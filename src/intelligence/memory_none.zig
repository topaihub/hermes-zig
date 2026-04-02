const std = @import("std");
const mi = @import("memory_interface.zig");

pub const MemoryNone = struct {
    pub fn memory(self: *MemoryNone) mi.Memory {
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

    fn storeFn(_: *MemoryNone, _: std.mem.Allocator, _: []const u8, _: []const u8, _: []const u8) !void {}
    fn recallFn(_: *MemoryNone, _: std.mem.Allocator, _: []const u8, _: u32) ![]mi.MemoryEntry { return &.{}; }
    fn getFn(_: *MemoryNone, _: std.mem.Allocator, _: []const u8) !?[]const u8 { return null; }
    fn forgetFn(_: *MemoryNone, _: std.mem.Allocator, _: []const u8) !void {}
    fn countFn(_: *MemoryNone) !u64 { return 0; }
    fn deinitFn(_: *MemoryNone) void {}
};

test "MemoryNone returns empty/null" {
    var mn = MemoryNone{};
    const m = mn.memory();
    try m.store(std.testing.allocator, "k", "v", "general");
    const got = try m.get(std.testing.allocator, "k");
    try std.testing.expectEqual(@as(?[]const u8, null), got);
    try std.testing.expectEqual(@as(u64, 0), try m.count());
}
