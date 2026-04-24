const std = @import("std");
const core = @import("../../core/root.zig");
const cli = @import("root.zig");
const tools_runtime_mod = @import("tools_runtime.zig");
const compat = @import("../../compat/root.zig");

const Allocator = std.mem.Allocator;
const ToolsRuntime = tools_runtime_mod.ToolsRuntime;
const ToolState = tools_runtime_mod.ToolState;

pub fn handleToolsCommand(
    allocator: Allocator,
    args: []const u8,
    stdin: std.Io.File,
    stdout: std.Io.File,
    cfg: *core.Config,
    config_path: []const u8,
    tools_runtime: *ToolsRuntime,
) !void {
    const trimmed = std.mem.trim(u8, args, " \t");

    if (trimmed.len == 0) {
        if (cli.canUseInteractiveInput(stdin, stdout)) {
            try runInteractiveToolsMenu(allocator, stdin, stdout, cfg, config_path, tools_runtime);
            return;
        }
        try renderToolsState(allocator, stdout, cfg, tools_runtime);
        return;
    }

    if (std.mem.eql(u8, trimmed, "list")) {
        try renderToolsState(allocator, stdout, cfg, tools_runtime);
        return;
    }

    if (std.mem.startsWith(u8, trimmed, "enable ")) {
        const name = std.mem.trim(u8, trimmed["enable ".len..], " \t");
        try setToolStateAndReport(allocator, stdout, cfg, config_path, tools_runtime, name, true);
        return;
    }

    if (std.mem.startsWith(u8, trimmed, "disable ")) {
        const name = std.mem.trim(u8, trimmed["disable ".len..], " \t");
        try setToolStateAndReport(allocator, stdout, cfg, config_path, tools_runtime, name, false);
        return;
    }

    var io_threaded: std.Io.Threaded = .init_single_threaded;
    const io_instance = io_threaded.io();
    var buf: [4096]u8 = undefined;
    var writer = stdout.writer(io_instance, &buf);
    
    try writer.interface.writeAll("\n  Usage:\n");
    try writer.interface.writeAll("    /tools           Open interactive tool toggler or show tool state\n");
    try writer.interface.writeAll("    /tools list      Show effective enabled and disabled tools\n");
    try writer.interface.writeAll("    /tools enable <name>\n");
    try writer.interface.writeAll("    /tools disable <name>\n\n");
    try writer.interface.flush();
}

fn renderToolsState(
    allocator: Allocator,
    stdout: std.Io.File,
    cfg: *const core.Config,
    tools_runtime: *ToolsRuntime,
) !void {
    const states = try tools_runtime.listStates(allocator, cfg);
    defer allocator.free(states);

    var io_threaded: std.Io.Threaded = .init_single_threaded;
    const io_instance = io_threaded.io();
    var buf: [4096]u8 = undefined;
    var writer = stdout.writer(io_instance, &buf);
    
    try writer.interface.writeAll("\n  \x1b[1mTools:\x1b[0m\n");
    for (states) |state| {
        const status = if (state.enabled) "\x1b[32menabled\x1b[0m" else "\x1b[90mdisabled\x1b[0m";
        const line = try std.fmt.allocPrint(allocator, "    • {s:<16} [{s}]\n", .{ state.name, status });
        defer allocator.free(line);
        try writer.interface.writeAll(line);
    }
    try writer.interface.writeAll("\n");
    try writer.interface.flush();
}

fn runInteractiveToolsMenu(
    allocator: Allocator,
    stdin: std.Io.File,
    stdout: std.Io.File,
    cfg: *core.Config,
    config_path: []const u8,
    tools_runtime: *ToolsRuntime,
) !void {
    var selected_index: usize = 0;
    var changed = false;
    var last_status: ?[]u8 = null;
    defer if (last_status) |msg| allocator.free(msg);

    while (true) {
        const states = try tools_runtime.listStates(allocator, cfg);
        defer allocator.free(states);
        const items = try buildMenuItems(allocator, states);
        defer freeOwnedStrings(allocator, items);

        const title = if (last_status) |msg|
            try std.fmt.allocPrint(allocator, "Toggle tools (Enter=toggle, Esc=done)  [{s}]", .{msg})
        else
            try allocator.dupe(u8, "Toggle tools (Enter=toggle, Esc=done)");
        defer allocator.free(title);

        const maybe_index = try cli.runSelectionMenu(allocator, stdin, stdout, title, items, selected_index);
        if (maybe_index == null) break;

        selected_index = maybe_index.?;
        const state = states[selected_index];
        const target_enabled = !state.enabled;

        if (last_status) |msg| {
            allocator.free(msg);
            last_status = null;
        }

        const label = try mutateToolState(allocator, cfg, config_path, tools_runtime, state.name, target_enabled);
        if (label.len == 0) {
            last_status = try std.fmt.allocPrint(
                allocator,
                "{s} already {s}",
                .{ state.name, if (target_enabled) "enabled" else "disabled" },
            );
        } else {
            last_status = label;
            changed = true;
        }
    }

    if (changed) {
        var io_threaded: std.Io.Threaded = .init_single_threaded;
        const io_instance = io_threaded.io();
        var buf: [4096]u8 = undefined;
        var writer = stdout.writer(io_instance, &buf);
        try writer.interface.writeAll("\n  Tool configuration updated.\n\n");
        try writer.interface.flush();
    }
}

