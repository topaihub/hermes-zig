const std = @import("std");
const types = @import("../core/types.zig");

pub const Message = types.Message;
pub const ToolCall = types.ToolCall;
pub const TokenUsage = types.TokenUsage;

pub const ToolSchema = struct {
    name: []const u8,
    description: []const u8,
    parameters_schema: []const u8,
};

pub const CompletionRequest = struct {
    model: []const u8,
    messages: []const Message,
    tools: ?[]const ToolSchema = null,
    temperature: f32 = 0.7,
    max_tokens: ?u32 = null,
    stream: bool = false,
};

pub const CompletionResponse = struct {
    content: ?[]const u8 = null,
    tool_calls: ?[]ToolCall = null,
    usage: TokenUsage = .{},
    arena: std.heap.ArenaAllocator,

    pub fn deinit(self: *CompletionResponse) void {
        self.arena.deinit();
    }
};

pub const StreamCallback = struct {
    ctx: *anyopaque,
    on_delta: *const fn (ctx: *anyopaque, content: []const u8, done: bool) void,
};

pub const LlmClient = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        complete: *const fn (ptr: *anyopaque, request: CompletionRequest) anyerror!CompletionResponse,
        completeStream: *const fn (ptr: *anyopaque, request: CompletionRequest, callback: StreamCallback) anyerror!CompletionResponse,
        deinit: *const fn (ptr: *anyopaque) void,
    };

    pub fn complete(self: LlmClient, request: CompletionRequest) !CompletionResponse {
        return self.vtable.complete(self.ptr, request);
    }

    pub fn completeStream(self: LlmClient, request: CompletionRequest, callback: StreamCallback) !CompletionResponse {
        return self.vtable.completeStream(self.ptr, request, callback);
    }

    pub fn deinit(self: LlmClient) void {
        self.vtable.deinit(self.ptr);
    }
};

test "CompletionResponse arena lifecycle" {
    var resp = CompletionResponse{
        .arena = std.heap.ArenaAllocator.init(std.testing.allocator),
    };
    const a = resp.arena.allocator();
    const s = try a.dupe(u8, "hello from arena");
    try std.testing.expectEqualStrings("hello from arena", s);
    resp.deinit();
}
