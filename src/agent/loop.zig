const std = @import("std");
const framework = @import("framework");
const llm_interface = @import("../llm/interface.zig");
const tools_registry = @import("../tools/registry.zig");
const tools_interface = @import("../tools/interface.zig");
const core_types = @import("../core/types.zig");
const core_config = @import("../core/config.zig");
const core_database = @import("../core/database.zig");
const core_sqlite = @import("../core/sqlite.zig");
const policy = @import("../security/policy.zig");
const audit_mod = @import("../security/audit.zig");

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
    logger: ?*framework.Logger = null,
    max_iterations: u32 = 25,
    fallback_model: ?[]const u8 = null,
    interrupt_flag: ?*std.atomic.Value(bool) = null,
    db: ?core_sqlite.Database = null,
    session_id: []const u8 = "default",
    autonomy_level: policy.AutonomyLevel = .supervised,
    audit_trail: ?*audit_mod.AuditTrail = null,

    pub fn run(self: *AgentLoop, messages: []const core_types.Message, tool_schemas: []const llm_interface.ToolSchema) !RunResult {
        var method_trace: ?framework.MethodTrace = null;
        defer if (method_trace) |*trace| trace.deinit();

        var summary_trace: ?framework.SummaryTrace = null;
        defer if (summary_trace) |*trace| trace.deinit();

        var trace_error_code: ?[]const u8 = null;
        errdefer {
            if (method_trace) |*trace| {
                trace.finishError(trace_error_code orelse "AgentLoopError", trace_error_code, false);
            }
            if (summary_trace) |*trace| {
                trace.finishError(.system);
            }
        }

        if (self.logger) |logger| {
            const params_summary = try std.fmt.allocPrint(self.allocator, "{{\"messages\":{d},\"tools\":{d}}}", .{ messages.len, tool_schemas.len });
            defer self.allocator.free(params_summary);

            method_trace = try framework.MethodTrace.begin(self.allocator, logger, "AgentLoop.Run", params_summary, 1000);
            summary_trace = try framework.SummaryTrace.begin(self.allocator, logger, "AgentLoop.Run", 1000);
        }

        var history = std.ArrayListUnmanaged(core_types.Message){};
        defer history.deinit(self.allocator);
        try history.appendSlice(self.allocator, messages);

        var total_usage = core_types.TokenUsage{};
        var iteration: u32 = 0;
        while (iteration < self.max_iterations) : (iteration += 1) {
            // Check interrupt flag
            if (self.interrupt_flag) |flag| {
                if (flag.load(.acquire)) {
                    trace_error_code = "Interrupted";
                    return error.Interrupted;
                }
            }

            const req = llm_interface.CompletionRequest{
                .model = self.config.model,
                .messages = history.items,
                .tools = if (tool_schemas.len > 0) tool_schemas else null,
                .temperature = self.config.temperature,
                .max_tokens = self.config.max_tokens,
                .stream = false,
            };

            if (self.logger) |logger| {
                if (self.config.logging.debug_prompts) {
                    const prompt_text = try formatMessagesForLog(self.allocator, req.messages);
                    defer self.allocator.free(prompt_text);

                    logger.child("llm").debug("PROMPT", &.{
                        framework.LogField.string("model", req.model),
                        framework.LogField.string("wire_api", self.config.wire_api),
                        framework.LogField.string("messages", prompt_text),
                    });
                }
            }

            var response = self.llm.complete(req) catch |err| blk: {
                // On LLM error, try fallback model if available
                if (self.fallback_model) |fb| {
                    var fb_req = req;
                    fb_req.model = fb;
                    break :blk self.llm.complete(fb_req) catch {
                        trace_error_code = @errorName(err);
                        return err;
                    };
                } else {
                    trace_error_code = @errorName(err);
                    return err;
                }
            };
            defer response.deinit();

            if (self.logger) |logger| {
                if (self.config.logging.debug_prompts) {
                    const response_text = try singleLineForLog(self.allocator, response.content orelse "");
                    defer self.allocator.free(response_text);

                    var fields: [4]framework.LogField = undefined;
                    var count: usize = 0;
                    fields[count] = framework.LogField.string("model", req.model);
                    count += 1;
                    fields[count] = framework.LogField.string("content", response_text);
                    count += 1;
                    if (response.tool_calls) |tool_calls| {
                        fields[count] = framework.LogField.uint("tool_calls", tool_calls.len);
                        count += 1;
                    }
                    logger.child("llm").debug("RESPONSE", fields[0..count]);
                }
            }

            total_usage.prompt_tokens += response.usage.prompt_tokens;
            total_usage.completion_tokens += response.usage.completion_tokens;
            total_usage.total_tokens += response.usage.total_tokens;

            if (response.tool_calls == null or response.tool_calls.?.len == 0) {
                const content = try self.allocator.dupe(u8, response.content orelse "");
                // Persist assistant response
                if (self.db) |db| {
                    core_database.appendMessage(db, self.session_id, "assistant", content) catch {};
                }
                if (method_trace) |*trace| {
                    trace.finishSuccess("Ok(200)", false);
                }
                if (summary_trace) |*trace| {
                    trace.finishSuccess();
                }
                return .{
                    .content = content,
                    .usage = total_usage,
                    .iterations = iteration + 1,
                };
            }

            // Persist assistant message with tool calls
            if (self.db) |db| {
                core_database.appendMessage(db, self.session_id, "assistant", response.content orelse "[tool_calls]") catch {};
            }

            // Append assistant message
            try history.append(self.allocator, .{ .role = .assistant, .content = response.content orelse "" });

            // Execute each tool call
            for (response.tool_calls.?) |tc| {
                // Check autonomy level
                if (policy.requiresApproval(self.autonomy_level, tc.name)) {
                    // For now, auto-approve (interactive approval needs CLI integration)
                }

                const result = self.tools.dispatch(tc.name, tc.arguments, self.allocator) catch |err| tools_interface.ToolResult{
                    .output = @errorName(err),
                    .is_error = true,
                };

                // Log to audit trail
                if (self.audit_trail) |trail| {
                    trail.log(self.allocator, .{ .timestamp = std.time.timestamp(), .tool_name = tc.name, .approved = true }) catch {};
                }

                // Persist tool result
                if (self.db) |db| {
                    core_database.appendMessage(db, self.session_id, "tool", result.output) catch {};
                }

                try history.append(self.allocator, .{ .role = .tool, .content = result.output, .tool_call_id = tc.id, .name = tc.name });

            }
        }
        trace_error_code = "MaxIterationsExceeded";
        return error.MaxIterationsExceeded;
    }
};

