const std = @import("std");

/// Stream callback function signature
pub const StreamDeltaFn = *const fn (ctx: *anyopaque, content: []const u8, done: bool) void;

/// Stream callback structure
pub const StreamCallback = struct {
    ctx: *anyopaque,
    on_delta: StreamDeltaFn,
};

/// CLI streaming callback context
pub const CliStreamCallback = struct {
    writer: std.io.AnyWriter,
    tool_call_count: usize = 0,
    
    pub fn init(writer: std.io.AnyWriter) CliStreamCallback {
        return .{ .writer = writer };
    }
    
    /// Create a StreamCallback for LLM streaming
    pub fn callback(self: *CliStreamCallback) StreamCallback {
        return .{
            .ctx = self,
            .on_delta = onDelta,
        };
    }
    
    fn onDelta(ctx: *anyopaque, content: []const u8, done: bool) void {
        const self: *CliStreamCallback = @ptrCast(@alignCast(ctx));
        
        if (done) {
            self.writer.writeAll("\n") catch {};
            return;
        }
        
        if (content.len > 0) {
            self.writer.writeAll(content) catch {};
        }
    }
    
    /// Display tool call notification
    pub fn onToolCall(self: *CliStreamCallback, tool_name: []const u8) void {
        self.tool_call_count += 1;
        self.writer.print("\n⚡ Calling {s}...\n", .{tool_name}) catch {};
    }
    
    /// Display tool result
    pub fn onToolResult(self: *CliStreamCallback, tool_name: []const u8, success: bool) void {
        if (success) {
            self.writer.print("✓ {s} completed\n", .{tool_name}) catch {};
        } else {
            self.writer.print("✗ {s} failed\n", .{tool_name}) catch {};
        }
    }
};

test "CliStreamCallback init" {
    var buf = std.ArrayList(u8).init(std.testing.allocator);
    defer buf.deinit();
    const writer = buf.writer().any();
    
    const cb = CliStreamCallback.init(writer);
    try std.testing.expectEqual(@as(usize, 0), cb.tool_call_count);
}

test "CliStreamCallback onDelta writes content" {
    var buf = std.ArrayList(u8).init(std.testing.allocator);
    defer buf.deinit();
    const writer = buf.writer().any();
    
    var cb = CliStreamCallback.init(writer);
    const stream_cb = cb.callback();
    
    stream_cb.on_delta(stream_cb.ctx, "Hello", false);
    stream_cb.on_delta(stream_cb.ctx, " World", false);
    
    try std.testing.expectEqualStrings("Hello World", buf.items);
}

test "CliStreamCallback onDelta done adds newline" {
    var buf = std.ArrayList(u8).init(std.testing.allocator);
    defer buf.deinit();
    const writer = buf.writer().any();
    
    var cb = CliStreamCallback.init(writer);
    const stream_cb = cb.callback();
    
    stream_cb.on_delta(stream_cb.ctx, "Done", false);
    stream_cb.on_delta(stream_cb.ctx, "", true);
    
    try std.testing.expectEqualStrings("Done\n", buf.items);
}

test "CliStreamCallback onToolCall displays notification" {
    var buf = std.ArrayList(u8).init(std.testing.allocator);
    defer buf.deinit();
    const writer = buf.writer().any();
    
    var cb = CliStreamCallback.init(writer);
    cb.onToolCall("read_file");
    
    try std.testing.expect(std.mem.indexOf(u8, buf.items, "⚡ Calling read_file...") != null);
    try std.testing.expectEqual(@as(usize, 1), cb.tool_call_count);
}

test "CliStreamCallback onToolResult displays success" {
    var buf = std.ArrayList(u8).init(std.testing.allocator);
    defer buf.deinit();
    const writer = buf.writer().any();
    
    var cb = CliStreamCallback.init(writer);
    cb.onToolResult("read_file", true);
    
    try std.testing.expect(std.mem.indexOf(u8, buf.items, "✓ read_file completed") != null);
}

test "CliStreamCallback onToolResult displays failure" {
    var buf = std.ArrayList(u8).init(std.testing.allocator);
    defer buf.deinit();
    const writer = buf.writer().any();
    
    var cb = CliStreamCallback.init(writer);
    cb.onToolResult("read_file", false);
    
    try std.testing.expect(std.mem.indexOf(u8, buf.items, "✗ read_file failed") != null);
}
