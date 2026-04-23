const std = @import("std");
const tools_interface = @import("../interface.zig");
const ToolResult = tools_interface.ToolResult;

pub const FileWriteTool = struct {
    pub const SCHEMA = tools_interface.ToolSchema{
        .name = "write_file",
        .description = "Write content to a file, creating parent directories as needed",
        .parameters_schema =
            \\{"type":"object","properties":{"path":{"type":"string"},"content":{"type":"string"}},"required":["path","content"]}
        ,
    };

    pub fn execute(self: *FileWriteTool, allocator: std.mem.Allocator, args: std.json.ObjectMap) anyerror!ToolResult {
        _ = self;
        const path = tools_interface.getString(args, "path") orelse return .{ .output = "missing path", .is_error = true };
        const content = tools_interface.getString(args, "content") orelse return .{ .output = "missing content", .is_error = true };

        var io = std.Io.Threaded.init(allocator, .{});
        defer io.deinit();
        const cwd = std.Io.Dir.cwd();
        
        if (std.fs.path.dirname(path)) |dir| {
            cwd.createDirPath(io.io(), dir) catch {};
        }
        
        const file = std.Io.Dir.createFile(cwd, io.io(), path, .{}) catch |e|
            return .{ .output = try std.fmt.allocPrint(allocator, "Error writing file: {s}", .{@errorName(e)}), .is_error = true };
        defer file.close(io.io());
        
        var write_buf: [4096]u8 = undefined;
        var writer = file.writer(io.io(), &write_buf);
        writer.interface.writeAll(content) catch |e|
            return .{ .output = try std.fmt.allocPrint(allocator, "Error writing file: {s}", .{@errorName(e)}), .is_error = true };

        return .{ .output = try std.fmt.allocPrint(allocator, "Wrote {d} bytes to {s}", .{ content.len, path }) };
    }
};

test "FileWriteTool schema" {
    var tool = FileWriteTool{};
    const handler = tools_interface.makeToolHandler(FileWriteTool, &tool);
    try std.testing.expectEqualStrings("write_file", handler.schema.name);
}

test "FileWriteTool write then read" {
    const path = "_hermes_test_write.txt";
    defer std.fs.cwd().deleteFile(path) catch {};

    var tool = FileWriteTool{};
    const handler = tools_interface.makeToolHandler(FileWriteTool, &tool);

    var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, std.fmt.comptimePrint("{{\"path\":\"{s}\",\"content\":\"hello world\"}}", .{path}), .{});
    defer parsed.deinit();
    const result = try handler.execute(std.testing.allocator, parsed.value.object);
    defer std.testing.allocator.free(result.output);
    try std.testing.expect(std.mem.indexOf(u8, result.output, "Wrote") != null);

    const content = try std.fs.cwd().readFileAlloc(std.testing.allocator, path, 4096);
    defer std.testing.allocator.free(content);
    try std.testing.expectEqualStrings("hello world", content);
}
