const std = @import("std");
const tools_interface = @import("../interface.zig");

const skills_base = "/.hermes/skills/";

fn getSkillsDir(allocator: std.mem.Allocator, working_dir: []const u8) ![]const u8 {
    if (std.fs.path.isAbsolute(working_dir)) {
        return std.fmt.allocPrint(allocator, "{s}{s}", .{ working_dir, skills_base });
    }
    const home = std.posix.getenv("HOME") orelse "/tmp";
    return std.fmt.allocPrint(allocator, "{s}{s}", .{ home, skills_base });
}

pub const SkillsList = struct {
    pub const SCHEMA = tools_interface.ToolSchema{
        .name = "skills_list",
        .description = "List available skills with name and description",
        .parameters_schema =
            \\{"type":"object","properties":{}}
        ,
    };

    pub fn execute(self: *SkillsList, args_json: []const u8, ctx: *const tools_interface.ToolContext) anyerror![]const u8 {
        _ = self;
        _ = args_json;
        const dir_path = try getSkillsDir(ctx.allocator, ctx.working_dir);
        defer ctx.allocator.free(dir_path);

        var dir = std.fs.cwd().openDir(dir_path, .{ .iterate = true }) catch
            return std.fmt.allocPrint(ctx.allocator, "No skills directory found at {s}", .{dir_path});

        defer dir.close();
        var result = std.ArrayList(u8).init(ctx.allocator);
        var iter = dir.iterate();
        while (try iter.next()) |entry| {
            if (entry.kind == .directory) {
                try result.appendSlice(entry.name);
                try result.append('\n');
            }
        }
        if (result.items.len == 0) return std.fmt.allocPrint(ctx.allocator, "No skills found in {s}", .{dir_path});
        return result.toOwnedSlice();
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

    pub fn execute(self: *SkillView, args_json: []const u8, ctx: *const tools_interface.ToolContext) anyerror![]const u8 {
        _ = self;
        const parsed = std.json.parseFromSlice(struct { skill_name: []const u8 = "" }, ctx.allocator, args_json, .{ .ignore_unknown_fields = true }) catch
            return error.InvalidArgs;
        defer parsed.deinit();

        const dir_path = try getSkillsDir(ctx.allocator, ctx.working_dir);
        defer ctx.allocator.free(dir_path);
        const path = try std.fmt.allocPrint(ctx.allocator, "{s}{s}/SKILL.md", .{ dir_path, parsed.value.skill_name });
        defer ctx.allocator.free(path);

        return std.fs.cwd().readFileAlloc(ctx.allocator, path, 1024 * 1024) catch
            return std.fmt.allocPrint(ctx.allocator, "Skill not found: {s}", .{parsed.value.skill_name});
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

    pub fn execute(self: *SkillManage, args_json: []const u8, ctx: *const tools_interface.ToolContext) anyerror![]const u8 {
        _ = self;
        const parsed = std.json.parseFromSlice(struct { action: []const u8 = "", name: []const u8 = "", content: []const u8 = "" }, ctx.allocator, args_json, .{ .ignore_unknown_fields = true }) catch
            return error.InvalidArgs;
        defer parsed.deinit();

        const dir_path = try getSkillsDir(ctx.allocator, ctx.working_dir);
        defer ctx.allocator.free(dir_path);
        const skill_dir = try std.fmt.allocPrint(ctx.allocator, "{s}{s}", .{ dir_path, parsed.value.name });
        defer ctx.allocator.free(skill_dir);
        const skill_file = try std.fmt.allocPrint(ctx.allocator, "{s}/SKILL.md", .{skill_dir});
        defer ctx.allocator.free(skill_file);

        if (std.mem.eql(u8, parsed.value.action, "delete")) {
            std.fs.cwd().deleteTree(skill_dir) catch |e|
                return std.fmt.allocPrint(ctx.allocator, "Error deleting skill: {s}", .{@errorName(e)});
            return std.fmt.allocPrint(ctx.allocator, "Deleted skill: {s}", .{parsed.value.name});
        }

        std.fs.cwd().makePath(skill_dir) catch |e|
            return std.fmt.allocPrint(ctx.allocator, "Error creating directory: {s}", .{@errorName(e)});
        std.fs.cwd().writeFile(.{ .sub_path = skill_file, .data = parsed.value.content }) catch |e|
            return std.fmt.allocPrint(ctx.allocator, "Error writing skill: {s}", .{@errorName(e)});

        return std.fmt.allocPrint(ctx.allocator, "Skill {s}d: {s}", .{ parsed.value.action, parsed.value.name });
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
