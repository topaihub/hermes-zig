const std = @import("std");
const core = @import("../../core/root.zig");
const tools = @import("../../tools/root.zig");

pub const managed_tool_names = [_][]const u8{
    "terminal",
    "read_file",
    "write_file",
    "patch",
    "search_files",
    "web_search",
    "web_extract",
    "execute_code",
    "todo",
    "memory",
    "clarify",
    "delegate_task",
    "send_message",
    "image_generate",
    "text_to_speech",
    "vision_analyze",
    "cronjob",
    "session_search",
    "skills_list",
    "skill_view",
    "skill_manage",
    "checkpoint",
    "process",
};

pub const ToolState = struct {
    name: []const u8,
    enabled: bool,
};

pub const ToolsRuntime = struct {
    allocator: std.mem.Allocator,
    registry: tools.ToolRegistry,
    arena: std.heap.ArenaAllocator,
    terminal_backend: tools.TerminalBackend,
    memory_dir: []u8,
    owned_disabled_tools: ?[][]u8 = null,

    pub fn init(allocator: std.mem.Allocator, cfg: *const core.Config) !ToolsRuntime {
        const hermes_home = try core.constants.getHermesHome(allocator);
        defer allocator.free(hermes_home);

        var runtime = ToolsRuntime{
            .allocator = allocator,
            .registry = tools.ToolRegistry.init(allocator, &.{}),
            .arena = std.heap.ArenaAllocator.init(allocator),
            .terminal_backend = tools.TerminalBackend.fromConfig(cfg.terminal),
            .memory_dir = try std.fs.path.join(allocator, &.{ hermes_home, "memory" }),
        };
        try runtime.reload(cfg);
        return runtime;
    }

    pub fn deinit(self: *ToolsRuntime) void {
        self.registry.deinit();
        self.arena.deinit();
        self.terminal_backend.cleanup() catch {};
        self.freeOwnedDisabledTools();
        self.allocator.free(self.memory_dir);
    }

    pub fn reload(self: *ToolsRuntime, cfg: *const core.Config) !void {
        self.registry.deinit();
        self.arena.deinit();
        self.arena = std.heap.ArenaAllocator.init(self.allocator);
        self.registry = tools.ToolRegistry.init(self.allocator, &.{});
        self.terminal_backend = tools.TerminalBackend.fromConfig(cfg.terminal);

        const enabled = try effectiveEnabledToolNames(self.allocator, cfg);
        defer self.allocator.free(enabled);

        for (enabled) |name| {
            try self.registerTool(name);
        }
    }

    pub fn collectSchemas(self: *ToolsRuntime, allocator: std.mem.Allocator) ![]tools.ToolSchema {
        return self.registry.collectSchemas(allocator);
    }

    pub fn listStates(self: *ToolsRuntime, allocator: std.mem.Allocator, cfg: *const core.Config) ![]ToolState {
        _ = self;
        var states: std.ArrayList(ToolState) = .empty;
        const enabled = try effectiveEnabledToolNames(allocator, cfg);
        defer allocator.free(enabled);

        for (managed_tool_names) |name| {
            try states.append(allocator, .{
                .name = name,
                .enabled = sliceContains(enabled, name),
            });
        }
        return states.toOwnedSlice(allocator);
    }

    pub fn isManagedToolName(_: *const ToolsRuntime, name: []const u8) bool {
        return isManagedTool(name);
    }

    pub fn setToolEnabled(self: *ToolsRuntime, cfg: *core.Config, name: []const u8, enabled: bool) !bool {
        if (!isManagedTool(name)) return error.UnknownTool;
        if (enabled and !isAvailableFromConfiguredToolsets(cfg, name)) {
            return error.ToolBlockedByToolsets;
        }

        const currently_disabled = sliceContains(cfg.tools.disabled_tools, name);
        if (enabled and !currently_disabled) return false;
        if (!enabled and currently_disabled) return false;

        var next: std.ArrayList([]const u8) = .empty;
        defer next.deinit(self.allocator);

        for (cfg.tools.disabled_tools) |disabled_name| {
            if (std.mem.eql(u8, disabled_name, name)) continue;
            try next.append(self.allocator, disabled_name);
        }
        if (!enabled) {
            try next.append(self.allocator, name);
        }

        try self.applyDisabledTools(cfg, next.items);
        return true;
    }

    fn applyDisabledTools(self: *ToolsRuntime, cfg: *core.Config, names: []const []const u8) !void {
        const owned = try self.allocator.alloc([]u8, names.len);
        var built: usize = 0;
        errdefer {
            for (owned[0..built]) |item| self.allocator.free(item);
            self.allocator.free(owned);
        }

        for (names, 0..) |name, index| {
            owned[index] = try self.allocator.dupe(u8, name);
            built += 1;
        }

        self.freeOwnedDisabledTools();
        self.owned_disabled_tools = owned;
        cfg.tools.disabled_tools = owned;
    }

    fn freeOwnedDisabledTools(self: *ToolsRuntime) void {
        if (self.owned_disabled_tools) |owned| {
            for (owned) |name| self.allocator.free(name);
            self.allocator.free(owned);
            self.owned_disabled_tools = null;
        }
    }

    fn registerTool(self: *ToolsRuntime, name: []const u8) !void {
        const a = self.arena.allocator();

        if (std.mem.eql(u8, name, "terminal")) {
            const tool = try a.create(tools.builtin.BashTool);
            tool.* = .{ .backend = &self.terminal_backend };
            try self.registry.registerDynamic(tools.makeToolHandler(tools.builtin.BashTool, tool));
            return;
        }
        if (std.mem.eql(u8, name, "read_file")) {
            const tool = try a.create(tools.builtin.FileReadTool);
            tool.* = .{};
            try self.registry.registerDynamic(tools.makeToolHandler(tools.builtin.FileReadTool, tool));
            return;
        }
        if (std.mem.eql(u8, name, "write_file")) {
            const tool = try a.create(tools.builtin.FileWriteTool);
            tool.* = .{};
            try self.registry.registerDynamic(tools.makeToolHandler(tools.builtin.FileWriteTool, tool));
            return;
        }
        if (std.mem.eql(u8, name, "patch")) {
            const tool = try a.create(tools.builtin.FileEditTool);
            tool.* = .{};
            try self.registry.registerDynamic(tools.makeToolHandler(tools.builtin.FileEditTool, tool));
            return;
        }
        if (std.mem.eql(u8, name, "search_files")) {
            const tool = try a.create(tools.builtin.FileTools);
            tool.* = .{ .backend = &self.terminal_backend };
            try self.registry.registerDynamic(tools.makeToolHandler(tools.builtin.FileTools, tool));
            return;
        }
        if (std.mem.eql(u8, name, "web_search")) {
            const tool = try a.create(tools.builtin.WebSearchTool);
            tool.* = .{};
            try self.registry.registerDynamic(tools.makeToolHandler(tools.builtin.WebSearchTool, tool));
            return;
        }
        if (std.mem.eql(u8, name, "web_extract")) {
            const tool = try a.create(tools.builtin.WebExtractTool);
            tool.* = .{};
            try self.registry.registerDynamic(tools.makeToolHandler(tools.builtin.WebExtractTool, tool));
            return;
        }
        if (std.mem.eql(u8, name, "execute_code")) {
            const tool = try a.create(tools.builtin.CodeExecutionTool);
            tool.* = .{ .backend = &self.terminal_backend };
            try self.registry.registerDynamic(tools.makeToolHandler(tools.builtin.CodeExecutionTool, tool));
            return;
        }
        if (std.mem.eql(u8, name, "todo")) {
            const tool = try a.create(tools.builtin.TodoTool);
            tool.* = tools.builtin.TodoTool.init(a);
            try self.registry.registerDynamic(tools.makeToolHandler(tools.builtin.TodoTool, tool));
            return;
        }
        if (std.mem.eql(u8, name, "memory")) {
            const tool = try a.create(tools.builtin.MemoryTool);
            tool.* = .{ .storage_dir = self.memory_dir };
            try self.registry.registerDynamic(tools.makeToolHandler(tools.builtin.MemoryTool, tool));
            return;
        }
        if (std.mem.eql(u8, name, "clarify")) {
            const tool = try a.create(tools.builtin.ClarifyTool);
            tool.* = .{};
            try self.registry.registerDynamic(tools.makeToolHandler(tools.builtin.ClarifyTool, tool));
            return;
        }
        if (std.mem.eql(u8, name, "delegate_task")) {
            const tool = try a.create(tools.builtin.DelegateTool);
            tool.* = .{};
            try self.registry.registerDynamic(tools.makeToolHandler(tools.builtin.DelegateTool, tool));
            return;
        }
        if (std.mem.eql(u8, name, "send_message")) {
            const tool = try a.create(tools.builtin.SendMessageTool);
            tool.* = .{};
            try self.registry.registerDynamic(tools.makeToolHandler(tools.builtin.SendMessageTool, tool));
            return;
        }
        if (std.mem.eql(u8, name, "image_generate")) {
            const tool = try a.create(tools.builtin.ImageGenTool);
            tool.* = .{};
            try self.registry.registerDynamic(tools.makeToolHandler(tools.builtin.ImageGenTool, tool));
            return;
        }
        if (std.mem.eql(u8, name, "text_to_speech")) {
            const tool = try a.create(tools.builtin.TtsTool);
            tool.* = .{};
            try self.registry.registerDynamic(tools.makeToolHandler(tools.builtin.TtsTool, tool));
            return;
        }
        if (std.mem.eql(u8, name, "vision_analyze")) {
            const tool = try a.create(tools.builtin.VisionTool);
            tool.* = .{};
            try self.registry.registerDynamic(tools.makeToolHandler(tools.builtin.VisionTool, tool));
            return;
        }
        if (std.mem.eql(u8, name, "cronjob")) {
            const tool = try a.create(tools.builtin.CronjobTool);
            tool.* = .{};
            try self.registry.registerDynamic(tools.makeToolHandler(tools.builtin.CronjobTool, tool));
            return;
        }
        if (std.mem.eql(u8, name, "session_search")) {
            const tool = try a.create(tools.builtin.SessionSearchTool);
            tool.* = .{};
            try self.registry.registerDynamic(tools.makeToolHandler(tools.builtin.SessionSearchTool, tool));
            return;
        }
        if (std.mem.eql(u8, name, "skills_list")) {
            const tool = try a.create(tools.builtin.SkillsList);
            tool.* = .{};
            try self.registry.registerDynamic(tools.makeToolHandler(tools.builtin.SkillsList, tool));
            return;
        }
        if (std.mem.eql(u8, name, "skill_view")) {
            const tool = try a.create(tools.builtin.SkillView);
            tool.* = .{};
            try self.registry.registerDynamic(tools.makeToolHandler(tools.builtin.SkillView, tool));
            return;
        }
        if (std.mem.eql(u8, name, "skill_manage")) {
            const tool = try a.create(tools.builtin.SkillManage);
            tool.* = .{};
            try self.registry.registerDynamic(tools.makeToolHandler(tools.builtin.SkillManage, tool));
            return;
        }
        if (std.mem.eql(u8, name, "checkpoint")) {
            const tool = try a.create(tools.builtin.CheckpointTool);
            tool.* = .{};
            try self.registry.registerDynamic(tools.makeToolHandler(tools.builtin.CheckpointTool, tool));
            return;
        }
        if (std.mem.eql(u8, name, "process")) {
            const tool = try a.create(tools.builtin.ProcessTool);
            tool.* = .{};
            try self.registry.registerDynamic(tools.makeToolHandler(tools.builtin.ProcessTool, tool));
            return;
        }
    }
};

