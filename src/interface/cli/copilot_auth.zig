const std = @import("std");

pub const DeviceFlowResult = struct {
    device_code: []const u8 = "",
    user_code: []const u8 = "",
    verification_uri: []const u8 = "",
};

pub const CopilotAuth = struct {
    pub fn isTokenValid(token: []const u8) bool {
        return std.mem.startsWith(u8, token, "gho_") or
            std.mem.startsWith(u8, token, "github_pat_") or
            std.mem.startsWith(u8, token, "ghu_");
    }

    pub fn startDeviceFlow() DeviceFlowResult {
        return .{};
    }

    pub fn pollForToken() ?[]const u8 {
        return null;
    }
};

test "isTokenValid" {
    try std.testing.expect(CopilotAuth.isTokenValid("gho_abc123"));
    try std.testing.expect(CopilotAuth.isTokenValid("github_pat_xyz"));
    try std.testing.expect(CopilotAuth.isTokenValid("ghu_test"));
    try std.testing.expect(!CopilotAuth.isTokenValid("invalid"));
    try std.testing.expect(!CopilotAuth.isTokenValid(""));
}
