const std = @import("std");
const framework = @import("framework");
const interface = @import("interface.zig");
const streaming = @import("streaming.zig");

const LlmClient = interface.LlmClient;
const CompletionRequest = interface.CompletionRequest;
const CompletionResponse = interface.CompletionResponse;
const StreamCallback = interface.StreamCallback;
const TokenUsage = interface.TokenUsage;

pub const WireApi = enum { chat_completions, responses };

pub const OpenAICompatClient = struct {
    base_url: []const u8,
    wire_api: WireApi,
    api_key: []const u8,
    allocator: std.mem.Allocator,
    http: framework.HttpClient,

    const vtable = LlmClient.VTable{
        .complete = completeErased,
        .completeStream = completeStreamErased,
        .deinit = deinitErased,
    };

    pub fn init(
        allocator: std.mem.Allocator,
        base_url: []const u8,
        wire_api: []const u8,
        api_key: []const u8,
        http: framework.HttpClient,
    ) OpenAICompatClient {
        return .{
            .base_url = base_url,
            .wire_api = parseWireApi(wire_api),
            .api_key = api_key,
            .allocator = allocator,
            .http = http,
        };
    }

    pub fn asLlmClient(self: *OpenAICompatClient) LlmClient {
        return .{ .ptr = @ptrCast(self), .vtable = &vtable };
    }

    pub fn providerName(self: *const OpenAICompatClient) []const u8 {
        _ = self;
        return "openai-compat";
    }

    pub fn complete(self: *OpenAICompatClient, request: CompletionRequest) !CompletionResponse {
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        errdefer arena.deinit();
        const a = arena.allocator();

        const body = switch (self.wire_api) {
            .chat_completions => try buildChatCompletionsRequestBody(a, request, false),
            .responses => try buildResponsesRequestBody(a, request),
        };
        const url = switch (self.wire_api) {
            .chat_completions => try std.fmt.allocPrint(a, "{s}/chat/completions", .{self.base_url}),
            .responses => try std.fmt.allocPrint(a, "{s}/responses", .{self.base_url}),
        };
        const auth = try std.fmt.allocPrint(a, "Bearer {s}", .{self.api_key});

        var resp = try self.http.send(a, .{
            .method = .POST,
            .url = url,
            .headers = &.{
                .{ .name = "Content-Type", .value = "application/json" },
                .{ .name = "Authorization", .value = auth },
            },
            .body = body,
        });
        _ = &resp;

        var response = CompletionResponse{ .arena = arena };
        switch (self.wire_api) {
            .chat_completions => try parseChatCompletionsBody(a, resp.body, &response),
            .responses => try parseResponsesBody(a, resp.body, &response),
        }

        return response;
    }

    pub fn completeStream(self: *OpenAICompatClient, request: CompletionRequest, callback: StreamCallback) !CompletionResponse {
        if (self.wire_api == .responses) {
            const response = try self.complete(request);
            if (response.content) |content| {
                callback.on_delta(callback.ctx, content, false);
            }
            callback.on_delta(callback.ctx, "", true);
            return response;
        }

        var arena = std.heap.ArenaAllocator.init(self.allocator);
        errdefer arena.deinit();
        const a = arena.allocator();

        const body = try buildChatCompletionsRequestBody(a, request, true);
        const url = try std.fmt.allocPrint(a, "{s}/chat/completions", .{self.base_url});
        const auth = try std.fmt.allocPrint(a, "Bearer {s}", .{self.api_key});

        var resp = try self.http.send(a, .{
            .method = .POST,
            .url = url,
            .headers = &.{
                .{ .name = "Content-Type", .value = "application/json" },
                .{ .name = "Authorization", .value = auth },
            },
            .body = body,
        });
        _ = &resp;

        // Parse SSE from response body
        var content_buf = std.ArrayList(u8){};
        var sse = streaming.SseParser.init(a);
        defer sse.deinit();

        const payloads = try sse.feed(resp.body, a);
        for (payloads) |payload| {
            const chunk = std.json.parseFromSlice(std.json.Value, a, payload, .{}) catch continue;
            const choices = chunk.value.object.get("choices") orelse continue;
            if (choices != .array or choices.array.items.len == 0) continue;
            const delta_obj = choices.array.items[0].object.get("delta") orelse continue;
            if (delta_obj != .object) continue;
            if (delta_obj.object.get("content")) |c| {
                if (c == .string) {
                    try content_buf.appendSlice(a, c.string);
                    callback.on_delta(callback.ctx, c.string, false);
                }
            }
        }
        callback.on_delta(callback.ctx, "", true);

        var response = CompletionResponse{ .arena = arena };
        if (content_buf.items.len > 0) {
            response.content = try a.dupe(u8, content_buf.items);
        }
        return response;
    }

    fn completeErased(ptr: *anyopaque, request: CompletionRequest) anyerror!CompletionResponse {
        const self: *OpenAICompatClient = @ptrCast(@alignCast(ptr));
        return self.complete(request);
    }

    fn completeStreamErased(ptr: *anyopaque, request: CompletionRequest, callback: StreamCallback) anyerror!CompletionResponse {
        const self: *OpenAICompatClient = @ptrCast(@alignCast(ptr));
        return self.completeStream(request, callback);
    }

    fn deinitErased(_: *anyopaque) void {}
};

