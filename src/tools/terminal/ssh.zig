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
        
        var io = std.Io.Threaded.init(allocator, .{});
        defer io.deinit();
        
        var child = try std.process.spawn(io.io(), .{
            .argv = &.{ "ssh", target, "-p", port_str, "sh", "-c", cmd },
            .stdout = .pipe,
            .stderr = .pipe,
        });
        
        var stdout_buf: [4096]u8 = undefined;
        var stderr_buf: [4096]u8 = undefined;
        var stdout_reader = child.stdout.?.reader(io.io(), &stdout_buf);
        var stderr_reader = child.stderr.?.reader(io.io(), &stderr_buf);
        
        const stdout = try stdout_reader.interface.allocRemaining(allocator, @enumFromInt(1024 * 1024));
        errdefer allocator.free(stdout);
        const stderr = try stderr_reader.interface.allocRemaining(allocator, @enumFromInt(1024 * 1024));
        
        if (child.stdout) |f| f.close(io.io());
        if (child.stderr) |f| f.close(io.io());
        
        const term = try child.wait(io.io());
        return .{
            .stdout = stdout,
            .stderr = stderr,
            .exit_code = if (term == .exited) term.exited else 1,
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
