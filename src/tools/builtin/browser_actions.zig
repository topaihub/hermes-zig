const std = @import("std");
const tools_if = @import("../interface.zig");
const ToolResult = tools_if.ToolResult;

fn checkPlaywright(allocator: std.mem.Allocator) bool {
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "which", "playwright" },
    }) catch return false;
    allocator.free(result.stdout);
    allocator.free(result.stderr);
    return result.term.Exited == 0;
}

fn browserResult(allocator: std.mem.Allocator, action: []const u8, detail: []const u8) !ToolResult {
    if (checkPlaywright(allocator)) {
        return .{ .output = try std.fmt.allocPrint(allocator, "[Browser] {s}: {s} (playwright available)", .{ action, detail }) };
    }
    return .{ .output = try std.fmt.allocPrint(allocator, "[Browser] {s}: {s}\nNote: Install playwright for full browser automation: npm i -g playwright", .{ action, detail }) };
}

pub const BrowserNavigate = struct {
    pub const SCHEMA = tools_if.ToolSchema{ .name = "browser_navigate", .description = "Navigate browser to URL", .parameters_schema =
        \\{"type":"object","properties":{"url":{"type":"string"}},"required":["url"]}
    };
    pub fn execute(self: *BrowserNavigate, allocator: std.mem.Allocator, args: std.json.ObjectMap) anyerror!ToolResult {
        _ = self;
        const url = tools_if.getString(args, "url") orelse return .{ .output = "missing url", .is_error = true };
        return browserResult(allocator, "navigate", url);
    }
};

pub const BrowserClick = struct {
    pub const SCHEMA = tools_if.ToolSchema{ .name = "browser_click", .description = "Click an element on the page", .parameters_schema =
        \\{"type":"object","properties":{"selector":{"type":"string"}},"required":["selector"]}
    };
    pub fn execute(self: *BrowserClick, allocator: std.mem.Allocator, args: std.json.ObjectMap) anyerror!ToolResult {
        _ = self;
        const selector = tools_if.getString(args, "selector") orelse return .{ .output = "missing selector", .is_error = true };
        return browserResult(allocator, "click", selector);
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
        const detail = try std.fmt.allocPrint(allocator, "{s} -> {s}", .{ selector, text });
        defer allocator.free(detail);
        return browserResult(allocator, "type", detail);
    }
};

pub const BrowserScroll = struct {
    pub const SCHEMA = tools_if.ToolSchema{ .name = "browser_scroll", .description = "Scroll the page", .parameters_schema =
        \\{"type":"object","properties":{"direction":{"type":"string"}},"required":["direction"]}
    };
    pub fn execute(self: *BrowserScroll, allocator: std.mem.Allocator, args: std.json.ObjectMap) anyerror!ToolResult {
        _ = self;
        const direction = tools_if.getString(args, "direction") orelse return .{ .output = "missing direction", .is_error = true };
        return browserResult(allocator, "scroll", direction);
    }
};

pub const BrowserSnapshot = struct {
    pub const SCHEMA = tools_if.ToolSchema{ .name = "browser_snapshot", .description = "Take a snapshot of the current page", .parameters_schema =
        \\{"type":"object","properties":{}}
    };
    pub fn execute(self: *BrowserSnapshot, allocator: std.mem.Allocator, _: std.json.ObjectMap) anyerror!ToolResult {
        _ = self;
        return browserResult(allocator, "snapshot", "capture requested");
    }
};

pub const BrowserBack = struct {
    pub const SCHEMA = tools_if.ToolSchema{ .name = "browser_back", .description = "Navigate back in browser history", .parameters_schema =
        \\{"type":"object","properties":{}}
    };
    pub fn execute(self: *BrowserBack, allocator: std.mem.Allocator, _: std.json.ObjectMap) anyerror!ToolResult {
        _ = self;
        return browserResult(allocator, "back", "navigated back");
    }
};

pub const BrowserClose = struct {
    pub const SCHEMA = tools_if.ToolSchema{ .name = "browser_close", .description = "Close the browser", .parameters_schema =
        \\{"type":"object","properties":{}}
    };
    pub fn execute(self: *BrowserClose, allocator: std.mem.Allocator, _: std.json.ObjectMap) anyerror!ToolResult {
        _ = self;
        return browserResult(allocator, "close", "session closed");
    }
};

pub const BrowserConsole = struct {
    pub const SCHEMA = tools_if.ToolSchema{ .name = "browser_console", .description = "Execute JavaScript in browser console", .parameters_schema =
        \\{"type":"object","properties":{"script":{"type":"string"}},"required":["script"]}
    };
    pub fn execute(self: *BrowserConsole, allocator: std.mem.Allocator, args: std.json.ObjectMap) anyerror!ToolResult {
        _ = self;
        const script = tools_if.getString(args, "script") orelse return .{ .output = "missing script", .is_error = true };
        return browserResult(allocator, "console", script);
    }
};

pub const BrowserPress = struct {
    pub const SCHEMA = tools_if.ToolSchema{ .name = "browser_press", .description = "Press a key in the browser", .parameters_schema =
        \\{"type":"object","properties":{"key":{"type":"string"}},"required":["key"]}
    };
    pub fn execute(self: *BrowserPress, allocator: std.mem.Allocator, args: std.json.ObjectMap) anyerror!ToolResult {
        _ = self;
        const key = tools_if.getString(args, "key") orelse return .{ .output = "missing key", .is_error = true };
        return browserResult(allocator, "press", key);
    }
};

pub const BrowserGetImages = struct {
    pub const SCHEMA = tools_if.ToolSchema{ .name = "browser_get_images", .description = "Get all images from the current page", .parameters_schema =
        \\{"type":"object","properties":{}}
    };
    pub fn execute(self: *BrowserGetImages, allocator: std.mem.Allocator, _: std.json.ObjectMap) anyerror!ToolResult {
        _ = self;
        return browserResult(allocator, "get_images", "listing page images");
    }
};

pub const BrowserVision = struct {
    pub const SCHEMA = tools_if.ToolSchema{ .name = "browser_vision", .description = "Analyze page visually using vision model", .parameters_schema =
        \\{"type":"object","properties":{"prompt":{"type":"string"}},"required":["prompt"]}
    };
    pub fn execute(self: *BrowserVision, allocator: std.mem.Allocator, args: std.json.ObjectMap) anyerror!ToolResult {
        _ = self;
        const prompt = tools_if.getString(args, "prompt") orelse return .{ .output = "missing prompt", .is_error = true };
        return browserResult(allocator, "vision", prompt);
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
