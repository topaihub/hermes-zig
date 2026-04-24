const std = @import("std");
const registry = @import("registry.zig");
const toolsets = @import("toolsets.zig");
const interface = @import("interface.zig");

const ToolRegistry = registry.ToolRegistry;
const ToolSchema = interface.ToolSchema;
const ToolContext = interface.ToolContext;

/// Get tool definitions filtered by enabled toolsets
pub fn getToolDefinitions(
    reg: *ToolRegistry,
    enabled_toolsets: []const []const u8,
    allocator: std.mem.Allocator,
) ![]ToolSchema {
    // Collect all enabled tool names
    var enabled_names = std.StringHashMap(void).init(allocator);
    defer enabled_names.deinit();
    
    for (enabled_toolsets) |toolset_name| {
        const tools = toolsets.resolveToolset(toolset_name) orelse continue;
        for (tools) |tool_name| {
            try enabled_names.put(tool_name, {});
        }
    }
    
    // Collect all schemas from registry
    const all_schemas = try reg.collectSchemas(allocator);
    defer allocator.free(all_schemas);
    
    // Filter by enabled names
    var filtered = std.ArrayList(ToolSchema).empty;
    for (all_schemas) |schema| {
        if (enabled_names.contains(schema.name)) {
            try filtered.append(allocator, schema);
        }
    }
    
    return filtered.toOwnedSlice(allocator);
}

/// Handle tool call with error wrapping
pub fn handleToolCall(
    reg: *ToolRegistry,
    name: []const u8,
    args: []const u8,
    ctx: *const ToolContext,
    allocator: std.mem.Allocator,
) ![]const u8 {
    _ = ctx; // Reserved for future use
    
    const result = reg.dispatch(name, args, allocator) catch |err| {
        const err_msg = try std.fmt.allocPrint(allocator, "Tool execution failed: {s}", .{@errorName(err)});
        return err_msg;
    };
    
    if (result.is_error) {
        const err_msg = try std.fmt.allocPrint(allocator, "Tool error: {s}", .{result.output});
        return err_msg;
    }
    
    return try allocator.dupe(u8, result.output);
}

test "getToolDefinitions filters by toolset" {
    const TestTool = struct {
        pub const SCHEMA = ToolSchema{
            .name = "terminal",
            .description = "test tool",
            .parameters_schema = "{}",
        };
        pub fn execute(_: *@This(), _: std.mem.Allocator, _: std.json.ObjectMap) !interface.ToolResult {
            return .{ .output = "ok" };
        }
    };
    
    var tool = TestTool{};
    const handlers = &[_]interface.ToolHandler{interface.makeToolHandler(TestTool, &tool)};
    
    var reg = ToolRegistry.init(std.testing.allocator, handlers);
    defer reg.deinit();
    
    const toolset_names = &[_][]const u8{"default"};
    const schemas = try getToolDefinitions(&reg, toolset_names, std.testing.allocator);
    defer std.testing.allocator.free(schemas);
    
    try std.testing.expectEqual(@as(usize, 1), schemas.len);
    try std.testing.expectEqualStrings("terminal", schemas[0].name);
}

test "handleToolCall wraps errors" {
    const TestTool = struct {
        pub const SCHEMA = ToolSchema{
            .name = "fail",
            .description = "failing tool",
            .parameters_schema = "{}",
        };
        pub fn execute(_: *@This(), _: std.mem.Allocator, _: std.json.ObjectMap) !interface.ToolResult {
            return .{ .output = "something went wrong", .is_error = true };
        }
    };
    
    var tool = TestTool{};
    const handlers = &[_]interface.ToolHandler{interface.makeToolHandler(TestTool, &tool)};
    
    var reg = ToolRegistry.init(std.testing.allocator, handlers);
    defer reg.deinit();
    
    const ctx = ToolContext{};
    const result = try handleToolCall(&reg, "fail", "{}", &ctx, std.testing.allocator);
    defer std.testing.allocator.free(result);
    
    try std.testing.expect(std.mem.indexOf(u8, result, "Tool error") != null);
}
