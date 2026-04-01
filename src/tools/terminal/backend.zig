const std = @import("std");
const local = @import("local.zig");
const docker = @import("docker.zig");
const ssh = @import("ssh.zig");
const daytona = @import("daytona.zig");
const singularity = @import("singularity.zig");
const modal = @import("modal.zig");
const config = @import("../../core/config.zig");

pub const ExecResult = struct {
    stdout: []const u8,
    stderr: []const u8,
    exit_code: u32,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *ExecResult) void {
        self.allocator.free(self.stdout);
        self.allocator.free(self.stderr);
    }

    pub fn isSuccess(self: ExecResult) bool {
        return self.exit_code == 0;
    }
};

pub const TerminalBackend = union(enum) {
    local: local.LocalBackend,
    docker: docker.DockerBackend,
    ssh: ssh.SshBackend,
    daytona: daytona.DaytonaBackend,
    singularity: singularity.SingularityBackend,
    modal: modal.ModalBackend,

    pub fn execute(self: *TerminalBackend, allocator: std.mem.Allocator, cmd: []const u8, cwd: []const u8, timeout_ms: u64) !ExecResult {
        return switch (self.*) {
            .local => |*b| b.execute(allocator, cmd, cwd, timeout_ms),
            .docker => |*b| b.execute(allocator, cmd, cwd, timeout_ms),
            .ssh => |*b| b.execute(allocator, cmd, cwd, timeout_ms),
            .daytona => |*b| b.execute(allocator, cmd, cwd, timeout_ms),
            .singularity => |*b| b.execute(allocator, cmd, cwd, timeout_ms),
            .modal => |*b| b.execute(allocator, cmd, cwd, timeout_ms),
        };
    }

    pub fn cleanup(self: *TerminalBackend) !void {
        return switch (self.*) {
            .local => |*b| b.cleanup(),
            .docker => |*b| b.cleanup(),
            .ssh => |*b| b.cleanup(),
            .daytona => |*b| b.cleanup(),
            .singularity => |*b| b.cleanup(),
            .modal => |*b| b.cleanup(),
        };
    }

    pub fn fromConfig(cfg: config.TerminalConfig) TerminalBackend {
        if (std.mem.eql(u8, cfg.backend, "docker")) return .{ .docker = .{ .container = cfg.docker_image, .image = cfg.docker_image } };
        if (std.mem.eql(u8, cfg.backend, "ssh")) return .{ .ssh = .{ .host = cfg.ssh_host, .user = cfg.ssh_user, .port = cfg.ssh_port } };
        if (std.mem.eql(u8, cfg.backend, "daytona")) return .{ .daytona = .{} };
        if (std.mem.eql(u8, cfg.backend, "singularity")) return .{ .singularity = .{} };
        if (std.mem.eql(u8, cfg.backend, "modal")) return .{ .modal = .{} };
        return .{ .local = .{} };
    }
};
