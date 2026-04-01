pub const approval = @import("approval.zig");
pub const injection = @import("injection.zig");
pub const path_safety = @import("path_safety.zig");
pub const env_filter = @import("env_filter.zig");

pub const checkApproval = approval.checkApproval;
pub const ApprovalResult = approval.ApprovalResult;
pub const scanForInjection = injection.scanForInjection;
pub const InjectionAlert = injection.InjectionAlert;
pub const resolveSafePath = path_safety.resolveSafePath;
pub const isSensitiveKey = env_filter.isSensitiveKey;

comptime {
    @import("std").testing.refAllDecls(@This());
}
