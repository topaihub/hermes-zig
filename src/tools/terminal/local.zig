const std = @import("std");
const backend = @import("backend.zig");
const ExecResult = backend.ExecResult;

pub const LocalBackend = struct {
    pub fn execute(_: *LocalBackend, allocator: std.mem.Allocator, cmd: []const u8, cwd: []const u8, timeout_ms: u64) !ExecResult {
        _ = timeout_ms;
        var child = std.process.Child.init(&.{ "sh", "-c", cmd }, allocator);
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

    pub fn cleanup(_: *LocalBackend) !void {}
};

test "LocalBackend execute echo hello" {
    var lb = LocalBackend{};
    var result = try lb.execute(std.testing.allocator, "echo hello", ".", 5000);
    defer result.deinit();
    try std.testing.expectEqualStrings("hello\n", result.stdout);
    try std.testing.expectEqual(@as(u32, 0), result.exit_code);
    try std.testing.expect(result.isSuccess());
}
