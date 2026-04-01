const std = @import("std");

pub fn chunkMessage(allocator: std.mem.Allocator, content: []const u8, max_len: usize) ![]const []const u8 {
    if (content.len == 0) {
        const result = try allocator.alloc([]const u8, 1);
        result[0] = "";
        return result;
    }
    var chunks = std.ArrayListUnmanaged([]const u8).empty;
    var pos: usize = 0;
    while (pos < content.len) {
        const end = @min(pos + max_len, content.len);
        try chunks.append(allocator, content[pos..end]);
        pos = end;
    }
    return chunks.toOwnedSlice(allocator);
}

test "chunkMessage splits correctly" {
    const allocator = std.testing.allocator;
    const chunks = try chunkMessage(allocator, "HelloWorld", 5);
    defer allocator.free(chunks);
    try std.testing.expectEqual(@as(usize, 2), chunks.len);
    try std.testing.expectEqualStrings("Hello", chunks[0]);
    try std.testing.expectEqualStrings("World", chunks[1]);
}

test "chunkMessage single chunk" {
    const allocator = std.testing.allocator;
    const chunks = try chunkMessage(allocator, "Hi", 10);
    defer allocator.free(chunks);
    try std.testing.expectEqual(@as(usize, 1), chunks.len);
    try std.testing.expectEqualStrings("Hi", chunks[0]);
}

test "chunkMessage empty content" {
    const allocator = std.testing.allocator;
    const chunks = try chunkMessage(allocator, "", 10);
    defer allocator.free(chunks);
    try std.testing.expectEqual(@as(usize, 1), chunks.len);
    try std.testing.expectEqualStrings("", chunks[0]);
}
