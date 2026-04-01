const std = @import("std");
const client = @import("client.zig");

pub fn discoverTools(_: *client.McpClient, _: std.mem.Allocator) !void {
    return error.NotImplemented;
}
