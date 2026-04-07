const backend = @import("backend.zig");
const ExecResult = backend.ExecResult;
const std = @import("std");

pub const SshBackend = struct {
    host: []const u8 = "",
    user: []const u8 = "",
    port: u16 = 22,

    pub fn execute(self: *SshBackend, allocator: std.mem.Allocator, cmd: []const u8, _: []const u8, _: u64) !ExecResult {
        const port_str = try std.fmt.allocPrint(allocator, "{d}", .{self.port});
        defer allocator.free(port_str);
        const target = try std.fmt.allocPrint(allocator, "{s}@{s}", .{ self.user, self.host });
        defer allocator.free(target);
        var child = std.process.Child.init(&.{ "ssh", target, "-p", port_str, "sh", "-c", cmd }, allocator);
        child.stdout_behavior = .Pipe;
        child.stderr_behavior = .Pipe;
        try child.spawn();
        const stdout = try child.stdout.?.readToEndAlloc(allocator, 1024 * 1024);
        const stderr = try child.stderr.?.readToEndAlloc(allocator, 1024 * 1024);
        const term = try child.wait();
        return .{
            .stdout = stdout,
            .stderr = stderr,
            .exit_code = if (term == .Exited) term.Exited else 1,
            .allocator = allocator,
        };
    }

    pub fn cleanup(_: *SshBackend) !void {}
};

test "SshBackend init" {
    var sb = SshBackend{ .host = "example.com", .user = "deploy", .port = 2222 };
    try std.testing.expectEqualStrings("example.com", sb.host);
    try std.testing.expectEqualStrings("deploy", sb.user);
    try std.testing.expectEqual(@as(u16, 2222), sb.port);
    try sb.cleanup();
}
