const std = @import("std");
const tools_interface = @import("../interface.zig");

pub const SendMessageTool = struct {
    pub const SCHEMA = tools_interface.ToolSchema{
        .name = "send_message",
        .description = "Send a message to a platform",
        .parameters_schema =
            \\{"type":"object","properties":{"platform":{"type":"string"},"chat_id":{"type":"string"},"content":{"type":"string"}},"required":["platform","chat_id","content"]}
        ,
    };

    pub fn execute(self: *SendMessageTool, args_json: []const u8, ctx: *const tools_interface.ToolContext) anyerror![]const u8 {
        _ = self;
        const Args = struct { platform: []const u8, chat_id: []const u8, content: []const u8 };
        const parsed = std.json.parseFromSlice(Args, ctx.allocator, args_json, .{ .ignore_unknown_fields = true }) catch
            return error.InvalidArgs;
        defer parsed.deinit();
        return std.fmt.allocPrint(ctx.allocator, "[SEND stub] {s}:{s} -> {s}", .{ parsed.value.platform, parsed.value.chat_id, parsed.value.content });
    }
};

test "SendMessageTool schema" {
    var tool = SendMessageTool{};
    const handler = tools_interface.makeToolHandler(SendMessageTool, &tool);
    try std.testing.expectEqualStrings("send_message", handler.schema.name);
}
