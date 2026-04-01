pub const cli = @import("cli/root.zig");
pub const gateway = @import("gateway/root.zig");
pub const acp = @import("acp/root.zig");

comptime {
    @import("std").testing.refAllDecls(@This());
}
