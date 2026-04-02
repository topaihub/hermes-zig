const std = @import("std");
const core_types = @import("../core/types.zig");

pub const ToolSchema = struct {
    name: []const u8,
    description: []const u8,
    parameters_schema: []const u8,
};

pub const ToolContext = struct {
    session_source: core_types.SessionSource,
    working_dir: []const u8 = ".",
    allocator: std.mem.Allocator,
};

pub const ToolResult = struct {
    output: []const u8,
    is_error: bool = false,
};

pub fn getString(args: std.json.ObjectMap, key: []const u8) ?[]const u8 {
    const val = args.get(key) orelse return null;
    return switch (val) {
        .string => |s| s,
        else => null,
    };
}

pub fn getBool(args: std.json.ObjectMap, key: []const u8) ?bool {
    const val = args.get(key) orelse return null;
    return switch (val) {
        .bool => |b| b,
        else => null,
    };
}

pub fn getInt(args: std.json.ObjectMap, key: []const u8) ?i64 {
    const val = args.get(key) orelse return null;
    return switch (val) {
        .integer => |i| i,
        else => null,
    };
}

pub const ToolHandler = struct {
    ptr: *anyopaque,
    vtable: *const VTable,
    schema: ToolSchema,

    pub const VTable = struct {
        execute: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator, args: std.json.ObjectMap) anyerror!ToolResult,
        deinit: *const fn (ptr: *anyopaque) void,
    };

    pub fn execute(self: ToolHandler, allocator: std.mem.Allocator, args: std.json.ObjectMap) !ToolResult {
        return self.vtable.execute(self.ptr, allocator, args);
    }

    pub fn deinit(self: ToolHandler) void {
        self.vtable.deinit(self.ptr);
    }
};

pub fn validateToolImpl(comptime T: type) void {
    comptime {
        if (!@hasDecl(T, "SCHEMA")) @compileError(@typeName(T) ++ " must have pub const SCHEMA: ToolSchema");
        if (!@hasDecl(T, "execute")) @compileError(@typeName(T) ++ " must have pub fn execute");
    }
}

pub fn makeToolHandler(comptime T: type, instance: *T) ToolHandler {
    validateToolImpl(T);
    return .{
        .ptr = @ptrCast(instance),
        .schema = T.SCHEMA,
        .vtable = &comptime .{
            .execute = struct {
                fn f(ptr: *anyopaque, allocator: std.mem.Allocator, args: std.json.ObjectMap) anyerror!ToolResult {
                    const self: *T = @ptrCast(@alignCast(ptr));
                    return self.execute(allocator, args);
                }
            }.f,
            .deinit = struct {
                fn f(ptr: *anyopaque) void {
                    if (@hasDecl(T, "deinit")) {
                        const self: *T = @ptrCast(@alignCast(ptr));
                        self.deinit();
                    }
                }
            }.f,
        },
    };
}

test "makeToolHandler compiles with valid tool struct" {
    const TestTool = struct {
        value: u32 = 42,

        pub const SCHEMA = ToolSchema{
            .name = "test_tool",
            .description = "A test tool",
            .parameters_schema = "{}",
        };

        pub fn execute(self: *@This(), _: std.mem.Allocator, _: std.json.ObjectMap) anyerror!ToolResult {
            _ = self;
            return .{ .output = "ok" };
        }
    };

    var tool = TestTool{};
    const handler = makeToolHandler(TestTool, &tool);
    try std.testing.expectEqualStrings("test_tool", handler.schema.name);

    var empty = std.json.ObjectMap.init(std.testing.allocator);
    defer empty.deinit();
    const result = try handler.execute(std.testing.allocator, empty);
    try std.testing.expectEqualStrings("ok", result.output);
}
