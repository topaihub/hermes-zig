pub const cli = @import("cli/root.zig");

comptime {
    @import("std").testing.refAllDecls(@This());
}
