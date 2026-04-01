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

pub const ToolHandler = struct {
    ptr: *anyopaque,
    vtable: *const VTable,
    schema: ToolSchema,

    pub const VTable = struct {
        execute: *const fn (ptr: *anyopaque, args_json: []const u8, ctx: *const ToolContext) anyerror![]const u8,
        deinit: *const fn (ptr: *anyopaque) void,
    };

    pub fn execute(self: ToolHandler, args_json: []const u8, ctx: *const ToolContext) ![]const u8 {
        return self.vtable.execute(self.ptr, args_json, ctx);
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
                fn f(ptr: *anyopaque, args: []const u8, ctx: *const ToolContext) anyerror![]const u8 {
                    const self: *T = @ptrCast(@alignCast(ptr));
                    return self.execute(args, ctx);
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

        pub fn execute(self: *@This(), _: []const u8, _: *const ToolContext) anyerror![]const u8 {
            _ = self;
            return "ok";
        }
    };

    var tool = TestTool{};
    const handler = makeToolHandler(TestTool, &tool);
    try std.testing.expectEqualStrings("test_tool", handler.schema.name);

    const ctx = ToolContext{
        .session_source = .{ .platform = .cli, .chat_id = "test" },
        .allocator = std.testing.allocator,
    };
    const result = try handler.execute("{}", &ctx);
    try std.testing.expectEqualStrings("ok", result);
}
