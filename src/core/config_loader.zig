const std = @import("std");
const Config = @import("config.zig").Config;

pub const LoadedConfig = struct {
    parsed: std.json.Parsed(Config),

    pub fn deinit(self: *LoadedConfig) void {
        self.parsed.deinit();
    }
};

pub fn loadFromString(json: []const u8, allocator: std.mem.Allocator) !LoadedConfig {
    return .{ .parsed = try std.json.parseFromSlice(Config, allocator, json, .{
        .ignore_unknown_fields = true,
        .allocate = .alloc_always,
    }) };
}

pub fn loadFromFile(path: []const u8, allocator: std.mem.Allocator) !LoadedConfig {
    var io = std.Io.Threaded.init(allocator, .{});
    defer io.deinit();
    
    const cwd = std.Io.Dir.cwd();
    const file = try std.Io.Dir.openFile(cwd, io.io(), path, .{});
    defer file.close(io.io());
    
    var read_buf: [4096]u8 = undefined;
    var reader = file.reader(io.io(), &read_buf);
    const data = try reader.interface.allocRemaining(allocator, @enumFromInt(1024 * 1024));
    defer allocator.free(data);
    return loadFromString(data, allocator);
}