fn setToolStateAndReport(
    allocator: Allocator,
    stdout: std.Io.File,
    cfg: *core.Config,
    config_path: []const u8,
    tools_runtime: *ToolsRuntime,
    name: []const u8,
    enabled: bool,
) !void {
    const label = try mutateToolState(allocator, cfg, config_path, tools_runtime, name, enabled);
    defer allocator.free(label);

    var io_threaded: std.Io.Threaded = .init_single_threaded;
    const io_instance = io_threaded.io();
    var buf: [4096]u8 = undefined;
    var writer = stdout.writer(io_instance, &buf);

    if (label.len == 0) {
        const unchanged = try std.fmt.allocPrint(
            allocator,
            "\n  Tool {s} is already {s}.\n\n",
            .{ name, if (enabled) "enabled" else "disabled" },
        );
        defer allocator.free(unchanged);
        try writer.interface.writeAll(unchanged);
        try writer.interface.flush();
        return;
    }

    const msg = try std.fmt.allocPrint(allocator, "\n  {s}.\n\n", .{label});
    defer allocator.free(msg);
    try writer.interface.writeAll(msg);
    try writer.interface.flush();
}

fn mutateToolState(
    allocator: Allocator,
    cfg: *core.Config,
    config_path: []const u8,
    tools_runtime: *ToolsRuntime,
    name: []const u8,
    enabled: bool,
) ![]u8 {
    const changed = tools_runtime.setToolEnabled(cfg, name, enabled) catch |err| switch (err) {
        error.UnknownTool => return std.fmt.allocPrint(allocator, "Unknown tool: {s}", .{name}),
        error.ToolBlockedByToolsets => return std.fmt.allocPrint(
            allocator,
            "Cannot enable {s} because the current enabled_toolsets do not include it",
            .{name},
        ),
        else => return err,
    };

    if (!changed) return allocator.alloc(u8, 0);

    try saveConfigAlloc(allocator, config_path, cfg.*);
    try tools_runtime.reload(cfg);
    return std.fmt.allocPrint(allocator, "{s} {s}", .{
        if (enabled) "Enabled" else "Disabled",
        name,
    });
}

fn buildMenuItems(allocator: Allocator, states: []const ToolState) ![][]u8 {
    const items = try allocator.alloc([]u8, states.len);
    var built: usize = 0;
    errdefer {
        for (items[0..built]) |item| allocator.free(item);
        allocator.free(items);
    }

    for (states, 0..) |state, index| {
        items[index] = try std.fmt.allocPrint(
            allocator,
            "[{s}] {s}",
            .{ if (state.enabled) "enabled " else "disabled", state.name },
        );
        built += 1;
    }
    return items;
}

fn freeOwnedStrings(allocator: Allocator, items: [][]u8) void {
    for (items) |item| allocator.free(item);
    allocator.free(items);
}

fn createConfigFile(config_path: []const u8) !compat.fs.File {
    if (std.fs.path.isAbsolute(config_path)) {
        return compat.fs.createFileAbsolute(config_path, .{});
    }
    const cwd = compat.fs.cwd();
    return cwd.createFile(config_path, .{});
}

fn saveConfigAlloc(allocator: Allocator, config_path: []const u8, cfg: core.Config) !void {
    const json = try std.json.Stringify.valueAlloc(allocator, cfg, .{ .whitespace = .indent_2 });
    defer allocator.free(json);
    var file = try createConfigFile(config_path);
    defer file.close();
    try file.writeAll(json);
}

test "mutateToolState rejects unknown tool names without mutating config" {
    var cfg = core.Config{};
    var runtime = try ToolsRuntime.init(std.testing.allocator, &cfg);
    defer runtime.deinit();

    const label = try mutateToolState(std.testing.allocator, &cfg, "tools-test-config.json", &runtime, "missing", false);
    defer std.testing.allocator.free(label);
    try std.testing.expectEqualStrings("Unknown tool: missing", label);
    try std.testing.expectEqual(@as(usize, 0), cfg.tools.disabled_tools.len);
}

test "mutateToolState disables tool, persists config, and refreshes runtime" {
    const config_path = "_hermes_tools_config_test.json";
    defer std.fs.cwd().deleteFile(config_path) catch {};

    var cfg = core.Config{};
    var runtime = try ToolsRuntime.init(std.testing.allocator, &cfg);
    defer runtime.deinit();

    const label = try mutateToolState(std.testing.allocator, &cfg, config_path, &runtime, "todo", false);
    defer std.testing.allocator.free(label);
    try std.testing.expectEqualStrings("Disabled todo", label);
    try std.testing.expectEqual(@as(usize, 1), cfg.tools.disabled_tools.len);
    try std.testing.expectEqualStrings("todo", cfg.tools.disabled_tools[0]);

    const states = try runtime.listStates(std.testing.allocator, &cfg);
    defer std.testing.allocator.free(states);
    var found_todo = false;
    for (states) |state| {
        if (std.mem.eql(u8, state.name, "todo")) {
            found_todo = true;
            try std.testing.expect(!state.enabled);
        }
    }
    try std.testing.expect(found_todo);
}
