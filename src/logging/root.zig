pub const rotating_file_sink = @import("rotating_file_sink.zig");
pub const RotatingFileSink = rotating_file_sink.RotatingFileSink;

test {
    @import("std").testing.refAllDecls(@This());
}
