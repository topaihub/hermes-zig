const std = @import("std");
const framework = @import("framework");
const interface = @import("interface.zig");
const streaming = @import("streaming.zig");

const LlmClient = interface.LlmClient;
const CompletionRequest = interface.CompletionRequest;
const CompletionResponse = interface.CompletionResponse;
const StreamCallback = interface.StreamCallback;
const TokenUsage = interface.TokenUsage;

pub const OpenAICompatClient = struct {
    base_url: []const u8,
    api_key: []const u8,
    allocator: std.mem.Allocator,
    http: framework.HttpClient,

    const vtable = LlmClient.VTable{
        .complete = completeErased,
        .completeStream = completeStreamErased,
        .deinit = deinitErased,
    };

    pub fn init(allocator: std.mem.Allocator, base_url: []const u8, api_key: []const u8, http: framework.HttpClient) OpenAICompatClient {
        return .{ .base_url = base_url, .api_key = api_key, .allocator = allocator, .http = http };
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

        const is_responses = std.mem.startsWith(u8, request.model, "responses/");
        const body = try buildRequestBody(a, request, false);
        const url = if (is_responses)
            try std.fmt.allocPrint(a, "{s}/responses", .{self.base_url})
        else
            try std.fmt.allocPrint(a, "{s}/chat/completions", .{self.base_url});
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

        const parsed = std.json.parseFromSlice(std.json.Value, a, resp.body, .{}) catch
            return error.InvalidJson;
        const root = parsed.value;

        var response = CompletionResponse{ .arena = arena };

        // Parse usage
        if (root.object.get("usage")) |usage_val| {
            if (usage_val == .object) {
                response.usage = .{
                    .prompt_tokens = jsonInt(usage_val, "prompt_tokens"),
                    .completion_tokens = jsonInt(usage_val, "completion_tokens"),
                    .total_tokens = jsonInt(usage_val, "total_tokens"),
                };
            }
        }

        // Parse choices[0]
        const choices = root.object.get("choices") orelse return response;
        if (choices != .array or choices.array.items.len == 0) return response;
        const choice = choices.array.items[0];
        const message = (if (choice == .object) choice.object.get("message") else null) orelse return response;
        if (message != .object) return response;

        // Content
        if (message.object.get("content")) |c| {
            if (c == .string) response.content = c.string;
        }

        // Tool calls
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

        return response;
    }

    pub fn completeStream(self: *OpenAICompatClient, request: CompletionRequest, callback: StreamCallback) !CompletionResponse {
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        errdefer arena.deinit();
        const a = arena.allocator();

        const body = try buildRequestBody(a, request, true);
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
        var content_buf = std.ArrayList(u8).init(a);
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
                    try content_buf.appendSlice(c.string);
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

fn buildRequestBody(a: std.mem.Allocator, request: CompletionRequest, stream: bool) ![]const u8 {
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
    var buf = std.ArrayList(u8).init(a);
    try std.json.stringify(val, .{}, buf.writer());
    return buf.toOwnedSlice();
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
        "test-key",
        native.client(),
    );
    try std.testing.expectEqualStrings("openai-compat", client.providerName());
    try std.testing.expectEqualStrings("https://api.example.com/v1", client.base_url);
}
