const std = @import("std");
const tools_interface = @import("../interface.zig");
const ToolResult = tools_interface.ToolResult;

pub const CheckpointTool = struct {
    pub const SCHEMA = tools_interface.ToolSchema{
        .name = "checkpoint",
        .description = "Create, list, rollback, or diff checkpoints",
        .parameters_schema =
            \\{"type":"object","properties":{"action":{"type":"string","enum":["create","list","rollback","diff"],"description":"Checkpoint action"},"id":{"type":"string","description":"Checkpoint ID"}},"required":["action"]}
        ,
    };

    pub fn execute(self: *CheckpointTool, allocator: std.mem.Allocator, args: std.json.ObjectMap) anyerror!ToolResult {
        _ = self;
        const action = tools_interface.getString(args, "action") orelse return .{ .output = "missing action", .is_error = true };

        if (std.mem.eql(u8, action, "create")) {
            const msg = tools_interface.getString(args, "id") orelse "checkpoint";
            _ = runGit(allocator, &.{ "git", "init" }) catch {};
            _ = try runGit(allocator, &.{ "git", "add", "-A" });
            const out = runGit(allocator, &.{ "git", "commit", "-m", msg, "--allow-empty" }) catch |err| {
                return .{ .output = try std.fmt.allocPrint(allocator, "git commit failed: {s}", .{@errorName(err)}), .is_error = true };
            };
            defer allocator.free(out);
            return .{ .output = try allocator.dupe(u8, out) };
        } else if (std.mem.eql(u8, action, "list")) {
            const out = runGit(allocator, &.{ "git", "log", "--oneline", "-20" }) catch |err| {
                return .{ .output = try std.fmt.allocPrint(allocator, "git log failed: {s}", .{@errorName(err)}), .is_error = true };
            };
            defer allocator.free(out);
            return .{ .output = try allocator.dupe(u8, out) };
        } else if (std.mem.eql(u8, action, "rollback")) {
            const id = tools_interface.getString(args, "id") orelse return .{ .output = "rollback requires id", .is_error = true };
            const out = runGit(allocator, &.{ "git", "checkout", id, "--", "." }) catch |err| {
                return .{ .output = try std.fmt.allocPrint(allocator, "git checkout failed: {s}", .{@errorName(err)}), .is_error = true };
            };
            defer allocator.free(out);
            return .{ .output = try std.fmt.allocPrint(allocator, "Rolled back to {s}", .{id}) };
        } else if (std.mem.eql(u8, action, "diff")) {
            const id = tools_interface.getString(args, "id") orelse "HEAD";
            const out = runGit(allocator, &.{ "git", "diff", id }) catch |err| {
                return .{ .output = try std.fmt.allocPrint(allocator, "git diff failed: {s}", .{@errorName(err)}), .is_error = true };
            };
            defer allocator.free(out);
            if (out.len == 0) return .{ .output = try allocator.dupe(u8, "No differences") };
            return .{ .output = try allocator.dupe(u8, out) };
        }
        return .{ .output = try std.fmt.allocPrint(allocator, "Unknown action: {s}", .{action}), .is_error = true };
    }

    fn runGit(allocator: std.mem.Allocator, argv: []const []const u8) ![]u8 {
        var io = std.Io.Threaded.init(allocator, .{});
        defer io.deinit();
        
        var child = try std.process.spawn(io.io(), .{
            .argv = argv,
            .stdout = .pipe,
            .stderr = .pipe,
        });
        
        var stdout_buf: [4096]u8 = undefined;
        var stderr_buf: [4096]u8 = undefined;
        var stdout_reader = child.stdout.?.reader(io.io(), &stdout_buf);
        var stderr_reader = child.stderr.?.reader(io.io(), &stderr_buf);
        
        const stdout = try stdout_reader.interface.allocRemaining(allocator, @enumFromInt(1024 * 1024));
        errdefer allocator.free(stdout);
        _ = try stderr_reader.interface.allocRemaining(allocator, @enumFromInt(1024 * 1024));
        
        if (child.stdout) |f| f.close(io.io());
        if (child.stderr) |f| f.close(io.io());
        
        const term = try child.wait(io.io());
        if (term != .exited or term.exited != 0) {
            allocator.free(stdout);
            return error.GitFailed;
        }
        return stdout;
    }
};

test "CheckpointTool schema" {
    var tool = CheckpointTool{};
    const handler = tools_interface.makeToolHandler(CheckpointTool, &tool);
    try std.testing.expectEqualStrings("checkpoint", handler.schema.name);
}
