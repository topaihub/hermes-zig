const std = @import("std");

pub const SetupWizard = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) SetupWizard {
        return .{ .allocator = allocator };
    }

    /// Interactive setup: select provider, enter key, select model.
    pub fn run(self: *SetupWizard) !void {
        _ = self;
        // Stub: would prompt user interactively
    }

    pub fn deinit(self: *SetupWizard) void {
        _ = self;
    }
};

test "SetupWizard init" {
    var wiz = SetupWizard.init(std.testing.allocator);
    defer wiz.deinit();
    try std.testing.expectEqual(std.testing.allocator, wiz.allocator);
}
