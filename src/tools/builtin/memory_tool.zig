const std = @import("std");
const tools_interface = @import("../interface.zig");

pub const MemoryTool = struct {
    storage_dir: []const u8,

    pub const SCHEMA = tools_interface.ToolSchema{
        .name = "memory",
        .description = "Persistent memory: read, write, or search key-value pairs",
        .parameters_schema =
            \\{"type":"object","properties":{"action":{"type":"string","enum":["read","write","search"]},"key":{"type":"string"},"content":{"type":"string"}},"required":["action"]}
        ,
    };

    pub fn execute(self: *MemoryTool, args_json: []const u8, ctx: *const tools_interface.ToolContext) anyerror![]const u8 {
        const Args = struct { action: []const u8, key: ?[]const u8 = null, content: ?[]const u8 = null };
        const parsed = std.json.parseFromSlice(Args, ctx.allocator, args_json, .{ .ignore_unknown_fields = true }) catch
            return error.InvalidArgs;
        defer parsed.deinit();

        std.fs.cwd().makePath(self.storage_dir) catch {};
        const action = parsed.value.action;

        if (std.mem.eql(u8, action, "write")) {
            const key = parsed.value.key orelse return error.InvalidArgs;
            const content = parsed.value.content orelse return error.InvalidArgs;
            const path = try std.fmt.allocPrint(ctx.allocator, "{s}/{s}", .{ self.storage_dir, key });
            defer ctx.allocator.free(path);
            std.fs.cwd().writeFile(.{ .sub_path = path, .data = content }) catch |e|
                return std.fmt.allocPrint(ctx.allocator, "Error: {s}", .{@errorName(e)});
            return std.fmt.allocPrint(ctx.allocator, "Stored key: {s}", .{key});
        }
        if (std.mem.eql(u8, action, "read")) {
            const key = parsed.value.key orelse return error.InvalidArgs;
            const path = try std.fmt.allocPrint(ctx.allocator, "{s}/{s}", .{ self.storage_dir, key });
            defer ctx.allocator.free(path);
            return std.fs.cwd().readFileAlloc(ctx.allocator, path, 1024 * 1024) catch
                return std.fmt.allocPrint(ctx.allocator, "Key not found: {s}", .{key});
        }
        if (std.mem.eql(u8, action, "search")) {
            const pattern = parsed.value.key orelse "";
            var dir = std.fs.cwd().openDir(self.storage_dir, .{ .iterate = true }) catch
                return try ctx.allocator.dupe(u8, "No memories stored");
            defer dir.close();
            var buf: std.ArrayList(u8) = .{};
            defer buf.deinit(ctx.allocator);
            var iter = dir.iterate();
            while (try iter.next()) |entry| {
                if (pattern.len == 0 or std.mem.indexOf(u8, entry.name, pattern) != null) {
                    try buf.print(ctx.allocator, "{s}\n", .{entry.name});
                }
            }
            return if (buf.items.len > 0) try buf.toOwnedSlice(ctx.allocator) else try ctx.allocator.dupe(u8, "No matches");
        }
        return error.InvalidArgs;
    }
};

test "MemoryTool schema" {
    var tool = MemoryTool{ .storage_dir = "/tmp/_hermes_test_memory" };
    const handler = tools_interface.makeToolHandler(MemoryTool, &tool);
    try std.testing.expectEqualStrings("memory", handler.schema.name);
}
