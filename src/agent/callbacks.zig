const std = @import("std");

/// CLI streaming callback for displaying LLM responses
pub const CliStreamCallback = struct {
    writer: std.Io.File.Writer,
    tool_count: usize = 0,
    
    pub fn init(writer: std.Io.File.Writer) CliStreamCallback {
        return .{ .writer = writer };
    }
    
    /// Called when streaming starts
    pub fn onStart(self: *CliStreamCallback) !void {
        _ = self;
    }
    
    /// Called for each text delta
    pub fn onText(self: *CliStreamCallback, text: []const u8) !void {
        try self.writer.writeAll(text);
    }
    
    /// Called when a tool is being invoked
    pub fn onToolUse(self: *CliStreamCallback, tool_name: []const u8, tool_id: []const u8) !void {
        self.tool_count += 1;
        try self.writer.print("\n🔧 {s} ({s})\n", .{ tool_name, tool_id });
    }
    
    /// Called when a tool completes
    pub fn onToolResult(self: *CliStreamCallback, tool_id: []const u8, result: []const u8) !void {
        _ = result;
        try self.writer.print("✓ {s}\n", .{tool_id});
    }
    
    /// Called on error
    pub fn onError(self: *CliStreamCallback, error_msg: []const u8) !void {
        try self.writer.print("\n❌ Error: {s}\n", .{error_msg});
    }
    
    /// Called when streaming completes
    pub fn onComplete(self: *CliStreamCallback) !void {
        try self.writer.writeAll("\n");
    }
};

test "CliStreamCallback basic" {
    // Smoke test - just verify the struct compiles and has correct fields
    const T = CliStreamCallback;
    try std.testing.expect(@hasField(T, "writer"));
    try std.testing.expect(@hasField(T, "tool_count"));
}
