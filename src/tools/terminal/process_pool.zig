const std = @import("std");

pub const ProcessStatus = enum { running, exited };

pub const ProcessInfo = struct {
    id: u32,
    command: []const u8,
    status: ProcessStatus = .running,
    exit_code: ?u32 = null,
    stdout_buffer: std.ArrayList(u8),

    pub fn deinit(self: *ProcessInfo) void {
        self.stdout_buffer.deinit();
    }
};

pub const ProcessPool = struct {
    map: std.StringHashMap(ProcessInfo),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) ProcessPool {
        return .{ .map = std.StringHashMap(ProcessInfo).init(allocator), .allocator = allocator };
    }

    pub fn deinit(self: *ProcessPool) void {
        var it = self.map.iterator();
        while (it.next()) |entry| {
            var info = entry.value_ptr;
            info.deinit();
        }
        self.map.deinit();
    }

    pub fn spawn(self: *ProcessPool, name: []const u8, command: []const u8) !void {
        try self.map.put(name, .{
            .id = @intCast(self.map.count()),
            .command = command,
            .status = .running,
            .stdout_buffer = std.ArrayList(u8).init(self.allocator),
        });
    }

    pub fn poll(self: *ProcessPool, name: []const u8) ?ProcessStatus {
        const info = self.map.getPtr(name) orelse return null;
        return info.status;
    }

    pub fn getOutput(self: *ProcessPool, name: []const u8) ?[]const u8 {
        const info = self.map.getPtr(name) orelse return null;
        return info.stdout_buffer.items;
    }

    pub fn kill(self: *ProcessPool, name: []const u8) bool {
        const info = self.map.getPtr(name) orelse return false;
        info.status = .exited;
        info.exit_code = 137;
        return true;
    }
};

test "ProcessPool spawn and poll" {
    var pool = ProcessPool.init(std.testing.allocator);
    defer pool.deinit();
    try pool.spawn("test", "echo hello");
    try std.testing.expectEqual(ProcessStatus.running, pool.poll("test").?);
    try std.testing.expectEqual(@as(?ProcessStatus, null), pool.poll("nonexistent"));
}

test "ProcessPool kill" {
    var pool = ProcessPool.init(std.testing.allocator);
    defer pool.deinit();
    try pool.spawn("bg", "sleep 100");
    try std.testing.expect(pool.kill("bg"));
    try std.testing.expectEqual(ProcessStatus.exited, pool.poll("bg").?);
    try std.testing.expect(!pool.kill("nonexistent"));
}