fn effectiveEnabledToolNames(allocator: std.mem.Allocator, cfg: *const core.Config) ![][]const u8 {
    var result: std.ArrayList([]const u8) = .empty;
    const default_toolsets = [_][]const u8{ "default" };
    const toolsets: []const []const u8 = if (cfg.tools.enabled_toolsets.len > 0)
        cfg.tools.enabled_toolsets
    else
        default_toolsets[0..];
    for (toolsets) |toolset_name| {
        const names = if (std.mem.eql(u8, toolset_name, "default"))
            &managed_tool_names
        else
            tools.toolsets.resolveToolset(toolset_name) orelse continue;
        for (names) |name| {
            if (!isManagedTool(name)) continue;
            if (sliceContains(result.items, name)) continue;
            try result.append(allocator, name);
        }
    }

    var filtered: std.ArrayList([]const u8) = .empty;
    for (result.items) |name| {
        if (!sliceContains(cfg.tools.disabled_tools, name)) {
            try filtered.append(allocator, name);
        }
    }
    result.deinit(allocator);
    return filtered.toOwnedSlice(allocator);
}

fn isManagedTool(name: []const u8) bool {
    return sliceContains(&managed_tool_names, name);
}

fn isAvailableFromConfiguredToolsets(cfg: *const core.Config, name: []const u8) bool {
    if (cfg.tools.enabled_toolsets.len == 0) return isManagedTool(name);

    for (cfg.tools.enabled_toolsets) |toolset_name| {
        const names = tools.toolsets.resolveToolset(toolset_name) orelse continue;
        if (sliceContains(names, name) and isManagedTool(name)) return true;
    }
    return false;
}

