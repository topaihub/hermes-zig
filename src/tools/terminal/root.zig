pub const backend = @import("backend.zig");
pub const local = @import("local.zig");
pub const docker = @import("docker.zig");
pub const ssh = @import("ssh.zig");
pub const daytona = @import("daytona.zig");
pub const singularity = @import("singularity.zig");
pub const modal = @import("modal.zig");
pub const persistent_shell = @import("persistent_shell.zig");
pub const process_pool = @import("process_pool.zig");

pub const TerminalBackend = backend.TerminalBackend;
pub const ExecResult = backend.ExecResult;
pub const LocalBackend = local.LocalBackend;
pub const PersistentShellBackend = persistent_shell.PersistentShellBackend;
pub const ProcessPool = process_pool.ProcessPool;

comptime {
    @import("std").testing.refAllDecls(@This());
}
