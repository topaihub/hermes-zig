const std = @import("std");
const llm_interface = @import("../llm/interface.zig");
const tools_registry = @import("../tools/registry.zig");
const tools_interface = @import("../tools/interface.zig");
const core_types = @import("../core/types.zig");
const core_config = @import("../core/config.zig");
const core_database = @import("../core/database.zig");
const core_sqlite = @import("../core/sqlite.zig");

pub const RunResult = struct {
    content: []u8,
    usage: core_types.TokenUsage = .{},
    iterations: u32 = 0,

    pub fn deinit(self: *RunResult, allocator: std.mem.Allocator) void {
        allocator.free(self.content);
    }
};

pub const AgentLoop = struct {
    allocator: std.mem.Allocator,
    llm: llm_interface.LlmClient,
    tools: *tools_registry.ToolRegistry,
    config: *const core_config.Config,
    max_iterations: u32 = 25,
    fallback_model: ?[]const u8 = null,
    interrupt_flag: ?*std.atomic.Value(bool) = null,
    db: ?core_sqlite.Database = null,

    pub fn run(self: *AgentLoop, messages: []const core_types.Message, tool_schemas: []const llm_interface.ToolSchema) !RunResult {
        var history = std.ArrayListUnmanaged(core_types.Message){};
        defer history.deinit(self.allocator);
        try history.appendSlice(self.allocator, messages);

        var total_usage = core_types.TokenUsage{};
        var iteration: u32 = 0;
        while (iteration < self.max_iterations) : (iteration += 1) {
            // Check interrupt flag
            if (self.interrupt_flag) |flag| {
                if (flag.load(.acquire)) return error.Interrupted;
            }

            const req = llm_interface.CompletionRequest{
                .model = self.config.model,
                .messages = history.items,
                .tools = if (tool_schemas.len > 0) tool_schemas else null,
                .temperature = self.config.temperature,
                .max_tokens = self.config.max_tokens,
                .stream = false,
            };

            var response = self.llm.complete(req) catch |err| blk: {
                // On LLM error, try fallback model if available
                if (self.fallback_model) |fb| {
                    var fb_req = req;
                    fb_req.model = fb;
                    break :blk self.llm.complete(fb_req) catch return err;
                } else return err;
            };
            defer response.deinit();

            total_usage.prompt_tokens += response.usage.prompt_tokens;
            total_usage.completion_tokens += response.usage.completion_tokens;
            total_usage.total_tokens += response.usage.total_tokens;

            if (response.tool_calls == null or response.tool_calls.?.len == 0) {
                const content = try self.allocator.dupe(u8, response.content orelse "");
                // Persist to database if available
                if (self.db) |db| {
                    core_database.appendMessage(db, "agent", "assistant", content) catch {};
                }
                return .{
                    .content = content,
                    .usage = total_usage,
                    .iterations = iteration + 1,
                };
            }

            // Append assistant message
            try history.append(self.allocator, .{ .role = .assistant, .content = response.content orelse "" });

            // Execute each tool call and append results
            for (response.tool_calls.?) |tc| {
                const tool_ctx = tools_interface.ToolContext{
                    .session_source = .{ .platform = .cli, .chat_id = "agent" },
                    .allocator = self.allocator,
                };
                const result = self.tools.dispatch(tc.name, tc.arguments, &tool_ctx) catch |err|
                    try std.fmt.allocPrint(self.allocator, "Error: {s}", .{@errorName(err)});
                defer self.allocator.free(result);
                try history.append(self.allocator, .{
                    .role = .tool,
                    .content = result,
                    .tool_call_id = tc.id,
                    .name = tc.name,
                });
            }
        }
        return error.MaxIterationsExceeded;
    }
};

// --- Tests ---

const MockLlmImpl = struct {
    response_content: []const u8,
    call_count: u32 = 0,

    pub fn complete(ptr: *anyopaque, _: llm_interface.CompletionRequest) anyerror!llm_interface.CompletionResponse {
        const self: *MockLlmImpl = @ptrCast(@alignCast(ptr));
        self.call_count += 1;
        var resp = llm_interface.CompletionResponse{
            .arena = std.heap.ArenaAllocator.init(std.testing.allocator),
        };
        resp.content = try resp.arena.allocator().dupe(u8, self.response_content);
        resp.usage = .{ .prompt_tokens = 10, .completion_tokens = 5, .total_tokens = 15 };
        return resp;
    }

    pub fn completeStream(_: *anyopaque, _: llm_interface.CompletionRequest, _: llm_interface.StreamCallback) anyerror!llm_interface.CompletionResponse {
        return error.NotImplemented;
    }

    pub fn deinitFn(_: *anyopaque) void {}

    const vtable = llm_interface.LlmClient.VTable{
        .complete = &complete,
        .completeStream = &completeStream,
        .deinit = &deinitFn,
    };
};

test "AgentLoop returns content when no tool calls" {
    var mock = MockLlmImpl{ .response_content = "Hello from LLM" };
    const client = llm_interface.LlmClient{ .ptr = @ptrCast(&mock), .vtable = &MockLlmImpl.vtable };

    var reg = tools_registry.ToolRegistry.init(std.testing.allocator, &.{});
    defer reg.deinit();

    const cfg = core_config.Config{};
    var agent = AgentLoop{
        .allocator = std.testing.allocator,
        .llm = client,
        .tools = &reg,
        .config = &cfg,
    };

    const msgs = &[_]core_types.Message{.{ .role = .user, .content = "hi" }};
    var result = try agent.run(msgs, &.{});
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("Hello from LLM", result.content);
    try std.testing.expectEqual(@as(u32, 1), result.iterations);
    try std.testing.expectEqual(@as(u32, 10), result.usage.prompt_tokens);
}
