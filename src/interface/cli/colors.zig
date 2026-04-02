pub const reset = "\x1b[0m";
pub const bold = "\x1b[1m";
pub const dim = "\x1b[2m";
pub const red = "\x1b[31m";
pub const green = "\x1b[32m";
pub const yellow = "\x1b[33m";
pub const blue = "\x1b[34m";
pub const cyan = "\x1b[36m";
pub const white = "\x1b[37m";
pub const bg_red = "\x1b[41m";
pub const bg_green = "\x1b[42m";

const std = @import("std");

test "constants non-empty" {
    try std.testing.expect(reset.len > 0);
    try std.testing.expect(bold.len > 0);
    try std.testing.expect(dim.len > 0);
    try std.testing.expect(red.len > 0);
    try std.testing.expect(green.len > 0);
    try std.testing.expect(yellow.len > 0);
    try std.testing.expect(blue.len > 0);
    try std.testing.expect(cyan.len > 0);
    try std.testing.expect(white.len > 0);
    try std.testing.expect(bg_red.len > 0);
    try std.testing.expect(bg_green.len > 0);
}
