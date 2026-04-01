const backend = @import("backend.zig");
const ExecResult = backend.ExecResult;
const std = @import("std");

pub const DockerBackend = struct {
    container: []const u8 = "",
    image: []const u8 = "",

    pub fn execute(self: *DockerBackend, allocator: std.mem.Allocator, cmd: []const u8, _: []const u8, _: u64) !ExecResult {
        const target = if (self.container.len > 0) self.container else self.image;
        var child = std.process.Child{
            .argv = &.{ "docker", "exec", target, "sh", "-c", cmd },
            .stdout_behavior = .Pipe,
            .stderr_behavior = .Pipe,
        };
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

    pub fn cleanup(_: *DockerBackend) !void {}
};

test "DockerBackend init" {
    var db = DockerBackend{ .container = "test-container", .image = "ubuntu" };
    try std.testing.expectEqualStrings("test-container", db.container);
    try std.testing.expectEqualStrings("ubuntu", db.image);
    try db.cleanup();
}
