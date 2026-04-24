const std = @import("std");

pub fn main() !void {
    const stdout = std.Io.File.stdout();
    
    var io = std.Io.Threaded.init(std.heap.page_allocator, .{});
    defer io.deinit();
    
    var buf: [1024]u8 = undefined;
    var writer = stdout.writer(io.io(), &buf);
    
    // Test different write methods
    const text = "Hello World\n";
    _ = try writer.interface.drain(&writer.interface, &.{text}, 0);
    
    std.debug.print("Test passed\n", .{});
}
