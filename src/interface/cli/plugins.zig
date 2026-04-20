const std = @import("std");

pub const PluginConfig = struct {
    name: []const u8 = "",
    enabled: bool = true,
};

pub const PluginManager = struct {
    plugins: std.ArrayList(PluginConfig),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) PluginManager {
        return .{ .plugins = .{}, .allocator = allocator };
    }

    pub fn deinit(self: *PluginManager) void {
        for (self.plugins.items) |plugin| {
            self.allocator.free(plugin.name);
        }
        self.plugins.deinit(self.allocator);
    }

    pub fn scan(self: *PluginManager, dir_path: []const u8) !void {
        var dir = std.fs.cwd().openDir(dir_path, .{ .iterate = true }) catch return;
        defer dir.close();
        var iter = dir.iterate();
        while (try iter.next()) |entry| {
            if (entry.kind == .directory) {
                const name = try self.allocator.dupe(u8, entry.name);
                errdefer self.allocator.free(name);
                try self.plugins.append(self.allocator, .{ .name = name });
            }
        }
    }

    pub fn list(self: *const PluginManager) []const PluginConfig {
        return self.plugins.items;
    }
};

test "PluginManager init and list" {
    var pm = PluginManager.init(std.testing.allocator);
    defer pm.deinit();
    try std.testing.expectEqual(@as(usize, 0), pm.list().len);
}

test "PluginManager scan nonexistent dir" {
    var pm = PluginManager.init(std.testing.allocator);
    defer pm.deinit();
    try pm.scan("_hermes_nonexistent_plugins_dir");
    try std.testing.expectEqual(@as(usize, 0), pm.list().len);
}