fn jsonInt(obj: std.json.Value, key: []const u8) u32 {
    const v = obj.object.get(key) orelse return 0;
    return switch (v) {
        .integer => |i| @intCast(@max(0, i)),
        .number_string, .string => 0,
        else => 0,
    };
}

fn parseWireApi(wire_api: []const u8) WireApi {
    if (std.mem.eql(u8, wire_api, "responses")) return .responses;
    return .chat_completions;
}

fn buildChatCompletionsRequestBody(a: std.mem.Allocator, request: CompletionRequest, stream: bool) ![]const u8 {
    var obj = std.json.ObjectMap.init(a);

    try obj.put("model", .{ .string = request.model });
    try obj.put("stream", .{ .bool = stream });

    // temperature
    const temp_str = try std.fmt.allocPrint(a, "{d:.1}", .{request.temperature});
    try obj.put("temperature", .{ .number_string = temp_str });

    if (request.max_tokens) |mt| {
        try obj.put("max_tokens", .{ .integer = @intCast(mt) });
    }

    // messages array
    var msgs = std.json.Array.init(a);
    for (request.messages) |msg| {
        var m = std.json.ObjectMap.init(a);
        try m.put("role", .{ .string = @tagName(msg.role) });
        try m.put("content", .{ .string = msg.content });
        if (msg.tool_call_id) |id| try m.put("tool_call_id", .{ .string = id });
        if (msg.name) |n| try m.put("name", .{ .string = n });
        try msgs.append(.{ .object = m });
    }
    try obj.put("messages", .{ .array = msgs });

    // tools
    if (request.tools) |tools| {
        var tools_arr = std.json.Array.init(a);
        for (tools) |tool| {
            var t = std.json.ObjectMap.init(a);
            try t.put("type", .{ .string = "function" });
            var func = std.json.ObjectMap.init(a);
            try func.put("name", .{ .string = tool.name });
            try func.put("description", .{ .string = tool.description });
            const params_parsed = try std.json.parseFromSlice(std.json.Value, a, tool.parameters_schema, .{});
            try func.put("parameters", params_parsed.value);
            try t.put("function", .{ .object = func });
            try tools_arr.append(.{ .object = t });
        }
        try obj.put("tools", .{ .array = tools_arr });
    }

    const val = std.json.Value{ .object = obj };
    return std.json.Stringify.valueAlloc(a, val, .{});
}

