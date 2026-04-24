const std = @import("std");
const cli = @import("root.zig");
const skills_runtime_mod = @import("skills_runtime.zig");

const Allocator = std.mem.Allocator;
const SkillsRuntime = skills_runtime_mod.SkillsRuntime;

const MenuAction = union(enum) {
    activate: []const u8,
    clear_active,
};

const MenuEntry = struct {
    label: []u8,
    action: MenuAction,
};

const ActionResult = struct {
    message: []u8,
    mutated: bool,
};

pub fn handleSkillsCommand(
    allocator: Allocator,
    stdin: std.Io.File,
    stdout: std.Io.File,
    skills_runtime: *SkillsRuntime,
) !void {
    try skills_runtime.reload();

    if (!cli.canUseInteractiveInput(stdin, stdout) or !skills_runtime.hasInstalledSkills()) {
        const output = try renderSkillsStateAlloc(allocator, skills_runtime);
        defer allocator.free(output);
        
        var io_threaded: std.Io.Threaded = .init_single_threaded;
        const io_instance = io_threaded.io();
        var buf: [4096]u8 = undefined;
        var writer = stdout.writer(io_instance, &buf);
        try writer.interface.writeAll(output);
        return;
    }

    try runInteractiveSkillsMenu(allocator, stdin, stdout, skills_runtime);
}

pub fn renderSkillsDirectory(
    allocator: Allocator,
    stdout: std.Io.File,
    skills_runtime: *SkillsRuntime,
) !void {
    const msg = try std.fmt.allocPrint(allocator, "\n  \x1b[1mSkills Directory:\x1b[0m\n    {s}\n\n", .{skills_runtime.skills_dir});
    defer allocator.free(msg);
    
    var io_threaded: std.Io.Threaded = .init_single_threaded;
    const io_instance = io_threaded.io();
    var buf: [4096]u8 = undefined;
    var writer = stdout.writer(io_instance, &buf);
    try writer.interface.writeAll(msg);
}

pub fn renderSkillView(
    allocator: Allocator,
    stdout: std.Io.File,
    skills_runtime: *SkillsRuntime,
    name: []const u8,
) !void {
    var io_threaded: std.Io.Threaded = .init_single_threaded;
    const io_instance = io_threaded.io();
    var buf: [4096]u8 = undefined;
    var writer = stdout.writer(io_instance, &buf);
    
    try skills_runtime.reload();
    const skill = skills_runtime.findInstalled(name) orelse {
        const msg = try std.fmt.allocPrint(allocator, "\n  Skill not found: {s}\n\n", .{name});
        defer allocator.free(msg);
        try writer.interface.writeAll(msg);
        return;
    };

    const header = try std.fmt.allocPrint(
        allocator,
        "\n  \x1b[1mSkill:\x1b[0m {s}\n{s}{s}\n\n{s}\n\n",
        .{
            skill.name,
            if (skill.description.len > 0) "  \x1b[1mDescription:\x1b[0m " else "",
            skill.description,
            skill.body,
        },
    );
    defer allocator.free(header);
    try writer.interface.writeAll(header);
}

pub fn activateSkill(
    allocator: Allocator,
    stdout: std.Io.File,
    skills_runtime: *SkillsRuntime,
    name: []const u8,
) !void {
    var io_threaded: std.Io.Threaded = .init_single_threaded;
    const io_instance = io_threaded.io();
    var buf: [4096]u8 = undefined;
    var writer = stdout.writer(io_instance, &buf);
    
    try skills_runtime.reload();
    if (!(try skills_runtime.activate(name))) {
        const msg = try std.fmt.allocPrint(allocator, "\n  Skill not found: {s}\n\n", .{name});
        defer allocator.free(msg);
        try writer.interface.writeAll(msg);
        return;
    }
    const msg = try std.fmt.allocPrint(allocator, "\n  Activated skill: {s}\n\n", .{skills_runtime.active.?.name});
    defer allocator.free(msg);
    try writer.interface.writeAll(msg);
}

pub fn clearActiveSkill(
    allocator: Allocator,
    stdout: std.Io.File,
    skills_runtime: *SkillsRuntime,
) !void {
    _ = allocator;
    skills_runtime.clearActive();
    
    var io_threaded: std.Io.Threaded = .init_single_threaded;
    const io_instance = io_threaded.io();
    var buf: [4096]u8 = undefined;
    var writer = stdout.writer(io_instance, &buf);
    try writer.interface.writeAll("\n  Cleared active skill for this session.\n\n");
}

