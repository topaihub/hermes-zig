const std = @import("std");

pub const SkillDefinition = struct {
    name: []const u8 = "",
    description: []const u8 = "",
    body: []const u8 = "",
    allocator: ?std.mem.Allocator = null,

    pub fn deinit(self: *SkillDefinition) void {
        if (self.allocator) |a| {
            if (self.name.len > 0) a.free(self.name);
            if (self.description.len > 0) a.free(self.description);
            if (self.body.len > 0) a.free(self.body);
        }
    }
};

pub fn loadSkill(allocator: std.mem.Allocator, path: []const u8) !?SkillDefinition {
    var io_threaded: std.Io.Threaded = .init_single_threaded;
    const io_instance = io_threaded.io();
    const cwd = std.Io.Dir.cwd();
    const content = cwd.readFileAlloc(io_instance, path, allocator, @enumFromInt(1024 * 1024)) catch return null;
    defer allocator.free(content);
    return parseSkillContent(allocator, content);
}

pub fn parseSkillContent(allocator: std.mem.Allocator, content: []const u8) !?SkillDefinition {
    // Expect --- frontmatter --- body
    if (!std.mem.startsWith(u8, content, "---")) return null;
    const after_first = content[3..];
    const end_idx = std.mem.indexOf(u8, after_first, "---") orelse return null;
    const frontmatter = std.mem.trim(u8, after_first[0..end_idx], " \t\r\n");
    const body_start = 3 + end_idx + 3;
    const body = if (body_start < content.len) std.mem.trim(u8, content[body_start..], " \t\r\n") else "";

    var name: []const u8 = "";
    var description: []const u8 = "";
    var lines_iter = std.mem.splitScalar(u8, frontmatter, '\n');
    while (lines_iter.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (std.mem.indexOf(u8, trimmed, ":")) |colon| {
            const key = std.mem.trim(u8, trimmed[0..colon], " \t");
            const val = std.mem.trim(u8, trimmed[colon + 1 ..], " \t");
            if (std.mem.eql(u8, key, "name")) name = val;
            if (std.mem.eql(u8, key, "description")) description = val;
        }
    }

    return .{
        .name = try allocator.dupe(u8, name),
        .description = try allocator.dupe(u8, description),
        .body = try allocator.dupe(u8, body),
        .allocator = allocator,
    };
}

pub fn loadSkillsFromDir(allocator: std.mem.Allocator, dir_path: []const u8) ![]SkillDefinition {
    var skills: std.ArrayListUnmanaged(SkillDefinition) = .empty;
    errdefer {
        for (skills.items) |*s| s.deinit();
        skills.deinit(allocator);
    }

    var io_threaded = std.Io.Threaded.init(std.heap.page_allocator, .{});
    const io_instance = io_threaded.io();
    const cwd = std.Io.Dir.cwd();
    var dir = cwd.openDir(io_instance, dir_path, .{ .iterate = true }) catch return skills.toOwnedSlice(allocator);
    defer dir.close(io_instance);

    var iter = dir.iterate();
    while (try iter.next(io_instance)) |entry| {
        if (entry.kind == .directory) {
            const skill_path = try std.fmt.allocPrint(allocator, "{s}/{s}/SKILL.md", .{ dir_path, entry.name });
            defer allocator.free(skill_path);
            if (try loadSkill(allocator, skill_path)) |skill| {
                try skills.append(allocator, skill);
            }
        }
    }
    return skills.toOwnedSlice(allocator);
}

test "parseSkillContent parses frontmatter" {
    const content = "---\nname: test-skill\ndescription: A test skill\n---\nThis is the body.";
    var skill = (try parseSkillContent(std.testing.allocator, content)).?;
    defer skill.deinit();
    try std.testing.expectEqualStrings("test-skill", skill.name);
    try std.testing.expectEqualStrings("A test skill", skill.description);
    try std.testing.expectEqualStrings("This is the body.", skill.body);
}

test "parseSkillContent returns null for invalid" {
    try std.testing.expectEqual(null, try parseSkillContent(std.testing.allocator, "no frontmatter"));
}
