const std = @import("std");

pub const AuxiliaryClient = struct {
    llm_client: ?*anyopaque = null,

    pub fn summarize(self: *const AuxiliaryClient, allocator: std.mem.Allocator, text: []const u8, max_tokens: u32) ![]const u8 {
        _ = self;
        _ = max_tokens;
        // Stub: return truncated text as summary
        const limit = @min(text.len, 200);
        return allocator.dupe(u8, text[0..limit]);
    }

    pub fn generateTitle(self: *const AuxiliaryClient, allocator: std.mem.Allocator, messages: []const []const u8) ![]const u8 {
        _ = self;
        if (messages.len > 0) return allocator.dupe(u8, messages[0]);
        return allocator.dupe(u8, "Untitled");
    }
};

test "struct init" {
    const client = AuxiliaryClient{};
    try std.testing.expectEqual(@as(?*anyopaque, null), client.llm_client);
}
