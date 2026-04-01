const std = @import("std");

pub fn shouldNudge(turn_count: u32, interval: u32) bool {
    if (interval == 0) return false;
    return turn_count > 0 and turn_count % interval == 0;
}

test "shouldNudge at correct intervals" {
    try std.testing.expect(!shouldNudge(0, 5));
    try std.testing.expect(!shouldNudge(3, 5));
    try std.testing.expect(shouldNudge(5, 5));
    try std.testing.expect(shouldNudge(10, 5));
    try std.testing.expect(!shouldNudge(7, 5));
}

test "shouldNudge zero interval never nudges" {
    try std.testing.expect(!shouldNudge(5, 0));
}
