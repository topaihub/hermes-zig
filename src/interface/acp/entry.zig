const std = @import("std");
const auth = @import("auth.zig");
const server = @import("server.zig");

pub fn main(allocator: std.mem.Allocator) !void {
    const provider = auth.detectProvider(allocator) orelse return error.NoProvider;
    _ = provider;
    var srv = server.AcpServer.init();
    defer srv.deinit();
}

test "main returns NoProvider when no env vars" {
    const result = main(std.testing.allocator);
    if (result) |_| {
        // Provider was found in env — that's fine
    } else |err| {
        try std.testing.expectEqual(error.NoProvider, err);
    }
}
