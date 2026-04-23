const std = @import("std");
const constants = @import("constants.zig");

pub const DEFAULT_SOUL = "You are Hermes, a helpful AI assistant. You are knowledgeable, concise, and friendly. You help users with coding, analysis, and general questions.";

pub fn getHermesHome(allocator: std.mem.Allocator) ![]u8 {
    return constants.getHermesHome(allocator);
}

pub fn loadSoul(allocator: std.mem.Allocator, hermes_home: []const u8) ![]u8 {
    const path = try std.fs.path.join(allocator, &.{ hermes_home, "SOUL.md" });
    defer allocator.free(path);
    var io_threaded: std.Io.Threaded = .init_single_threaded;
    const io_instance = io_threaded.io();
    const file = std.Io.Dir.openFileAbsolute(io_instance, path, .{}) catch |err| switch (err) {
        error.FileNotFound => return try allocator.dupe(u8, DEFAULT_SOUL),
        else => return err,
    };
    defer file.close(io_instance);
    var stream_buf: [4096]u8 = undefined;
    var file_reader = file.readerStreaming(io_instance, &stream_buf);
    return try file_reader.interface.allocRemaining(allocator, .limited(1024 * 1024));
}
