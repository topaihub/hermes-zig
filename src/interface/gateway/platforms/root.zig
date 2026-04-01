pub const telegram = @import("telegram.zig");
pub const TelegramAdapter = telegram.TelegramAdapter;

comptime {
    @import("std").testing.refAllDecls(@This());
}
