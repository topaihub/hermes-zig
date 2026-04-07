const std = @import("std");
const backend = @import("backend.zig");
const ExecResult = backend.ExecResult;

pub const PersistentShellBackend = struct {
    shell_path: []const u8 = "/bin/sh",

    pub fn execute(self: *PersistentShellBackend, allocator: std.mem.Allocator, cmd: []const u8, cwd: []const u8, timeout_ms: u64) !ExecResult {
        _ = self;
        _ = timeout_ms;
        var child = std.process.Child.init(&.{ "/bin/sh", "-c", cmd }, allocator);
        child.cwd = if (cwd.len > 0 and !std.mem.eql(u8, cwd, ".")) cwd else null;
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

    pub fn cleanup(_: *PersistentShellBackend) !void {}
};

test "PersistentShellBackend init" {
    var ps = PersistentShellBackend{};
    try std.testing.expectEqualStrings("/bin/sh", ps.shell_path);
    try ps.cleanup();
}
