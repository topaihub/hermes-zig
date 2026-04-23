const backend = @import("backend.zig");
const ExecResult = backend.ExecResult;
const std = @import("std");

pub const DockerBackend = struct {
    container: []const u8 = "",
    image: []const u8 = "",

    pub fn execute(self: *DockerBackend, allocator: std.mem.Allocator, cmd: []const u8, _: []const u8, _: u64) !ExecResult {
        const target = if (self.container.len > 0) self.container else self.image;
        
        var io = std.Io.Threaded.init(allocator, .{});
        defer io.deinit();
        
        var child = try std.process.spawn(io.io(), .{
            .argv = &.{ "docker", "exec", target, "sh", "-c", cmd },
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

    pub fn cleanup(_: *DockerBackend) !void {}
};

test "DockerBackend init" {
    var db = DockerBackend{ .container = "test-container", .image = "ubuntu" };
    try std.testing.expectEqualStrings("test-container", db.container);
    try std.testing.expectEqualStrings("ubuntu", db.image);
    try db.cleanup();
}
