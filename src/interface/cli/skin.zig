const std = @import("std");

pub const Theme = struct {
    fg: []const u8 = "white",
    bg: []const u8 = "black",
    accent: []const u8 = "cyan",
    error_color: []const u8 = "red",
    warning_color: []const u8 = "yellow",
};

pub const SkinEngine = struct {
    theme: Theme = .{},

    pub fn loadFromJson(allocator: std.mem.Allocator, json_str: []const u8) !SkinEngine {
        const parsed = std.json.parseFromSlice(Theme, allocator, json_str, .{ .ignore_unknown_fields = true }) catch
            return .{};
        defer parsed.deinit();
        return .{ .theme = parsed.value };
    }

    pub fn colorLookup(self: *const SkinEngine, name: []const u8) []const u8 {
        if (std.mem.eql(u8, name, "fg")) return self.theme.fg;
        if (std.mem.eql(u8, name, "bg")) return self.theme.bg;
        if (std.mem.eql(u8, name, "accent")) return self.theme.accent;
        if (std.mem.eql(u8, name, "error")) return self.theme.error_color;
        if (std.mem.eql(u8, name, "warning")) return self.theme.warning_color;
        return self.theme.fg;
    }
};

test "SkinEngine default theme" {
    const engine = SkinEngine{};
    try std.testing.expectEqualStrings("white", engine.colorLookup("fg"));
    try std.testing.expectEqualStrings("cyan", engine.colorLookup("accent"));
    try std.testing.expectEqualStrings("red", engine.colorLookup("error"));
}

test "SkinEngine loadFromJson" {
    const json = "{\"fg\":\"green\",\"accent\":\"blue\"}";
    const engine = try SkinEngine.loadFromJson(std.testing.allocator, json);
    try std.testing.expectEqualStrings("green", engine.colorLookup("fg"));
    try std.testing.expectEqualStrings("blue", engine.colorLookup("accent"));
}
