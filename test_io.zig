const std = @import("std");

pub fn main() !void {
    // Test basic stdout writing
    const stdout = std.Io.File.stdout();
    
    var io = std.Io.Threaded.init(std.heap.page_allocator, .{});
    defer io.deinit();
    
    var buf: [1024]u8 = undefined;
    const writer = stdout.writer(io.io(), &buf);
    
    // Test if writer has writeAll
    _ = writer;
    
    std.debug.print("Test passed\n", .{});
}
