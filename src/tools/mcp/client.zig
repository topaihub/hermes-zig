const std = @import("std");

pub const McpClient = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) McpClient {
        return .{ .allocator = allocator };
    }

    pub fn connect(_: *McpClient, _: []const u8, _: []const []const u8) !void {
        return error.NotImplemented;
    }

    pub fn callTool(_: *McpClient, _: []const u8, _: []const u8) ![]const u8 {
        return error.NotImplemented;
    }

    pub fn deinit(_: *McpClient) void {}
};
