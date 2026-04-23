const std = @import("std");
const backend = @import("backend.zig");
const ExecResult = backend.ExecResult;

pub const PersistentShellBackend = struct {
    shell_path: []const u8 = "/bin/sh",

    pub fn execute(self: *PersistentShellBackend, allocator: std.mem.Allocator, cmd: []const u8, cwd: []const u8, timeout_ms: u64) !ExecResult {
        _ = self;
        _ = timeout_ms;
        
        var io = std.Io.Threaded.init(allocator, .{});
        defer io.deinit();
        
        const cwd_option: std.process.Child.Cwd = if (cwd.len > 0 and !std.mem.eql(u8, cwd, "."))
            .{ .path = cwd }
        else
            .inherit;
        
        var child = try std.process.spawn(io.io(), .{
            .argv = &.{ "/bin/sh", "-c", cmd },
            .cwd = cwd_option,
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

    pub fn cleanup(_: *PersistentShellBackend) !void {}
};

test "PersistentShellBackend init" {
    var ps = PersistentShellBackend{};
    try std.testing.expectEqualStrings("/bin/sh", ps.shell_path);
    try ps.cleanup();
}
