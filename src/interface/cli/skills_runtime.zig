const std = @import("std");
const core = @import("../../core/root.zig");
const skills_loader = @import("../../intelligence/skills_loader.zig");

pub const SkillsRuntime = struct {
    allocator: std.mem.Allocator,
    skills_dir: []u8,
    installed: []skills_loader.SkillDefinition = &.{},
    active: ?skills_loader.SkillDefinition = null,

    pub fn init(allocator: std.mem.Allocator) !SkillsRuntime {
        const hermes_home = try core.constants.getHermesHome(allocator);
        defer allocator.free(hermes_home);

        return .{
            .allocator = allocator,
            .skills_dir = try std.fs.path.join(allocator, &.{ hermes_home, "skills" }),
        };
    }

    pub fn deinit(self: *SkillsRuntime) void {
        self.clearInstalled();
        self.clearActive();
        self.allocator.free(self.skills_dir);
    }

    pub fn reload(self: *SkillsRuntime) !void {
        self.clearInstalled();
        self.installed = try skills_loader.loadSkillsFromDir(self.allocator, self.skills_dir);
    }

    pub fn clearActive(self: *SkillsRuntime) void {
        if (self.active) |*skill| {
            skill.deinit();
            self.active = null;
        }
    }

    pub fn activate(self: *SkillsRuntime, name: []const u8) !bool {
        const skill = self.findInstalled(name) orelse return false;
        self.clearActive();
        self.active = try duplicateSkill(self.allocator, skill);
        return true;
    }

    pub fn hasInstalledSkills(self: *const SkillsRuntime) bool {
        return self.installed.len > 0;
    }

    pub fn activeName(self: *const SkillsRuntime) ?[]const u8 {
        if (self.active) |skill| return skill.name;
        return null;
    }

    pub fn findInstalled(self: *const SkillsRuntime, name: []const u8) ?*const skills_loader.SkillDefinition {
        for (self.installed) |*skill| {
            if (std.mem.eql(u8, skill.name, name)) return skill;
        }
        return null;
    }

    fn clearInstalled(self: *SkillsRuntime) void {
        for (self.installed) |*skill| {
            skill.deinit();
        }
        if (self.installed.len > 0) self.allocator.free(self.installed);
        self.installed = &.{};
    }
};

fn duplicateSkill(allocator: std.mem.Allocator, skill: *const skills_loader.SkillDefinition) !skills_loader.SkillDefinition {
    return .{
        .name = try allocator.dupe(u8, skill.name),
        .description = try allocator.dupe(u8, skill.description),
        .body = try allocator.dupe(u8, skill.body),
        .allocator = allocator,
    };
}

test "activate replaces previous active skill" {
    var runtime = try SkillsRuntime.init(std.testing.allocator);
    defer runtime.deinit();

    runtime.installed = try std.testing.allocator.alloc(skills_loader.SkillDefinition, 2);
    runtime.installed[0] = .{
        .name = try std.testing.allocator.dupe(u8, "one"),
        .description = try std.testing.allocator.dupe(u8, "d1"),
        .body = try std.testing.allocator.dupe(u8, "b1"),
        .allocator = std.testing.allocator,
    };
    runtime.installed[1] = .{
        .name = try std.testing.allocator.dupe(u8, "two"),
        .description = try std.testing.allocator.dupe(u8, "d2"),
        .body = try std.testing.allocator.dupe(u8, "b2"),
        .allocator = std.testing.allocator,
    };

    try std.testing.expect(try runtime.activate("one"));
    try std.testing.expectEqualStrings("one", runtime.active.?.name);
    try std.testing.expect(try runtime.activate("two"));
    try std.testing.expectEqualStrings("two", runtime.active.?.name);
}
