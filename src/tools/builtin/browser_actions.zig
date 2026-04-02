const std = @import("std");
const tools_if = @import("../interface.zig");
const ToolResult = tools_if.ToolResult;

pub const BrowserNavigate = struct {
    pub const SCHEMA = tools_if.ToolSchema{ .name = "browser_navigate", .description = "Navigate browser to URL", .parameters_schema =
        \\{"type":"object","properties":{"url":{"type":"string"}},"required":["url"]}
    };
    pub fn execute(self: *BrowserNavigate, allocator: std.mem.Allocator, args: std.json.ObjectMap) anyerror!ToolResult {
        _ = self;
        const url = tools_if.getString(args, "url") orelse return .{ .output = "missing url", .is_error = true };
        return .{ .output = try std.fmt.allocPrint(allocator, "[stub] browser_navigate: {s}", .{url}) };
    }
};

pub const BrowserClick = struct {
    pub const SCHEMA = tools_if.ToolSchema{ .name = "browser_click", .description = "Click an element on the page", .parameters_schema =
        \\{"type":"object","properties":{"selector":{"type":"string"}},"required":["selector"]}
    };
    pub fn execute(self: *BrowserClick, allocator: std.mem.Allocator, args: std.json.ObjectMap) anyerror!ToolResult {
        _ = self;
        const selector = tools_if.getString(args, "selector") orelse return .{ .output = "missing selector", .is_error = true };
        return .{ .output = try std.fmt.allocPrint(allocator, "[stub] browser_click: {s}", .{selector}) };
    }
};

pub const BrowserType = struct {
    pub const SCHEMA = tools_if.ToolSchema{ .name = "browser_type", .description = "Type text into an element", .parameters_schema =
        \\{"type":"object","properties":{"selector":{"type":"string"},"text":{"type":"string"}},"required":["selector","text"]}
    };
    pub fn execute(self: *BrowserType, allocator: std.mem.Allocator, args: std.json.ObjectMap) anyerror!ToolResult {
        _ = self;
        const selector = tools_if.getString(args, "selector") orelse return .{ .output = "missing selector", .is_error = true };
        const text = tools_if.getString(args, "text") orelse return .{ .output = "missing text", .is_error = true };
        return .{ .output = try std.fmt.allocPrint(allocator, "[stub] browser_type: {s} -> {s}", .{ selector, text }) };
    }
};

pub const BrowserScroll = struct {
    pub const SCHEMA = tools_if.ToolSchema{ .name = "browser_scroll", .description = "Scroll the page", .parameters_schema =
        \\{"type":"object","properties":{"direction":{"type":"string"}},"required":["direction"]}
    };
    pub fn execute(self: *BrowserScroll, allocator: std.mem.Allocator, args: std.json.ObjectMap) anyerror!ToolResult {
        _ = self;
        const direction = tools_if.getString(args, "direction") orelse return .{ .output = "missing direction", .is_error = true };
        return .{ .output = try std.fmt.allocPrint(allocator, "[stub] browser_scroll: {s}", .{direction}) };
    }
};

pub const BrowserSnapshot = struct {
    pub const SCHEMA = tools_if.ToolSchema{ .name = "browser_snapshot", .description = "Take a snapshot of the current page", .parameters_schema =
        \\{"type":"object","properties":{}}
    };
    pub fn execute(self: *BrowserSnapshot, allocator: std.mem.Allocator, _: std.json.ObjectMap) anyerror!ToolResult {
        _ = self;
        return .{ .output = try std.fmt.allocPrint(allocator, "[stub] browser_snapshot: captured", .{}) };
    }
};

pub const BrowserBack = struct {
    pub const SCHEMA = tools_if.ToolSchema{ .name = "browser_back", .description = "Navigate back in browser history", .parameters_schema =
        \\{"type":"object","properties":{}}
    };
    pub fn execute(self: *BrowserBack, allocator: std.mem.Allocator, _: std.json.ObjectMap) anyerror!ToolResult {
        _ = self;
        return .{ .output = try std.fmt.allocPrint(allocator, "[stub] browser_back: navigated back", .{}) };
    }
};

pub const BrowserClose = struct {
    pub const SCHEMA = tools_if.ToolSchema{ .name = "browser_close", .description = "Close the browser", .parameters_schema =
        \\{"type":"object","properties":{}}
    };
    pub fn execute(self: *BrowserClose, allocator: std.mem.Allocator, _: std.json.ObjectMap) anyerror!ToolResult {
        _ = self;
        return .{ .output = try std.fmt.allocPrint(allocator, "[stub] browser_close: closed", .{}) };
    }
};