fn buildResponsesRequestBody(a: std.mem.Allocator, request: CompletionRequest) ![]const u8 {
    var obj = std.json.ObjectMap.init(a);

    try obj.put("model", .{ .string = request.model });

    var input = std.json.Array.init(a);
    for (request.messages) |msg| {
        switch (msg.role) {
            .system, .user => {
                var message = std.json.ObjectMap.init(a);
                try message.put("role", .{ .string = @tagName(msg.role) });
                try message.put("content", .{ .string = msg.content });
                try input.append(.{ .object = message });
            },
            .assistant => {
                if (msg.content.len == 0) continue;
                var message = std.json.ObjectMap.init(a);
                try message.put("type", .{ .string = "message" });
                try message.put("role", .{ .string = "assistant" });
                try message.put("status", .{ .string = "completed" });

                var content = std.json.Array.init(a);
                var text = std.json.ObjectMap.init(a);
                try text.put("type", .{ .string = "output_text" });
                try text.put("text", .{ .string = msg.content });
                try content.append(.{ .object = text });
                try message.put("content", .{ .array = content });
                try input.append(.{ .object = message });
            },
            .tool => {
                const call_id = msg.tool_call_id orelse continue;
                var tool_output = std.json.ObjectMap.init(a);
                try tool_output.put("type", .{ .string = "function_call_output" });
                try tool_output.put("call_id", .{ .string = call_id });
                try tool_output.put("output", .{ .string = msg.content });
                try input.append(.{ .object = tool_output });
            },
        }
    }
    try obj.put("input", .{ .array = input });

    if (request.max_tokens) |mt| {
        try obj.put("max_output_tokens", .{ .integer = @intCast(mt) });
    }

    if (request.tools) |tools| {
        var tools_arr = std.json.Array.init(a);
        for (tools) |tool| {
            var t = std.json.ObjectMap.init(a);
            try t.put("type", .{ .string = "function" });
            try t.put("name", .{ .string = tool.name });
            try t.put("description", .{ .string = tool.description });
            try t.put("strict", .{ .bool = true });
            const params_parsed = try std.json.parseFromSlice(std.json.Value, a, tool.parameters_schema, .{});
            try t.put("parameters", params_parsed.value);
            try tools_arr.append(.{ .object = t });
        }
        try obj.put("tools", .{ .array = tools_arr });
    }

    const val = std.json.Value{ .object = obj };
    return std.json.Stringify.valueAlloc(a, val, .{});
}

fn parseChatCompletionsBody(a: std.mem.Allocator, body: []const u8, response: *CompletionResponse) !void {
    const parsed = std.json.parseFromSlice(std.json.Value, a, body, .{}) catch
        return error.InvalidJson;
    const root = parsed.value;

    if (root.object.get("usage")) |usage_val| {
        if (usage_val == .object) {
            response.usage = .{
                .prompt_tokens = jsonInt(usage_val, "prompt_tokens"),
                .completion_tokens = jsonInt(usage_val, "completion_tokens"),
                .total_tokens = jsonInt(usage_val, "total_tokens"),
            };
        }
    }

    const choices = root.object.get("choices") orelse return;
    if (choices != .array or choices.array.items.len == 0) return;
    const choice = choices.array.items[0];
    const message = (if (choice == .object) choice.object.get("message") else null) orelse return;
    if (message != .object) return;

    if (message.object.get("content")) |c| {
        if (c == .string) response.content = c.string;
    }

    if (message.object.get("tool_calls")) |tc_val| {
        if (tc_val == .array and tc_val.array.items.len > 0) {
            var tool_calls = try a.alloc(interface.ToolCall, tc_val.array.items.len);
            for (tc_val.array.items, 0..) |tc, i| {
                if (tc != .object) continue;
                const func = tc.object.get("function") orelse continue;
                if (func != .object) continue;
                tool_calls[i] = .{
                    .id = if (tc.object.get("id")) |id| (if (id == .string) id.string else "") else "",
                    .name = if (func.object.get("name")) |n| (if (n == .string) n.string else "") else "",
                    .arguments = if (func.object.get("arguments")) |args| (if (args == .string) args.string else "") else "",
                };
            }
            response.tool_calls = tool_calls;
        }
    }
}