fn renderSkillsStateAlloc(allocator: Allocator, skills_runtime: *const SkillsRuntime) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    var out_writer: std.Io.Writer.Allocating = .fromArrayList(allocator, &out);
    const w = &out_writer.writer;

    try w.writeAll("\n  \x1b[1mSkills:\x1b[0m\n");
    if (!skills_runtime.hasInstalledSkills()) {
        try w.print("    No skills found in {s}\n", .{skills_runtime.skills_dir});
        try w.writeAll("    Install SKILL.md folders under this directory and try /skills again.\n\n");
        return out.toOwnedSlice(allocator);
    }

    for (skills_runtime.installed) |skill| {
        const marker = if (skills_runtime.activeName()) |active_name|
            if (std.mem.eql(u8, active_name, skill.name)) " (active)" else ""
        else
            "";
        try w.print("    • {s}{s}\n", .{ skill.name, marker });
    }
    if (skills_runtime.activeName()) |_| {
        try w.writeAll("    /skills clear to remove the active session skill\n");
    }
    try w.writeAll("\n");
    return out.toOwnedSlice(allocator);
}

fn runInteractiveSkillsMenu(
    allocator: Allocator,
    stdin: std.Io.File,
    stdout: std.Io.File,
    skills_runtime: *SkillsRuntime,
) !void {
    var selected_index: usize = 0;
    var changed = false;
    var last_status: ?[]u8 = null;
    defer if (last_status) |msg| allocator.free(msg);

    while (true) {
        const entries = try buildMenuEntries(allocator, skills_runtime);
        defer freeMenuEntries(allocator, entries);

        const title = if (last_status) |msg|
            try std.fmt.allocPrint(allocator, "Select skill (Enter=apply, Esc=done)  [{s}]", .{msg})
        else
            try allocator.dupe(u8, "Select skill (Enter=apply, Esc=done)");
        defer allocator.free(title);

        const items = try borrowMenuLabels(allocator, entries);
        defer allocator.free(items);
        if (entries.len == 0) break;
        if (selected_index >= entries.len) selected_index = entries.len - 1;

        const maybe_index = try cli.runSelectionMenu(allocator, stdin, stdout, title, items, selected_index);
        if (maybe_index == null) break;
        selected_index = maybe_index.?;

        if (last_status) |msg| {
            allocator.free(msg);
            last_status = null;
        }

        const result = try applyMenuAction(allocator, skills_runtime, entries[selected_index].action);
        last_status = result.message;
        changed = changed or result.mutated;
    }

    if (changed) {
        var io_threaded: std.Io.Threaded = .init_single_threaded;
        const io_instance = io_threaded.io();
        var buf: [4096]u8 = undefined;
        var writer = stdout.writer(io_instance, &buf);
        try writer.interface.writeAll("\n  Skills session state updated.\n\n");
    }
}

fn buildMenuEntries(allocator: Allocator, skills_runtime: *const SkillsRuntime) ![]MenuEntry {
    var entries: std.ArrayList(MenuEntry) = .empty;
    errdefer {
        for (entries.items) |entry| allocator.free(entry.label);
        entries.deinit(allocator);
    }

    for (skills_runtime.installed) |skill| {
        const state = if (skills_runtime.activeName()) |active_name|
            if (std.mem.eql(u8, active_name, skill.name)) "[active]" else "[skill ]"
        else
            "[skill ]";
        const label = try std.fmt.allocPrint(allocator, "{s} {s}", .{ state, skill.name });
        try entries.append(allocator, .{
            .label = label,
            .action = .{ .activate = skill.name },
        });
    }

    if (skills_runtime.activeName()) |active_name| {
        try entries.append(allocator, .{
            .label = try std.fmt.allocPrint(allocator, "[clear ] Clear active skill ({s})", .{active_name}),
            .action = .clear_active,
        });
    }

    return entries.toOwnedSlice(allocator);
}

fn freeMenuEntries(allocator: Allocator, entries: []MenuEntry) void {
    for (entries) |entry| allocator.free(entry.label);
    allocator.free(entries);
}

fn borrowMenuLabels(allocator: Allocator, entries: []const MenuEntry) ![][]const u8 {
    const labels = try allocator.alloc([]const u8, entries.len);
    for (entries, 0..) |entry, index| {
        labels[index] = entry.label;
    }
    return labels;
}

