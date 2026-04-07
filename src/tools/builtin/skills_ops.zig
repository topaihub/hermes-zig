const std = @import("std");
const tools_interface = @import("../interface.zig");
const core_env = @import("../../core/env.zig");
const ToolResult = tools_interface.ToolResult;

fn getSkillsDir(allocator: std.mem.Allocator, working_dir: []const u8) ![]const u8 {
    if (std.fs.path.isAbsolute(working_dir)) {
        return std.fs.path.join(allocator, &.{ working_dir, ".hermes", "skills" });
    }
    const home = try core_env.getHomeDirOwned(allocator);
    defer allocator.free(home);
    return std.fs.path.join(allocator, &.{ home, ".hermes", "skills" });
}

pub const SkillsList = struct {
    pub const SCHEMA = tools_interface.ToolSchema{
        .name = "skills_list",
        .description = "List available skills with name and description",
        .parameters_schema =
            \\{"type":"object","properties":{}}
        ,
    };

    pub fn execute(self: *SkillsList, allocator: std.mem.Allocator, _: std.json.ObjectMap) anyerror!ToolResult {
        _ = self;
        const dir_path = try getSkillsDir(allocator, ".");
        defer allocator.free(dir_path);

        var dir = std.fs.cwd().openDir(dir_path, .{ .iterate = true }) catch
            return .{ .output = try std.fmt.allocPrint(allocator, "No skills directory found at {s}", .{dir_path}) };

        defer dir.close();
        var result = std.ArrayList(u8){};
        defer result.deinit(allocator);
        var iter = dir.iterate();
        while (try iter.next()) |entry| {
            if (entry.kind == .directory) {
                try result.appendSlice(allocator, entry.name);
                try result.append(allocator, '\n');
            }
        }
        if (result.items.len == 0) return .{ .output = try std.fmt.allocPrint(allocator, "No skills found in {s}", .{dir_path}) };
        return .{ .output = try result.toOwnedSlice(allocator) };
    }
};

pub const SkillView = struct {
    pub const SCHEMA = tools_interface.ToolSchema{
        .name = "skill_view",
        .description = "View the content of a skill's SKILL.md file",
        .parameters_schema =
            \\{"type":"object","properties":{"skill_name":{"type":"string","description":"Name of the skill to view"}},"required":["skill_name"]}
        ,
    };

    pub fn execute(self: *SkillView, allocator: std.mem.Allocator, args: std.json.ObjectMap) anyerror!ToolResult {
        _ = self;
        const skill_name = tools_interface.getString(args, "skill_name") orelse return .{ .output = "missing skill_name", .is_error = true };

        const dir_path = try getSkillsDir(allocator, ".");
        defer allocator.free(dir_path);
        const path = try std.fmt.allocPrint(allocator, "{s}{s}/SKILL.md", .{ dir_path, skill_name });
        defer allocator.free(path);

        return .{ .output = std.fs.cwd().readFileAlloc(allocator, path, 1024 * 1024) catch
            return .{ .output = try std.fmt.allocPrint(allocator, "Skill not found: {s}", .{skill_name}) } };
    }
};

pub const SkillManage = struct {
    pub const SCHEMA = tools_interface.ToolSchema{
        .name = "skill_manage",
        .description = "Create, update, or delete a skill",
        .parameters_schema =
            \\{"type":"object","properties":{"action":{"type":"string","enum":["create","update","delete"],"description":"Action to perform"},"name":{"type":"string","description":"Skill name"},"content":{"type":"string","description":"Skill content (for create/update)"}},"required":["action","name"]}
        ,
    };

    pub fn execute(self: *SkillManage, allocator: std.mem.Allocator, args: std.json.ObjectMap) anyerror!ToolResult {
        _ = self;
        const action = tools_interface.getString(args, "action") orelse return .{ .output = "missing action", .is_error = true };
        const name = tools_interface.getString(args, "name") orelse return .{ .output = "missing name", .is_error = true };
        const content = tools_interface.getString(args, "content") orelse "";

        const dir_path = try getSkillsDir(allocator, ".");
        defer allocator.free(dir_path);
        const skill_dir = try std.fmt.allocPrint(allocator, "{s}{s}", .{ dir_path, name });
        defer allocator.free(skill_dir);
        const skill_file = try std.fmt.allocPrint(allocator, "{s}/SKILL.md", .{skill_dir});
        defer allocator.free(skill_file);

        if (std.mem.eql(u8, action, "delete")) {
            std.fs.cwd().deleteTree(skill_dir) catch |e|
                return .{ .output = try std.fmt.allocPrint(allocator, "Error deleting skill: {s}", .{@errorName(e)}), .is_error = true };
            return .{ .output = try std.fmt.allocPrint(allocator, "Deleted skill: {s}", .{name}) };
        }

        std.fs.cwd().makePath(skill_dir) catch |e|
            return .{ .output = try std.fmt.allocPrint(allocator, "Error creating directory: {s}", .{@errorName(e)}), .is_error = true };
        std.fs.cwd().writeFile(.{ .sub_path = skill_file, .data = content }) catch |e|
            return .{ .output = try std.fmt.allocPrint(allocator, "Error writing skill: {s}", .{@errorName(e)}), .is_error = true };

        return .{ .output = try std.fmt.allocPrint(allocator, "Skill {s}d: {s}", .{ action, name }) };
    }
};

test "SkillsList schema" {
    var tool = SkillsList{};
    const handler = tools_interface.makeToolHandler(SkillsList, &tool);
    try std.testing.expectEqualStrings("skills_list", handler.schema.name);
}

test "SkillView schema" {
    var tool = SkillView{};
    const handler = tools_interface.makeToolHandler(SkillView, &tool);
    try std.testing.expectEqualStrings("skill_view", handler.schema.name);
}

test "SkillManage schema" {
    var tool = SkillManage{};
    const handler = tools_interface.makeToolHandler(SkillManage, &tool);
    try std.testing.expectEqualStrings("skill_manage", handler.schema.name);
}