fn parseResponsesBody(a: std.mem.Allocator, body: []const u8, response: *CompletionResponse) !void {
    const parsed = std.json.parseFromSlice(std.json.Value, a, body, .{}) catch
        return error.InvalidJson;
    const root = parsed.value;

    if (root.object.get("usage")) |usage_val| {
        if (usage_val == .object) {
            response.usage = .{
                .prompt_tokens = jsonInt(usage_val, "input_tokens"),
                .completion_tokens = jsonInt(usage_val, "output_tokens"),
                .total_tokens = jsonInt(usage_val, "total_tokens"),
            };
        }
    }

    const output = root.object.get("output") orelse return;
    if (output != .array) return;

    var content_buf = std.ArrayList(u8){};
    var tool_calls = std.ArrayList(interface.ToolCall){};

    for (output.array.items) |item| {
        if (item != .object) continue;
        const item_type = item.object.get("type") orelse continue;
        if (item_type != .string) continue;

        if (std.mem.eql(u8, item_type.string, "message")) {
            const role = item.object.get("role") orelse continue;
            if (role != .string or !std.mem.eql(u8, role.string, "assistant")) continue;
            const content = item.object.get("content") orelse continue;
            if (content != .array) continue;

            for (content.array.items) |content_item| {
                if (content_item != .object) continue;
                const content_type = content_item.object.get("type") orelse continue;
                if (content_type != .string) continue;

                if (std.mem.eql(u8, content_type.string, "output_text")) {
                    if (content_item.object.get("text")) |text| {
                        if (text == .string) try content_buf.appendSlice(a, text.string);
                    }
                } else if (std.mem.eql(u8, content_type.string, "refusal")) {
                    if (content_item.object.get("refusal")) |refusal| {
                        if (refusal == .string) try content_buf.appendSlice(a, refusal.string);
                    }
                }
            }
        } else if (std.mem.eql(u8, item_type.string, "function_call")) {
            const call_id = if (item.object.get("call_id")) |id| (if (id == .string) id.string else "") else "";
            const item_id = if (item.object.get("id")) |id| (if (id == .string) id.string else "") else "";
            try tool_calls.append(a, .{
                .id = if (call_id.len > 0) call_id else item_id,
                .name = if (item.object.get("name")) |name| (if (name == .string) name.string else "") else "",
                .arguments = if (item.object.get("arguments")) |args| (if (args == .string) args.string else "") else "",
            });
        }
    }

    if (content_buf.items.len > 0) {
        response.content = try a.dupe(u8, content_buf.items);
    }
    if (tool_calls.items.len > 0) {
        response.tool_calls = try tool_calls.toOwnedSlice(a);
    }
}

test "OpenAICompatClient init and providerName" {
    const Mock = struct {
        fn mockSend(_: std.mem.Allocator, _: framework.HttpRequest) !framework.HttpResponse {
            unreachable;
        }
    };
    var native = framework.NativeHttpClient.init(Mock.mockSend);
    var client = OpenAICompatClient.init(
        std.testing.allocator,
        "https://api.example.com/v1",
        "chat_completions",
        "test-key",
        native.client(),
    );
    try std.testing.expectEqualStrings("openai-compat", client.providerName());
    try std.testing.expectEqualStrings("https://api.example.com/v1", client.base_url);
    try std.testing.expectEqual(WireApi.chat_completions, client.wire_api);
}

