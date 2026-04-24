const std = @import("std");

test "file api" {
    const io = std.testing.io;
    const cwd = std.fs.cwd(io);
    const file = try cwd.openFile(io, "test.txt", .{});
    defer file.close(io);
}