pub const BrowserConsole = struct {
    pub const SCHEMA = tools_if.ToolSchema{ .name = "browser_console", .description = "Execute JavaScript in browser console", .parameters_schema =
        \\{"type":"object","properties":{"script":{"type":"string"}},"required":["script"]}
    };
    pub fn execute(self: *BrowserConsole, allocator: std.mem.Allocator, args: std.json.ObjectMap) anyerror!ToolResult {
        _ = self;
        const script = tools_if.getString(args, "script") orelse return .{ .output = "missing script", .is_error = true };
        return .{ .output = try std.fmt.allocPrint(allocator, "[stub] browser_console: {s}", .{script}) };
    }
};

pub const BrowserPress = struct {
    pub const SCHEMA = tools_if.ToolSchema{ .name = "browser_press", .description = "Press a key in the browser", .parameters_schema =
        \\{"type":"object","properties":{"key":{"type":"string"}},"required":["key"]}
    };
    pub fn execute(self: *BrowserPress, allocator: std.mem.Allocator, args: std.json.ObjectMap) anyerror!ToolResult {
        _ = self;
        const key = tools_if.getString(args, "key") orelse return .{ .output = "missing key", .is_error = true };
        return .{ .output = try std.fmt.allocPrint(allocator, "[stub] browser_press: {s}", .{key}) };
    }
};

pub const BrowserGetImages = struct {
    pub const SCHEMA = tools_if.ToolSchema{ .name = "browser_get_images", .description = "Get all images from the current page", .parameters_schema =
        \\{"type":"object","properties":{}}
    };
    pub fn execute(self: *BrowserGetImages, allocator: std.mem.Allocator, _: std.json.ObjectMap) anyerror!ToolResult {
        _ = self;
        return .{ .output = try std.fmt.allocPrint(allocator, "[stub] browser_get_images: []", .{}) };
    }
};

pub const BrowserVision = struct {
    pub const SCHEMA = tools_if.ToolSchema{ .name = "browser_vision", .description = "Analyze page visually using vision model", .parameters_schema =
        \\{"type":"object","properties":{"prompt":{"type":"string"}},"required":["prompt"]}
    };
    pub fn execute(self: *BrowserVision, allocator: std.mem.Allocator, args: std.json.ObjectMap) anyerror!ToolResult {
        _ = self;
        const prompt = tools_if.getString(args, "prompt") orelse return .{ .output = "missing prompt", .is_error = true };
        return .{ .output = try std.fmt.allocPrint(allocator, "[stub] browser_vision: {s}", .{prompt}) };
    }
};

test "browser_actions schemas" {
    const testing = std.testing;
    var nav = BrowserNavigate{};
    try testing.expectEqualStrings("browser_navigate", tools_if.makeToolHandler(BrowserNavigate, &nav).schema.name);
    var click = BrowserClick{};
    try testing.expectEqualStrings("browser_click", tools_if.makeToolHandler(BrowserClick, &click).schema.name);
    var typ = BrowserType{};
    try testing.expectEqualStrings("browser_type", tools_if.makeToolHandler(BrowserType, &typ).schema.name);
    var scroll = BrowserScroll{};
    try testing.expectEqualStrings("browser_scroll", tools_if.makeToolHandler(BrowserScroll, &scroll).schema.name);
    var snap = BrowserSnapshot{};
    try testing.expectEqualStrings("browser_snapshot", tools_if.makeToolHandler(BrowserSnapshot, &snap).schema.name);
    var back = BrowserBack{};
    try testing.expectEqualStrings("browser_back", tools_if.makeToolHandler(BrowserBack, &back).schema.name);
    var close = BrowserClose{};
    try testing.expectEqualStrings("browser_close", tools_if.makeToolHandler(BrowserClose, &close).schema.name);
    var console = BrowserConsole{};
    try testing.expectEqualStrings("browser_console", tools_if.makeToolHandler(BrowserConsole, &console).schema.name);
    var press = BrowserPress{};
    try testing.expectEqualStrings("browser_press", tools_if.makeToolHandler(BrowserPress, &press).schema.name);
    var imgs = BrowserGetImages{};
    try testing.expectEqualStrings("browser_get_images", tools_if.makeToolHandler(BrowserGetImages, &imgs).schema.name);
    var vis = BrowserVision{};
    try testing.expectEqualStrings("browser_vision", tools_if.makeToolHandler(BrowserVision, &vis).schema.name);
}
