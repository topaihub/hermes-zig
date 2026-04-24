const std = @import("std");
const framework = @import("framework");
const interface = @import("interface.zig");
const streaming = @import("streaming.zig");

const LlmClient = interface.LlmClient;
const CompletionRequest = interface.CompletionRequest;
const CompletionResponse = interface.CompletionResponse;
const StreamCallback = interface.StreamCallback;

pub const AnthropicClient = struct {
    api_key: []const u8,
    allocator: std.mem.Allocator,
    http: framework.HttpClient,

    const base_url = "https://api.anthropic.com/v1/messages";

    const vtable = LlmClient.VTable{
        .complete = completeErased,
        .completeStream = completeStreamErased,
        .deinit = deinitErased,
    };

    pub fn init(allocator: std.mem.Allocator, api_key: []const u8, http: framework.HttpClient) AnthropicClient {
        return .{ .api_key = api_key, .allocator = allocator, .http = http };
    }

    pub fn asLlmClient(self: *AnthropicClient) LlmClient {
        return .{ .ptr = @ptrCast(self), .vtable = &vtable };
    }

    pub fn complete(self: *AnthropicClient, request: CompletionRequest) !CompletionResponse {
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        errdefer arena.deinit();
        const a = arena.allocator();

        const body = try buildAnthropicBody(a, request, false);

        var resp = try self.http.send(a, .{
            .method = .POST,
            .url = base_url,
            .headers = &.{
                .{ .name = "Content-Type", .value = "application/json" },
                .{ .name = "x-api-key", .value = self.api_key },
                .{ .name = "anthropic-version", .value = "2023-06-01" },
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
                    .prompt_tokens = jsonInt(usage_val, "input_tokens"),
                    .completion_tokens = jsonInt(usage_val, "output_tokens"),
                    .total_tokens = jsonInt(usage_val, "input_tokens") + jsonInt(usage_val, "output_tokens"),
                };
            }
        }

        // Parse content array
        const content_arr = root.object.get("content") orelse return response;
        if (content_arr != .array) return response;

        var text_buf: std.ArrayList(u8) = .empty;
        var tool_calls: std.ArrayList(interface.ToolCall) = .empty;

        for (content_arr.array.items) |block| {
            if (block != .object) continue;
            const block_type = block.object.get("type") orelse continue;
            if (block_type != .string) continue;

            if (std.mem.eql(u8, block_type.string, "text")) {
                if (block.object.get("text")) |t| {
                    if (t == .string) try text_buf.appendSlice(a, t.string);
                }
            } else if (std.mem.eql(u8, block_type.string, "tool_use")) {
                var tc = interface.ToolCall{};
                if (block.object.get("id")) |id| {
                    if (id == .string) tc.id = id.string;
                }
                if (block.object.get("name")) |n| {
                    if (n == .string) tc.name = n.string;
                }
                if (block.object.get("input")) |input| {
                    tc.arguments = try std.json.Stringify.valueAlloc(a, input, .{});
                }
                try tool_calls.append(a, tc);
            }
        }

        if (text_buf.items.len > 0) response.content = try a.dupe(u8, text_buf.items);
        if (tool_calls.items.len > 0) response.tool_calls = try tool_calls.toOwnedSlice(a);

        return response;
    }

    pub fn completeStream(self: *AnthropicClient, request: CompletionRequest, callback: StreamCallback) !CompletionResponse {
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        errdefer arena.deinit();
        const a = arena.allocator();

        const body = try buildAnthropicBody(a, request, true);

        var resp = try self.http.send(a, .{
            .method = .POST,
            .url = base_url,
            .headers = &.{
                .{ .name = "Content-Type", .value = "application/json" },
                .{ .name = "x-api-key", .value = self.api_key },
                .{ .name = "anthropic-version", .value = "2023-06-01" },
            },
            .body = body,
        });
        _ = &resp;

        var content_buf: std.ArrayList(u8) = .empty;
        var sse = streaming.SseParser.init(a);
        defer sse.deinit();

        const payloads = try sse.feed(resp.body, a);
        for (payloads) |payload| {
            const chunk = std.json.parseFromSlice(std.json.Value, a, payload, .{}) catch continue;
            const ev_type = chunk.value.object.get("type") orelse continue;
            if (ev_type != .string) continue;
            if (std.mem.eql(u8, ev_type.string, "content_block_delta")) {
                const delta = chunk.value.object.get("delta") orelse continue;
                if (delta != .object) continue;
                if (delta.object.get("text")) |t| {
                    if (t == .string) {
                        try content_buf.appendSlice(a, t.string);
                        callback.on_delta(callback.ctx, t.string, false);
                    }
                }
            }
        }
        callback.on_delta(callback.ctx, "", true);

        var response = CompletionResponse{ .arena = arena };
        if (content_buf.items.len > 0) response.content = try a.dupe(u8, content_buf.items);
        return response;
    }

    fn completeErased(ptr: *anyopaque, request: CompletionRequest) anyerror!CompletionResponse {
        const self: *AnthropicClient = @ptrCast(@alignCast(ptr));
        return self.complete(request);
    }

    fn completeStreamErased(ptr: *anyopaque, request: CompletionRequest, callback: StreamCallback) anyerror!CompletionResponse {
        const self: *AnthropicClient = @ptrCast(@alignCast(ptr));
        return self.completeStream(request, callback);
    }

    fn deinitErased(_: *anyopaque) void {}
};

fn jsonInt(obj: std.json.Value, key: []const u8) u32 {
    const v = obj.object.get(key) orelse return 0;
    return switch (v) {
        .integer => |i| @intCast(@max(0, i)),
        else => 0,
    };
}

fn buildAnthropicBody(a: std.mem.Allocator, request: CompletionRequest, stream: bool) ![]const u8 {
    var obj: std.json.ObjectMap = .empty;

    try obj.put(a, "model", .{ .string = request.model });
    try obj.put(a, "stream", .{ .bool = stream });

    if (request.max_tokens) |mt| {
        try obj.put(a, "max_tokens", .{ .integer = @intCast(mt) });
    } else {
        try obj.put(a, "max_tokens", .{ .integer = 4096 });
    }

    // Anthropic uses separate system param; filter system messages out of messages array
    var msgs = std.json.Array.init(a);
    for (request.messages) |msg| {
        if (msg.role == .system) {
            try obj.put(a, "system", .{ .string = msg.content });
            continue;
        }
        var m: std.json.ObjectMap = .empty;
        try m.put(a, "role", .{ .string = @tagName(msg.role) });
        try m.put(a, "content", .{ .string = msg.content });
        try msgs.append(.{ .object = m });
    }
    try obj.put(a, "messages", .{ .array = msgs });

    // Tools
    if (request.tools) |tools| {
        var tools_arr = std.json.Array.init(a);
        for (tools) |tool| {
            var t: std.json.ObjectMap = .empty;
            try t.put(a, "name", .{ .string = tool.name });
            try t.put(a, "description", .{ .string = tool.description });
            const params_parsed = try std.json.parseFromSlice(std.json.Value, a, tool.parameters_schema, .{});
            try t.put(a, "input_schema", params_parsed.value);
            try tools_arr.append(.{ .object = t });
        }
        try obj.put(a, "tools", .{ .array = tools_arr });
    }

    const val = std.json.Value{ .object = obj };
    return std.json.Stringify.valueAlloc(a, val, .{});
}