fn applyMenuAction(
    allocator: Allocator,
    skills_runtime: *SkillsRuntime,
    action: MenuAction,
) !ActionResult {
    switch (action) {
        .activate => |name| {
            if (skills_runtime.activeName()) |active_name| {
                if (std.mem.eql(u8, active_name, name)) {
                    return .{
                        .message = try std.fmt.allocPrint(allocator, "{s} already active", .{name}),
                        .mutated = false,
                    };
                }
            }
            _ = try skills_runtime.activate(name);
            return .{
                .message = try std.fmt.allocPrint(allocator, "Activated skill: {s}", .{name}),
                .mutated = true,
            };
        },
        .clear_active => {
            if (skills_runtime.activeName() == null) {
                return .{
                    .message = try allocator.dupe(u8, "No active skill"),
                    .mutated = false,
                };
            }
            skills_runtime.clearActive();
            return .{
                .message = try allocator.dupe(u8, "Cleared active skill"),
                .mutated = true,
            };
        },
    }
}

test "renderSkillsStateAlloc shows empty guidance with directory" {
    var runtime = try SkillsRuntime.init(std.testing.allocator);
    defer runtime.deinit();

    const output = try renderSkillsStateAlloc(std.testing.allocator, &runtime);
    defer std.testing.allocator.free(output);
    try std.testing.expect(std.mem.indexOf(u8, output, "No skills found in") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, runtime.skills_dir) != null);
}

test "buildMenuEntries marks active skill and appends clear action" {
    var runtime = try SkillsRuntime.init(std.testing.allocator);
    defer runtime.deinit();

    runtime.installed = try std.testing.allocator.alloc(@import("../../intelligence/skills_loader.zig").SkillDefinition, 2);
    runtime.installed[0] = .{
        .name = try std.testing.allocator.dupe(u8, "poetry"),
        .description = try std.testing.allocator.dupe(u8, "write poems"),
        .body = try std.testing.allocator.dupe(u8, "body-1"),
        .allocator = std.testing.allocator,
    };
    runtime.installed[1] = .{
        .name = try std.testing.allocator.dupe(u8, "review"),
        .description = try std.testing.allocator.dupe(u8, "review code"),
        .body = try std.testing.allocator.dupe(u8, "body-2"),
        .allocator = std.testing.allocator,
    };
    try std.testing.expect(try runtime.activate("poetry"));

    const entries = try buildMenuEntries(std.testing.allocator, &runtime);
    defer freeMenuEntries(std.testing.allocator, entries);
    try std.testing.expectEqual(@as(usize, 3), entries.len);
    try std.testing.expect(std.mem.indexOf(u8, entries[0].label, "[active] poetry") != null);
    try std.testing.expect(std.mem.indexOf(u8, entries[2].label, "Clear active skill") != null);
}

test "applyMenuAction activates and clears session skill state" {
    var runtime = try SkillsRuntime.init(std.testing.allocator);
    defer runtime.deinit();

    runtime.installed = try std.testing.allocator.alloc(@import("../../intelligence/skills_loader.zig").SkillDefinition, 1);
    runtime.installed[0] = .{
        .name = try std.testing.allocator.dupe(u8, "poetry"),
        .description = try std.testing.allocator.dupe(u8, "write poems"),
        .body = try std.testing.allocator.dupe(u8, "body-1"),
        .allocator = std.testing.allocator,
    };

    const activate_result = try applyMenuAction(std.testing.allocator, &runtime, .{ .activate = "poetry" });
    defer std.testing.allocator.free(activate_result.message);
    try std.testing.expectEqualStrings("Activated skill: poetry", activate_result.message);
    try std.testing.expect(activate_result.mutated);
    try std.testing.expectEqualStrings("poetry", runtime.active.?.name);

    const clear_result = try applyMenuAction(std.testing.allocator, &runtime, .clear_active);
    defer std.testing.allocator.free(clear_result.message);
    try std.testing.expectEqualStrings("Cleared active skill", clear_result.message);
    try std.testing.expect(clear_result.mutated);
    try std.testing.expect(runtime.active == null);
}

test "buildMenuEntries only shows skill names" {
    var runtime = try SkillsRuntime.init(std.testing.allocator);
    defer runtime.deinit();

    runtime.installed = try std.testing.allocator.alloc(@import("../../intelligence/skills_loader.zig").SkillDefinition, 1);
    runtime.installed[0] = .{
        .name = try std.testing.allocator.dupe(u8, "openspec-apply-change"),
        .description = try std.testing.allocator.dupe(u8, "Implement tasks from an OpenSpec change with a very long explanation"),
        .body = try std.testing.allocator.dupe(u8, "body"),
        .allocator = std.testing.allocator,
    };

    const entries = try buildMenuEntries(std.testing.allocator, &runtime);
    defer freeMenuEntries(std.testing.allocator, entries);
    try std.testing.expectEqualStrings("[skill ] openspec-apply-change", entries[0].label);
}
