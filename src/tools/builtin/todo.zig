const std = @import("std");
const tools_interface = @import("../interface.zig");

pub const TodoTool = struct {
    allocator: std.mem.Allocator,
    items: std.ArrayList(Item) = .{},
    next_id: i64 = 1,

    const Item = struct { id: i64, text: []const u8, done: bool = false };

    pub const SCHEMA = tools_interface.ToolSchema{
        .name = "todo",
        .description = "Manage a todo list: add, list, complete, delete",
        .parameters_schema =
            \\{"type":"object","properties":{"action":{"type":"string","enum":["add","list","complete","delete"]},"text":{"type":"string"},"id":{"type":"integer"}},"required":["action"]}
        ,
    };

    pub fn init(allocator: std.mem.Allocator) TodoTool {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *TodoTool) void {
        for (self.items.items) |item| self.allocator.free(item.text);
        self.items.deinit(self.allocator);
    }

    pub fn execute(self: *TodoTool, args_json: []const u8, ctx: *const tools_interface.ToolContext) anyerror![]const u8 {
        const Args = struct { action: []const u8, text: ?[]const u8 = null, id: ?i64 = null };
        const parsed = std.json.parseFromSlice(Args, ctx.allocator, args_json, .{ .ignore_unknown_fields = true }) catch
            return error.InvalidArgs;
        defer parsed.deinit();
        const action = parsed.value.action;

        if (std.mem.eql(u8, action, "add")) {
            const text = parsed.value.text orelse return error.InvalidArgs;
            const owned = try self.allocator.dupe(u8, text);
            const id = self.next_id;
            self.next_id += 1;
            try self.items.append(self.allocator, .{ .id = id, .text = owned });
            return std.fmt.allocPrint(ctx.allocator, "Added todo #{d}: {s}", .{ id, text });
        }
        if (std.mem.eql(u8, action, "list")) {
            var buf: std.ArrayList(u8) = .{};
            defer buf.deinit(ctx.allocator);
            for (self.items.items) |item| {
                try buf.print(ctx.allocator, "[{s}] #{d}: {s}\n", .{ if (item.done) "x" else " ", item.id, item.text });
            }
            return if (buf.items.len > 0) try buf.toOwnedSlice(ctx.allocator) else try ctx.allocator.dupe(u8, "No todos");
        }
        if (std.mem.eql(u8, action, "complete") or std.mem.eql(u8, action, "delete")) {
            const id = parsed.value.id orelse return error.InvalidArgs;
            for (self.items.items, 0..) |*item, i| {
                if (item.id == id) {
                    if (std.mem.eql(u8, action, "complete")) {
                        item.done = true;
                        return std.fmt.allocPrint(ctx.allocator, "Completed #{d}", .{id});
                    }
                    self.allocator.free(item.text);
                    _ = self.items.orderedRemove(i);
                    return std.fmt.allocPrint(ctx.allocator, "Deleted #{d}", .{id});
                }
            }
            return std.fmt.allocPrint(ctx.allocator, "Todo #{d} not found", .{id});
        }
        return error.InvalidArgs;
    }
};

test "TodoTool schema" {
    var tool = TodoTool.init(std.testing.allocator);
    defer tool.deinit();
    const handler = tools_interface.makeToolHandler(TodoTool, &tool);
    try std.testing.expectEqualStrings("todo", handler.schema.name);
}