fn formatMessagesForLog(allocator: std.mem.Allocator, messages: []const core_types.Message) ![]u8 {
    var parts = std.ArrayList(u8){};
    defer parts.deinit(allocator);

    for (messages, 0..) |msg, index| {
        if (index > 0) {
            try parts.appendSlice(allocator, " || ");
        }

        try parts.append(allocator, '[');
        try parts.appendSlice(allocator, @tagName(msg.role));
        try parts.appendSlice(allocator, "] ");

        const content = try singleLineForLog(allocator, msg.content);
        defer allocator.free(content);
        try parts.appendSlice(allocator, content);
    }

    return parts.toOwnedSlice(allocator);
}

fn singleLineForLog(allocator: std.mem.Allocator, text: []const u8) ![]u8 {
    var out = std.ArrayList(u8){};
    defer out.deinit(allocator);

    for (text) |ch| {
        switch (ch) {
            '\r' => {},
            '\n' => try out.appendSlice(allocator, "\\n"),
            '\t' => try out.appendSlice(allocator, "\\t"),
            else => try out.append(allocator, ch),
        }
    }

    return out.toOwnedSlice(allocator);
}

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

test "singleLineForLog escapes newlines and tabs" {
    const escaped = try singleLineForLog(std.testing.allocator, "a\nb\tc\r");
    defer std.testing.allocator.free(escaped);
    try std.testing.expectEqualStrings("a\\nb\\tc", escaped);
}
