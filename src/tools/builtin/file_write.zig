const std = @import("std");
const tools_interface = @import("../interface.zig");

pub const FileWriteTool = struct {
    pub const SCHEMA = tools_interface.ToolSchema{
        .name = "write_file",
        .description = "Write content to a file, creating parent directories as needed",
        .parameters_schema =
            \\{"type":"object","properties":{"path":{"type":"string"},"content":{"type":"string"}},"required":["path","content"]}
        ,
    };

    pub fn execute(self: *FileWriteTool, args_json: []const u8, ctx: *const tools_interface.ToolContext) anyerror![]const u8 {
        _ = self;
        const Args = struct { path: []const u8, content: []const u8 };
        const parsed = std.json.parseFromSlice(Args, ctx.allocator, args_json, .{ .ignore_unknown_fields = true }) catch
            return error.InvalidArgs;
        defer parsed.deinit();

        if (std.fs.path.dirname(parsed.value.path)) |dir| {
            std.fs.cwd().makePath(dir) catch {};
        }
        std.fs.cwd().writeFile(.{ .sub_path = parsed.value.path, .data = parsed.value.content }) catch |e|
            return std.fmt.allocPrint(ctx.allocator, "Error writing file: {s}", .{@errorName(e)});

        return std.fmt.allocPrint(ctx.allocator, "Wrote {d} bytes to {s}", .{ parsed.value.content.len, parsed.value.path });
    }
};

test "FileWriteTool schema" {
    var tool = FileWriteTool{};
    const handler = tools_interface.makeToolHandler(FileWriteTool, &tool);
    try std.testing.expectEqualStrings("write_file", handler.schema.name);
}

test "FileWriteTool write then read" {
    const path = "/tmp/_hermes_test_write.txt";
    defer std.fs.cwd().deleteFile(path) catch {};

    var tool = FileWriteTool{};
    const handler = tools_interface.makeToolHandler(FileWriteTool, &tool);
    const ctx = tools_interface.ToolContext{
        .session_source = .{ .platform = .cli, .chat_id = "test" },
        .allocator = std.testing.allocator,
    };
    const result = try handler.execute(std.fmt.comptimePrint("{{\"path\":\"{s}\",\"content\":\"hello world\"}}", .{path}), &ctx);
    defer std.testing.allocator.free(result);
    try std.testing.expect(std.mem.indexOf(u8, result, "Wrote") != null);

    const content = try std.fs.cwd().readFileAlloc(std.testing.allocator, path, 4096);
    defer std.testing.allocator.free(content);
    try std.testing.expectEqualStrings("hello world", content);
}
