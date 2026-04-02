const std = @import("std");
const tools_interface = @import("../interface.zig");
const ToolResult = tools_interface.ToolResult;

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

    pub fn execute(self: *TodoTool, allocator: std.mem.Allocator, args: std.json.ObjectMap) anyerror!ToolResult {
        const action = tools_interface.getString(args, "action") orelse return .{ .output = "missing action", .is_error = true };

        if (std.mem.eql(u8, action, "add")) {
            const text = tools_interface.getString(args, "text") orelse return .{ .output = "missing text", .is_error = true };
            const owned = try self.allocator.dupe(u8, text);
            const id = self.next_id;
            self.next_id += 1;
            try self.items.append(self.allocator, .{ .id = id, .text = owned });
            return .{ .output = try std.fmt.allocPrint(allocator, "Added todo #{d}: {s}", .{ id, text }) };
        }
        if (std.mem.eql(u8, action, "list")) {
            var buf: std.ArrayList(u8) = .{};
            defer buf.deinit(allocator);
            for (self.items.items) |item| {
                try buf.print(allocator, "[{s}] #{d}: {s}\n", .{ if (item.done) "x" else " ", item.id, item.text });
            }
            return .{ .output = if (buf.items.len > 0) try buf.toOwnedSlice(allocator) else try allocator.dupe(u8, "No todos") };
        }
        if (std.mem.eql(u8, action, "complete") or std.mem.eql(u8, action, "delete")) {
            const id = tools_interface.getInt(args, "id") orelse return .{ .output = "missing id", .is_error = true };
            for (self.items.items, 0..) |*item, i| {
                if (item.id == id) {
                    if (std.mem.eql(u8, action, "complete")) {
                        item.done = true;
                        return .{ .output = try std.fmt.allocPrint(allocator, "Completed #{d}", .{id}) };
                    }
                    self.allocator.free(item.text);
                    _ = self.items.orderedRemove(i);
                    return .{ .output = try std.fmt.allocPrint(allocator, "Deleted #{d}", .{id}) };
                }
            }
            return .{ .output = try std.fmt.allocPrint(allocator, "Todo #{d} not found", .{id}) };
        }
        return .{ .output = "unknown action", .is_error = true };
    }
};

test "TodoTool schema" {
    var tool = TodoTool.init(std.testing.allocator);
    defer tool.deinit();
    const handler = tools_interface.makeToolHandler(TodoTool, &tool);
    try std.testing.expectEqualStrings("todo", handler.schema.name);
}
