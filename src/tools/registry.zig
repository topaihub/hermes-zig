const std = @import("std");
const interface = @import("interface.zig");
const ToolHandler = interface.ToolHandler;
const ToolSchema = interface.ToolSchema;
const ToolResult = interface.ToolResult;

pub const ToolRegistry = struct {
    static_tools: []const ToolHandler,
    dynamic: std.StringHashMap(ToolHandler),
    lock: std.Io.RwLock = std.Io.RwLock.init,
    io: std.Io,

    pub fn init(allocator: std.mem.Allocator, static_tools: []const ToolHandler) ToolRegistry {
        var io = std.Io.Threaded.init(allocator, .{});
        return .{
            .static_tools = static_tools,
            .dynamic = std.StringHashMap(ToolHandler).init(allocator),
            .io = io.io(),
        };
    }

    pub fn registerDynamic(self: *ToolRegistry, handler: ToolHandler) !void {
        try self.lock.lock(self.io);
        defer self.lock.unlock(self.io);
        try self.dynamic.put(handler.schema.name, handler);
    }

    pub fn dispatch(self: *ToolRegistry, name: []const u8, args_json: []const u8, allocator: std.mem.Allocator) !ToolResult {
        var parsed = std.json.parseFromSlice(std.json.Value, allocator, args_json, .{}) catch
            return .{ .output = "Invalid JSON arguments", .is_error = true };
        defer parsed.deinit();
        const args = switch (parsed.value) {
            .object => |obj| obj,
            else => return .{ .output = "Arguments must be JSON object", .is_error = true },
        };

        // Static first (no lock needed, immutable)
        for (self.static_tools) |h| {
            if (std.mem.eql(u8, h.schema.name, name)) return h.execute(allocator, args);
        }
        // Dynamic second (read lock)
        try self.lock.lockShared(self.io);
        defer self.lock.unlockShared(self.io);
        if (self.dynamic.get(name)) |h| return h.execute(allocator, args);
        return error.ToolNotFound;
    }

    pub fn collectSchemas(self: *ToolRegistry, allocator: std.mem.Allocator) ![]ToolSchema {
        var list = std.ArrayList(ToolSchema).empty;
        for (self.static_tools) |h| try list.append(allocator, h.schema);
        try self.lock.lockShared(self.io);
        defer self.lock.unlockShared(self.io);
        var it = self.dynamic.valueIterator();
        while (it.next()) |h| try list.append(allocator, h.schema);
        return list.toOwnedSlice(allocator);
    }

    pub fn deinit(self: *ToolRegistry) void {
        var it = self.dynamic.valueIterator();
        while (it.next()) |h| h.deinit();
        self.dynamic.deinit();
    }
};

test "ToolRegistry dispatch: static first, dynamic second" {
    const StaticTool = struct {
        pub const SCHEMA = ToolSchema{ .name = "echo", .description = "static echo", .parameters_schema = "{}" };
        pub fn execute(_: *@This(), _: std.mem.Allocator, _: std.json.ObjectMap) anyerror!ToolResult {
            return .{ .output = "static" };
        }
    };
    const DynTool = struct {
        pub const SCHEMA = ToolSchema{ .name = "echo", .description = "dynamic echo", .parameters_schema = "{}" };
        pub fn execute(_: *@This(), _: std.mem.Allocator, _: std.json.ObjectMap) anyerror!ToolResult {
            return .{ .output = "dynamic" };
        }
    };

    var st = StaticTool{};
    const static_handlers = &[_]ToolHandler{interface.makeToolHandler(StaticTool, &st)};
    var reg = ToolRegistry.init(std.testing.allocator, static_handlers);
    defer reg.deinit();

    var dt = DynTool{};
    try reg.registerDynamic(interface.makeToolHandler(DynTool, &dt));

    // Static wins over dynamic with same name
    const result = try reg.dispatch("echo", "{}", std.testing.allocator);
    try std.testing.expectEqualStrings("static", result.output);

    // collectSchemas returns both
    const schemas = try reg.collectSchemas(std.testing.allocator);
    defer std.testing.allocator.free(schemas);
    try std.testing.expectEqual(@as(usize, 2), schemas.len);
}

test "ToolRegistry dispatch returns error for unknown tool" {
    var reg = ToolRegistry.init(std.testing.allocator, &.{});
    defer reg.deinit();
    try std.testing.expectError(error.ToolNotFound, reg.dispatch("nonexistent", "{}", std.testing.allocator));
}
