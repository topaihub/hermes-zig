const std = @import("std");
const tools_interface = @import("../interface.zig");
const ToolResult = tools_interface.ToolResult;

pub const FileReadTool = struct {
    pub const SCHEMA = tools_interface.ToolSchema{
        .name = "read_file",
        .description = "Read file contents, optionally a range of lines",
        .parameters_schema =
            \\{"type":"object","properties":{"path":{"type":"string"},"start_line":{"type":"integer"},"end_line":{"type":"integer"}},"required":["path"]}
        ,
    };

    pub fn execute(self: *FileReadTool, allocator: std.mem.Allocator, args: std.json.ObjectMap) anyerror!ToolResult {
        _ = self;
        const path = tools_interface.getString(args, "path") orelse return .{ .output = "missing path", .is_error = true };
        const start_line = tools_interface.getInt(args, "start_line");
        const end_line = tools_interface.getInt(args, "end_line");

        var io = std.Io.Threaded.init(allocator, .{});
        defer io.deinit();
        
        const cwd = std.Io.Dir.cwd();
        const file = std.Io.Dir.openFile(cwd, io.io(), path, .{}) catch |e|
            return .{ .output = try std.fmt.allocPrint(allocator, "Error reading file: {s}", .{@errorName(e)}) };
        defer file.close(io.io());
        
        var read_buf: [4096]u8 = undefined;
        var reader = file.reader(io.io(), &read_buf);
        const content = reader.interface.allocRemaining(allocator, @enumFromInt(10 * 1024 * 1024)) catch |e|
            return .{ .output = try std.fmt.allocPrint(allocator, "Error reading file: {s}", .{@errorName(e)}) };

        if (start_line == null and end_line == null)
            return .{ .output = content };

        defer allocator.free(content);
        var lines: std.ArrayList([]const u8) = .empty;
        defer lines.deinit(allocator);
        var iter = std.mem.splitScalar(u8, content, '\n');
        var i: i64 = 1;
        while (iter.next()) |line| : (i += 1) {
            if (start_line) |s| {
                if (i < s) continue;
            }
            if (end_line) |e| {
                if (i > e) break;
            }
            try lines.append(allocator, line);
        }
        return .{ .output = try std.mem.join(allocator, "\n", lines.items) };
    }
};

test "FileReadTool schema" {
    var tool = FileReadTool{};
    const handler = tools_interface.makeToolHandler(FileReadTool, &tool);
    try std.testing.expectEqualStrings("read_file", handler.schema.name);
}

test "FileReadTool read file" {
    const path = "_hermes_test_read.txt";
    try std.fs.cwd().writeFile(.{ .sub_path = path, .data = "line1\nline2\nline3\n" });
    defer std.fs.cwd().deleteFile(path) catch {};

    var tool = FileReadTool{};
    const handler = tools_interface.makeToolHandler(FileReadTool, &tool);

    var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, std.fmt.comptimePrint("{{\"path\":\"{s}\"}}", .{path}), .{});
    defer parsed.deinit();
    const result = try handler.execute(std.testing.allocator, parsed.value.object);
    defer std.testing.allocator.free(result.output);
    try std.testing.expect(std.mem.indexOf(u8, result.output, "line1") != null);
}
