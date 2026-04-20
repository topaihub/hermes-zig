const std = @import("std");

const BANNER =
    \\  _   _                              
    \\ | | | | ___ _ __ _ __ ___   ___  ___ 
    \\ | |_| |/ _ \ '__| '_ ` _ \ / _ \/ __|
    \\ |  _  |  __/ |  | | | | | |  __/\__ \
    \\ |_| |_|\___|_|  |_| |_| |_|\___||___/
    \\
;

pub fn renderBanner(writer: anytype) !void {
    try writer.writeAll(BANNER);
}

test "renderBanner writes output" {
    var buf: [512]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    try renderBanner(fbs.writer());
    try std.testing.expect(fbs.getWritten().len > 0);
    try std.testing.expect(std.mem.indexOf(u8, fbs.getWritten(), "| |_| |") != null);
}
