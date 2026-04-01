const std = @import("std");
const Config = @import("config.zig").Config;

pub const LoadedConfig = struct {
    parsed: std.json.Parsed(Config),

    pub fn deinit(self: *LoadedConfig) void {
        self.parsed.deinit();
    }
};

pub fn loadFromString(json: []const u8, allocator: std.mem.Allocator) !LoadedConfig {
    return .{ .parsed = try std.json.parseFromSlice(Config, allocator, json, .{ .ignore_unknown_fields = true }) };
}

pub fn loadFromFile(path: []const u8, allocator: std.mem.Allocator) !LoadedConfig {
    const data = try std.fs.cwd().readFileAlloc(allocator, path, 1024 * 1024);
    defer allocator.free(data);
    return loadFromString(data, allocator);
}
