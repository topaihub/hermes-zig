const std = @import("std");

pub const McpServer = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) McpServer {
        return .{ .allocator = allocator };
    }

    pub fn serve(_: *McpServer) !void {
        return error.NotImplemented;
    }

    pub fn deinit(_: *McpServer) void {}
};
