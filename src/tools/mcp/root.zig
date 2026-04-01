pub const client = @import("client.zig");
pub const discovery = @import("discovery.zig");
pub const server = @import("server.zig");

pub const McpClient = client.McpClient;
pub const McpServer = server.McpServer;

comptime {
    @import("std").testing.refAllDecls(@This());
}
