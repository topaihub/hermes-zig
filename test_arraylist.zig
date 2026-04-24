const std = @import("std");
pub fn main() !void {
    const allocator = std.heap.page_allocator;
    
    var list = std.ArrayList(u8).init(allocator);
    defer list.deinit();
}
