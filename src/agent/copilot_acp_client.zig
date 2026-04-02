const std = @import("std");

pub const CopilotClient = struct {
    token: ?[]const u8 = null,

    pub fn isAvailable(self: *const CopilotClient) bool {
        _ = self;
        const val = std.process.getEnvVarOwned(std.heap.page_allocator, "GITHUB_TOKEN") catch return false;
        std.heap.page_allocator.free(val);
        return true;
    }
};

test "struct init" {
    const client = CopilotClient{};
    try std.testing.expectEqual(@as(?[]const u8, null), client.token);
}