fn sliceContains(items: []const []const u8, target: []const u8) bool {
    for (items) |item| {
        if (std.mem.eql(u8, item, target)) return true;
    }
    return false;
}

test "effectiveEnabledToolNames filters disabled tools" {
    const cfg = core.Config{
        .tools = .{
            .enabled_toolsets = &.{ "default" },
            .disabled_tools = &.{ "todo", "memory" },
        },
    };
    const names = try effectiveEnabledToolNames(std.testing.allocator, &cfg);
    defer std.testing.allocator.free(names);
    try std.testing.expect(sliceContains(names, "terminal"));
    try std.testing.expect(!sliceContains(names, "todo"));
    try std.testing.expect(!sliceContains(names, "memory"));
}

fn schemasContain(schemas: []const tools.ToolSchema, target: []const u8) bool {
    for (schemas) |schema| {
        if (std.mem.eql(u8, schema.name, target)) return true;
    }
    return false;
}

test "setToolEnabled persists disabled tools and runtime reload removes schema" {
    var cfg = core.Config{};
    var runtime = try ToolsRuntime.init(std.testing.allocator, &cfg);
    defer runtime.deinit();

    var changed = try runtime.setToolEnabled(&cfg, "todo", false);
    try std.testing.expect(changed);
    try std.testing.expect(sliceContains(cfg.tools.disabled_tools, "todo"));
    try runtime.reload(&cfg);

    const disabled_schemas = try runtime.collectSchemas(std.testing.allocator);
    defer std.testing.allocator.free(disabled_schemas);
    try std.testing.expect(!schemasContain(disabled_schemas, "todo"));

    changed = try runtime.setToolEnabled(&cfg, "todo", true);
    try std.testing.expect(changed);
    try runtime.reload(&cfg);
    const enabled_schemas = try runtime.collectSchemas(std.testing.allocator);
    defer std.testing.allocator.free(enabled_schemas);
    try std.testing.expect(schemasContain(enabled_schemas, "todo"));
}

test "setToolEnabled rejects unknown tool names" {
    var cfg = core.Config{};
    var runtime = try ToolsRuntime.init(std.testing.allocator, &cfg);
    defer runtime.deinit();

    try std.testing.expectError(error.UnknownTool, runtime.setToolEnabled(&cfg, "nonexistent", false));
}

test "setToolEnabled rejects enabling tools blocked by current toolsets" {
    var cfg = core.Config{
        .tools = .{
            .enabled_toolsets = &.{ "coding" },
        },
    };
    var runtime = try ToolsRuntime.init(std.testing.allocator, &cfg);
    defer runtime.deinit();

    try std.testing.expectError(error.ToolBlockedByToolsets, runtime.setToolEnabled(&cfg, "skills_list", true));
}
