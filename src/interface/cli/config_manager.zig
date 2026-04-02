const std = @import("std");
const config_loader = @import("../../core/config_loader.zig");

pub const ConfigManager = struct {
    allocator: std.mem.Allocator,
    config_path: []const u8 = "config.json",

    pub fn loadConfig(self: *const ConfigManager) !config_loader.LoadedConfig {
        return config_loader.loadFromFile(self.config_path, self.allocator);
    }

    pub fn saveConfig(self: *const ConfigManager, json: []const u8) !void {
        var file = try std.fs.cwd().createFile(self.config_path, .{});
        defer file.close();
        try file.writeAll(json);
    }

    pub fn showConfig(self: *const ConfigManager, writer: anytype) !void {
        const content = std.fs.cwd().readFileAlloc(self.allocator, self.config_path, 64 * 1024) catch {
            try writer.writeAll("No config found.\n");
            return;
        };
        defer self.allocator.free(content);
        try writer.writeAll(content);
    }

    pub fn editConfig(self: *const ConfigManager, writer: anytype) !void {
        try writer.print("Edit config at: {s}\n", .{self.config_path});
    }
};

test "struct init" {
    const mgr = ConfigManager{ .allocator = std.testing.allocator };
    try std.testing.expectEqualStrings("config.json", mgr.config_path);
}
