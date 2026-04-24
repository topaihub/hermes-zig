const std = @import("std");

pub fn main() !void {
    const term: std.process.Child.Term = .{ .exited = 0 };
    std.debug.print("Term: {}\n", .{term});
}
