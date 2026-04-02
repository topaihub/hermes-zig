const std = @import("std");
const mi = @import("memory_interface.zig");
const persistent = @import("memory_persistent.zig");

pub const MemoryMarkdown = struct {
    path: []const u8,

    pub fn init(path: []const u8) MemoryMarkdown {
        return .{ .path = path };
    }

    pub fn memory(self: *MemoryMarkdown) mi.Memory {
        return .{ .ptr = @ptrCast(self), .vtable = &vtable };
    }

    const vtable = mi.Memory.VTable{
        .store = @ptrCast(&storeFn),
        .recall = @ptrCast(&recallFn),
        .get = @ptrCast(&getFn),
        .forget = @ptrCast(&forgetFn),
        .count = @ptrCast(&countFn),
        .deinit = @ptrCast(&deinitFn),
    };

    fn storeFn(self: *MemoryMarkdown, _: std.mem.Allocator, key: []const u8, content: []const u8, _: []const u8) !void {
        const entry = try std.fmt.allocPrint(std.heap.page_allocator, "\n## {s}\n{s}\n", .{ key, content });
        defer std.heap.page_allocator.free(entry);
        try persistent.appendMemory(self.path, entry);
    }

    fn recallFn(_: *MemoryMarkdown, _: std.mem.Allocator, _: []const u8, _: u32) ![]mi.MemoryEntry {
        return &.{};
    }

    fn getFn(self: *MemoryMarkdown, allocator: std.mem.Allocator, _: []const u8) !?[]const u8 {
        return persistent.readMemory(allocator, self.path);
    }

    fn forgetFn(_: *MemoryMarkdown, _: std.mem.Allocator, _: []const u8) !void {}
    fn countFn(_: *MemoryMarkdown) !u64 { return 0; }
    fn deinitFn(_: *MemoryMarkdown) void {}
};

test "MemoryMarkdown init" {
    var mm = MemoryMarkdown.init("MEMORY.md");
    const m = mm.memory();
    try std.testing.expectEqual(@as(u64, 0), try m.count());
}