test "buildResponsesRequestBody encodes message history and tools" {
    const request = CompletionRequest{
        .model = "gpt-5.4",
        .messages = &.{
            .{ .role = .system, .content = "You are helpful." },
            .{ .role = .user, .content = "hi" },
            .{ .role = .assistant, .content = "hello" },
            .{ .role = .tool, .content = "{\"ok\":true}", .tool_call_id = "call_123", .name = "demo_tool" },
        },
        .tools = &.{
            .{
                .name = "demo_tool",
                .description = "demo",
                .parameters_schema = "{\"type\":\"object\"}",
            },
        },
    };

    const body = try buildResponsesRequestBody(std.testing.allocator, request);
    defer std.testing.allocator.free(body);

    var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, body, .{});
    defer parsed.deinit();

    const root = parsed.value.object;
    try std.testing.expectEqualStrings("gpt-5.4", root.get("model").?.string);
    try std.testing.expect(root.get("input").?.array.items.len == 4);
    try std.testing.expectEqualStrings("function_call_output", root.get("input").?.array.items[3].object.get("type").?.string);
    try std.testing.expectEqualStrings("call_123", root.get("input").?.array.items[3].object.get("call_id").?.string);
    try std.testing.expectEqualStrings("function", root.get("tools").?.array.items[0].object.get("type").?.string);
}

test "parseResponsesBody extracts text and tool calls" {
    var response = CompletionResponse{
        .arena = std.heap.ArenaAllocator.init(std.testing.allocator),
    };
    defer response.deinit();

    const body =
        \\{
        \\  "output": [
        \\    {
        \\      "type": "function_call",
        \\      "id": "fc_1",
        \\      "call_id": "call_1",
        \\      "name": "search_files",
        \\      "arguments": "{\"q\":\"zig\"}"
        \\    },
        \\    {
        \\      "type": "message",
        \\      "role": "assistant",
        \\      "content": [
        \\        { "type": "output_text", "text": "hello" }
        \\      ]
        \\    }
        \\  ],
        \\  "usage": {
        \\    "input_tokens": 3,
        \\    "output_tokens": 5,
        \\    "total_tokens": 8
        \\  }
        \\}
    ;

    try parseResponsesBody(response.arena.allocator(), body, &response);

    try std.testing.expectEqualStrings("hello", response.content.?);
    try std.testing.expectEqual(@as(u32, 3), response.usage.prompt_tokens);
    try std.testing.expectEqual(@as(u32, 5), response.usage.completion_tokens);
    try std.testing.expectEqualStrings("call_1", response.tool_calls.?[0].id);
    try std.testing.expectEqualStrings("search_files", response.tool_calls.?[0].name);
}

test "responses smoke test" {
    const maybe_base_url = std.process.getEnvVarOwned(std.testing.allocator, "HERMES_RESPONSES_SMOKE_BASE_URL") catch |err| switch (err) {
        error.EnvironmentVariableNotFound => return,
        else => return err,
    };
    defer std.testing.allocator.free(maybe_base_url);

    const maybe_api_key = std.process.getEnvVarOwned(std.testing.allocator, "HERMES_RESPONSES_SMOKE_API_KEY") catch |err| switch (err) {
        error.EnvironmentVariableNotFound => return,
        else => return err,
    };
    defer std.testing.allocator.free(maybe_api_key);

    const maybe_model = std.process.getEnvVarOwned(std.testing.allocator, "HERMES_RESPONSES_SMOKE_MODEL") catch |err| switch (err) {
        error.EnvironmentVariableNotFound => try std.testing.allocator.dupe(u8, "gpt-5.4"),
        else => return err,
    };
    defer std.testing.allocator.free(maybe_model);

    var native = framework.NativeHttpClient.init(null);
    var client = OpenAICompatClient.init(
        std.testing.allocator,
        maybe_base_url,
        "responses",
        maybe_api_key,
        native.client(),
    );

    const request = CompletionRequest{
        .model = maybe_model,
        .messages = &.{
            .{ .role = .user, .content = "Reply with exactly: ok" },
        },
        .max_tokens = 16,
    };

    var response = try client.complete(request);
    defer response.deinit();

    const content = response.content orelse return error.ExpectedContent;
    try std.testing.expectEqualStrings("ok", std.mem.trim(u8, content, " \t\r\n"));
}
