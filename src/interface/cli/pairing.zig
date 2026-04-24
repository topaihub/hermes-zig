const std = @import("std");
const Allocator = std.mem.Allocator;

pub const PairingAction = enum { list, approve, revoke, clear_pending, unknown };

pub const ParsedPairing = struct {
    action: PairingAction = .unknown,
    platform: []const u8 = "",
    code: []const u8 = "",
};

pub fn parseArgs(args: []const u8) ParsedPairing {
    const trimmed = std.mem.trim(u8, args, " \t");
    if (trimmed.len == 0 or std.mem.eql(u8, trimmed, "list")) return .{ .action = .list };
    if (std.mem.eql(u8, trimmed, "clear-pending")) return .{ .action = .clear_pending };

    // "approve <platform> <code>" or "revoke <platform> <code>"
    var it = std.mem.splitScalar(u8, trimmed, ' ');
    const cmd = it.next() orelse return .{};
    const action: PairingAction = if (std.mem.eql(u8, cmd, "approve")) .approve else if (std.mem.eql(u8, cmd, "revoke")) .revoke else return .{};
    const platform = it.next() orelse return .{ .action = action };
    const code = it.next() orelse return .{ .action = action, .platform = platform };
    return .{ .action = action, .platform = platform, .code = code };
}

pub fn handlePairingCommand(allocator: Allocator, args: []const u8, stdout: std.Io.File) !void {
    const parsed = parseArgs(args);
    switch (parsed.action) {
        .list => try stdout.writeAll("  No paired devices.\n"),
        .approve => {
            const msg = try std.fmt.allocPrint(allocator, "  Approved {s} ({s})\n", .{ parsed.platform, parsed.code });
            defer allocator.free(msg);
            try stdout.writeAll(msg);
        },
        .revoke => {
            const msg = try std.fmt.allocPrint(allocator, "  Revoked {s} ({s})\n", .{ parsed.platform, parsed.code });
            defer allocator.free(msg);
            try stdout.writeAll(msg);
        },
        .clear_pending => try stdout.writeAll("  Cleared pending requests.\n"),
        .unknown => try stdout.writeAll("  Pairing subcommands: list, approve, revoke, clear-pending\n"),
    }
}

test "parse approve telegram ABC123" {
    const p = parseArgs("approve telegram ABC123");
    try std.testing.expectEqual(PairingAction.approve, p.action);
    try std.testing.expectEqualStrings("telegram", p.platform);
    try std.testing.expectEqualStrings("ABC123", p.code);
}
