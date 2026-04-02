const std = @import("std");
const tools_interface = @import("../interface.zig");
const ToolResult = tools_interface.ToolResult;

pub const SendMessageTool = struct {
    pub const SCHEMA = tools_interface.ToolSchema{
        .name = "send_message",
        .description = "Send a message to a platform",
        .parameters_schema =
            \\{"type":"object","properties":{"platform":{"type":"string"},"chat_id":{"type":"string"},"content":{"type":"string"}},"required":["platform","chat_id","content"]}
        ,
    };

    pub fn execute(self: *SendMessageTool, allocator: std.mem.Allocator, args: std.json.ObjectMap) anyerror!ToolResult {
        _ = self;
        const platform = tools_interface.getString(args, "platform") orelse return .{ .output = "missing platform", .is_error = true };
        const chat_id = tools_interface.getString(args, "chat_id") orelse return .{ .output = "missing chat_id", .is_error = true };
        const content = tools_interface.getString(args, "content") orelse return .{ .output = "missing content", .is_error = true };
        return .{ .output = try std.fmt.allocPrint(allocator, "[SEND stub] {s}:{s} -> {s}", .{ platform, chat_id, content }) };
    }
};

test "SendMessageTool schema" {
    var tool = SendMessageTool{};
    const handler = tools_interface.makeToolHandler(SendMessageTool, &tool);
    try std.testing.expectEqualStrings("send_message", handler.schema.name);
}
