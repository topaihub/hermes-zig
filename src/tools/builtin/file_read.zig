const std = @import("std");
const tools_interface = @import("../interface.zig");

pub const FileReadTool = struct {
    pub const SCHEMA = tools_interface.ToolSchema{
        .name = "file_read",
        .description = "Read file contents, optionally a range of lines",
        .parameters_schema =
            \\{"type":"object","properties":{"path":{"type":"string"},"start_line":{"type":"integer"},"end_line":{"type":"integer"}},"required":["path"]}
        ,
    };

    pub fn execute(self: *FileReadTool, args_json: []const u8, ctx: *const tools_interface.ToolContext) anyerror![]const u8 {
        _ = self;
        const Args = struct { path: []const u8, start_line: ?i64 = null, end_line: ?i64 = null };
        const parsed = std.json.parseFromSlice(Args, ctx.allocator, args_json, .{ .ignore_unknown_fields = true }) catch
            return error.InvalidArgs;
        defer parsed.deinit();

        const content = std.fs.cwd().readFileAlloc(ctx.allocator, parsed.value.path, 10 * 1024 * 1024) catch |e|
            return std.fmt.allocPrint(ctx.allocator, "Error reading file: {s}", .{@errorName(e)});

        if (parsed.value.start_line == null and parsed.value.end_line == null)
            return content;

        defer ctx.allocator.free(content);
        var lines = std.ArrayList([]const u8).init(ctx.allocator);
        defer lines.deinit();
        var iter = std.mem.splitScalar(u8, content, '\n');
        var i: i64 = 1;
        while (iter.next()) |line| : (i += 1) {
            if (parsed.value.start_line) |s| { if (i < s) continue; }
            if (parsed.value.end_line) |e| { if (i > e) break; }
            try lines.append(line);
        }
        return std.mem.join(ctx.allocator, "\n", lines.items);
    }
};

test "FileReadTool schema" {
    var tool = FileReadTool{};
    const handler = tools_interface.makeToolHandler(FileReadTool, &tool);
    try std.testing.expectEqualStrings("file_read", handler.schema.name);
}

test "FileReadTool read file" {
    const path = "/tmp/_hermes_test_read.txt";
    try std.fs.cwd().writeFile(.{ .sub_path = path, .data = "line1\nline2\nline3\n" });
    defer std.fs.cwd().deleteFile(path) catch {};

    var tool = FileReadTool{};
    const handler = tools_interface.makeToolHandler(FileReadTool, &tool);
    const ctx = tools_interface.ToolContext{
        .session_source = .{ .platform = .cli, .chat_id = "test" },
        .allocator = std.testing.allocator,
    };
    const result = try handler.execute(std.fmt.comptimePrint("{{\"path\":\"{s}\"}}", .{path}), &ctx);
    defer std.testing.allocator.free(result);
    try std.testing.expect(std.mem.indexOf(u8, result, "line1") != null);
}
