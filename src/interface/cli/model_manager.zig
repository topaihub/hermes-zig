const std = @import("std");

pub const ModelManager = struct {
    config_path: []const u8 = "config.json",

    pub fn listModels(self: *const ModelManager, allocator: std.mem.Allocator, writer: anytype) !void {
        const content = std.fs.cwd().readFileAlloc(allocator, self.config_path, 64 * 1024) catch {
            try writer.writeAll("No config found.\n");
            return;
        };
        defer allocator.free(content);
        const parsed = std.json.parseFromSlice(struct { models: []const []const u8 = &.{} }, allocator, content, .{ .ignore_unknown_fields = true }) catch {
            try writer.writeAll("Config parse error.\n");
            return;
        };
        defer parsed.deinit();
        for (parsed.value.models) |m| try writer.print("  {s}\n", .{m});
    }

    pub fn switchModel(self: *const ModelManager, writer: anytype, model: []const u8) !void {
        _ = self;
        try writer.print("Switched to: {s}\n", .{model});
    }

    pub fn validateModel(model: []const u8) bool {
        return model.len > 0;
    }
};

test "struct init" {
    const mgr = ModelManager{};
    try std.testing.expectEqualStrings("config.json", mgr.config_path);
}

test "validateModel" {
    try std.testing.expect(ModelManager.validateModel("gpt-4o"));
    try std.testing.expect(!ModelManager.validateModel(""));
}
