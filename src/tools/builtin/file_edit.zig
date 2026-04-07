const std = @import("std");
const tools_interface = @import("../interface.zig");
const ToolResult = tools_interface.ToolResult;

pub const FileEditTool = struct {
    pub const SCHEMA = tools_interface.ToolSchema{
        .name = "patch",
        .description = "Apply text replacements to a file",
        .parameters_schema =
            \\{"type":"object","properties":{"path":{"type":"string","description":"File path"},"old_text":{"type":"string","description":"Text to find"},"new_text":{"type":"string","description":"Replacement text"}},"required":["path","old_text","new_text"]}
        ,
    };

    pub fn execute(self: *FileEditTool, allocator: std.mem.Allocator, args: std.json.ObjectMap) anyerror!ToolResult {
        _ = self;
        const path = tools_interface.getString(args, "path") orelse return .{ .output = "missing path", .is_error = true };
        const old_text = tools_interface.getString(args, "old_text") orelse return .{ .output = "missing old_text", .is_error = true };
        const new_text = tools_interface.getString(args, "new_text") orelse return .{ .output = "missing new_text", .is_error = true };

        const content = std.fs.cwd().readFileAlloc(allocator, path, 10 * 1024 * 1024) catch |e|
            return .{ .output = try std.fmt.allocPrint(allocator, "Error reading file: {s}", .{@errorName(e)}) };
        defer allocator.free(content);

        var count: usize = 0;
        var result = std.ArrayList(u8){};
        defer result.deinit(allocator);

        var rest: []const u8 = content;
        while (std.mem.indexOf(u8, rest, old_text)) |idx| {
            result.appendSlice(allocator, rest[0..idx]) catch return error.OutOfMemory;
            result.appendSlice(allocator, new_text) catch return error.OutOfMemory;
            rest = rest[idx + old_text.len ..];
            count += 1;
        }
        result.appendSlice(allocator, rest) catch return error.OutOfMemory;

        if (count == 0) return .{ .output = try std.fmt.allocPrint(allocator, "No occurrences of old_text found in {s}", .{path}) };

        std.fs.cwd().writeFile(.{ .sub_path = path, .data = result.items }) catch |e|
            return .{ .output = try std.fmt.allocPrint(allocator, "Error writing file: {s}", .{@errorName(e)}), .is_error = true };

        return .{ .output = try std.fmt.allocPrint(allocator, "Edited {s}: replaced {d} occurrences", .{ path, count }) };
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

    var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, std.fmt.comptimePrint("{{\"path\":\"{s}\",\"old_text\":\"hello\",\"new_text\":\"hi\"}}", .{path}), .{});
    defer parsed.deinit();
    const args = parsed.value.object;

    const result = try handler.execute(std.testing.allocator, args);
    defer std.testing.allocator.free(result.output);
    try std.testing.expect(std.mem.indexOf(u8, result.output, "replaced 2 occurrences") != null);

    const content = try std.fs.cwd().readFileAlloc(std.testing.allocator, path, 4096);
    defer std.testing.allocator.free(content);
    try std.testing.expectEqualStrings("hi world hi", content);
}
