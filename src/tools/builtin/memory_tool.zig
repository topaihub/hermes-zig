const std = @import("std");
const tools_interface = @import("../interface.zig");
const ToolResult = tools_interface.ToolResult;

pub const MemoryTool = struct {
    storage_dir: []const u8,

    pub const SCHEMA = tools_interface.ToolSchema{
        .name = "memory",
        .description = "Persistent memory: read, write, or search key-value pairs",
        .parameters_schema =
            \\{"type":"object","properties":{"action":{"type":"string","enum":["read","write","search"]},"key":{"type":"string"},"content":{"type":"string"}},"required":["action"]}
        ,
    };

    pub fn execute(self: *MemoryTool, allocator: std.mem.Allocator, args: std.json.ObjectMap) anyerror!ToolResult {
        const action = tools_interface.getString(args, "action") orelse return .{ .output = "missing action", .is_error = true };

        var io = std.Io.Threaded.init(allocator, .{});
        defer io.deinit();
        const cwd = std.Io.Dir.cwd();
        cwd.createDirPath(io.io(), self.storage_dir) catch {};

        if (std.mem.eql(u8, action, "write")) {
            const key = tools_interface.getString(args, "key") orelse return .{ .output = "missing key", .is_error = true };
            const content = tools_interface.getString(args, "content") orelse return .{ .output = "missing content", .is_error = true };
            const path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ self.storage_dir, key });
            defer allocator.free(path);
            
            const file = std.Io.Dir.createFile(cwd, io.io(), path, .{}) catch |e|
                return .{ .output = try std.fmt.allocPrint(allocator, "Error: {s}", .{@errorName(e)}), .is_error = true };
            defer file.close(io.io());
            
            var write_buf: [4096]u8 = undefined;
            var writer = file.writer(io.io(), &write_buf);
            writer.interface.writeAll(content) catch |e|
                return .{ .output = try std.fmt.allocPrint(allocator, "Error: {s}", .{@errorName(e)}), .is_error = true };
            
            return .{ .output = try std.fmt.allocPrint(allocator, "Stored key: {s}", .{key}) };
        }
        if (std.mem.eql(u8, action, "read")) {
            const key = tools_interface.getString(args, "key") orelse return .{ .output = "missing key", .is_error = true };
            const path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ self.storage_dir, key });
            defer allocator.free(path);
            
            var io_read = std.Io.Threaded.init(allocator, .{});
            defer io_read.deinit();
            const cwd_read = std.Io.Dir.cwd();
            
            const file = std.Io.Dir.openFile(cwd_read, io_read.io(), path, .{}) catch
                return .{ .output = try std.fmt.allocPrint(allocator, "Key not found: {s}", .{key}) };
            defer file.close(io_read.io());
            
            var read_buf: [4096]u8 = undefined;
            var reader = file.reader(io_read.io(), &read_buf);
            return .{ .output = try reader.interface.allocRemaining(allocator, @enumFromInt(1024 * 1024)) };
        }
        if (std.mem.eql(u8, action, "search")) {
            const pattern = tools_interface.getString(args, "key") orelse "";
            
            var io_search = std.Io.Threaded.init(allocator, .{});
            defer io_search.deinit();
            const cwd_search = std.Io.Dir.cwd();
            
            var dir = std.Io.Dir.openDir(cwd_search, io_search.io(), self.storage_dir, .{ .iterate = true }) catch
                return .{ .output = try allocator.dupe(u8, "No memories stored") };
            defer dir.close(io_search.io());
            
            var buf: std.ArrayList(u8) = .empty;
            defer buf.deinit(allocator);
            var iter = dir.iterate();
            while (try iter.next(io_search.io())) |entry| {
                if (pattern.len == 0 or std.mem.indexOf(u8, entry.name, pattern) != null) {
                    const line = try std.fmt.allocPrint(allocator, "{s}\n", .{entry.name});
                    defer allocator.free(line);
                    try buf.appendSlice(allocator, line);
                }
            }
            return .{ .output = if (buf.items.len > 0) try buf.toOwnedSlice(allocator) else try allocator.dupe(u8, "No matches") };
        }
        return .{ .output = "unknown action", .is_error = true };
    }
};

test "MemoryTool schema" {
    var tool = MemoryTool{ .storage_dir = "_hermes_test_memory" };
    const handler = tools_interface.makeToolHandler(MemoryTool, &tool);
    try std.testing.expectEqualStrings("memory", handler.schema.name);
}
