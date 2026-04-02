const std = @import("std");
const tools_interface = @import("../interface.zig");

pub const FileEditTool = struct {
    pub const SCHEMA = tools_interface.ToolSchema{
        .name = "patch",
        .description = "Apply text replacements to a file",
        .parameters_schema =
            \\{"type":"object","properties":{"path":{"type":"string","description":"File path"},"old_text":{"type":"string","description":"Text to find"},"new_text":{"type":"string","description":"Replacement text"}},"required":["path","old_text","new_text"]}
        ,
    };

    pub fn execute(self: *FileEditTool, args_json: []const u8, ctx: *const tools_interface.ToolContext) anyerror![]const u8 {
        _ = self;
        const Args = struct { path: []const u8, old_text: []const u8, new_text: []const u8 };
        const parsed = std.json.parseFromSlice(Args, ctx.allocator, args_json, .{ .ignore_unknown_fields = true }) catch
            return error.InvalidArgs;
        defer parsed.deinit();

        const content = std.fs.cwd().readFileAlloc(ctx.allocator, parsed.value.path, 10 * 1024 * 1024) catch |e|
            return std.fmt.allocPrint(ctx.allocator, "Error reading file: {s}", .{@errorName(e)});
        defer ctx.allocator.free(content);

        var count: usize = 0;
        var result = std.ArrayList(u8).init(ctx.allocator);
        defer result.deinit();

        var rest: []const u8 = content;
        while (std.mem.indexOf(u8, rest, parsed.value.old_text)) |idx| {
            result.appendSlice(rest[0..idx]) catch return error.OutOfMemory;
            result.appendSlice(parsed.value.new_text) catch return error.OutOfMemory;
            rest = rest[idx + parsed.value.old_text.len ..];
            count += 1;
        }
        result.appendSlice(rest) catch return error.OutOfMemory;

        if (count == 0) return std.fmt.allocPrint(ctx.allocator, "No occurrences of old_text found in {s}", .{parsed.value.path});

        std.fs.cwd().writeFile(.{ .sub_path = parsed.value.path, .data = result.items }) catch |e|
            return std.fmt.allocPrint(ctx.allocator, "Error writing file: {s}", .{@errorName(e)});

        return std.fmt.allocPrint(ctx.allocator, "Edited {s}: replaced {d} occurrences", .{ parsed.value.path, count });
    }
};

test "FileEditTool schema" {
    var tool = FileEditTool{};
    const handler = tools_interface.makeToolHandler(FileEditTool, &tool);
    try std.testing.expectEqualStrings("patch", handler.schema.name);
}

test "FileEditTool replace text" {
    const path = "_hermes_test_edit.txt";
    defer std.fs.cwd().deleteFile(path) catch {};

    std.fs.cwd().writeFile(.{ .sub_path = path, .data = "hello world hello" }) catch unreachable;

    var tool = FileEditTool{};
    const handler = tools_interface.makeToolHandler(FileEditTool, &tool);
    const ctx = tools_interface.ToolContext{
        .session_source = .{ .platform = .cli, .chat_id = "test" },
        .allocator = std.testing.allocator,
    };
    const result = try handler.execute(std.fmt.comptimePrint("{{\"path\":\"{s}\",\"old_text\":\"hello\",\"new_text\":\"hi\"}}", .{path}), &ctx);
    defer std.testing.allocator.free(result);
    try std.testing.expect(std.mem.indexOf(u8, result, "replaced 2 occurrences") != null);

    const content = try std.fs.cwd().readFileAlloc(std.testing.allocator, path, 4096);
    defer std.testing.allocator.free(content);
    try std.testing.expectEqualStrings("hi world hi", content);
}
