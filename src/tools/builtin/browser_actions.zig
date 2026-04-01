const std = @import("std");
const tools_if = @import("../interface.zig");

fn stubExecute(comptime name: []const u8, comptime ArgType: type, args_json: []const u8, ctx: *const tools_if.ToolContext) anyerror![]const u8 {
    const parsed = std.json.parseFromSlice(ArgType, ctx.allocator, args_json, .{ .ignore_unknown_fields = true }) catch
        return error.InvalidArgs;
    defer parsed.deinit();
    const v = parsed.value;
    return std.fmt.allocPrint(ctx.allocator, "[stub] {s}: {s}", .{ name, if (@hasField(ArgType, "url")) v.url else if (@hasField(ArgType, "selector")) v.selector else if (@hasField(ArgType, "text")) v.text else if (@hasField(ArgType, "key")) v.key else if (@hasField(ArgType, "direction")) v.direction else "" });
}

pub const BrowserNavigate = struct {
    pub const SCHEMA = tools_if.ToolSchema{ .name = "browser_navigate", .description = "Navigate browser to URL", .parameters_schema =
        \\{"type":"object","properties":{"url":{"type":"string"}},"required":["url"]}
    };
    pub fn execute(self: *BrowserNavigate, args_json: []const u8, ctx: *const tools_if.ToolContext) anyerror![]const u8 {
        _ = self;
        return stubExecute("browser_navigate", struct { url: []const u8 = "" }, args_json, ctx);
    }
};

pub const BrowserClick = struct {
    pub const SCHEMA = tools_if.ToolSchema{ .name = "browser_click", .description = "Click an element on the page", .parameters_schema =
        \\{"type":"object","properties":{"selector":{"type":"string"}},"required":["selector"]}
    };
    pub fn execute(self: *BrowserClick, args_json: []const u8, ctx: *const tools_if.ToolContext) anyerror![]const u8 {
        _ = self;
        return stubExecute("browser_click", struct { selector: []const u8 = "" }, args_json, ctx);
    }
};

pub const BrowserType = struct {
    pub const SCHEMA = tools_if.ToolSchema{ .name = "browser_type", .description = "Type text into an element", .parameters_schema =
        \\{"type":"object","properties":{"selector":{"type":"string"},"text":{"type":"string"}},"required":["selector","text"]}
    };
    pub fn execute(self: *BrowserType, args_json: []const u8, ctx: *const tools_if.ToolContext) anyerror![]const u8 {
        _ = self;
        const parsed = std.json.parseFromSlice(struct { selector: []const u8 = "", text: []const u8 = "" }, ctx.allocator, args_json, .{ .ignore_unknown_fields = true }) catch
            return error.InvalidArgs;
        defer parsed.deinit();
        return std.fmt.allocPrint(ctx.allocator, "[stub] browser_type: {s} -> {s}", .{ parsed.value.selector, parsed.value.text });
    }
};

pub const BrowserScroll = struct {
    pub const SCHEMA = tools_if.ToolSchema{ .name = "browser_scroll", .description = "Scroll the page", .parameters_schema =
        \\{"type":"object","properties":{"direction":{"type":"string"}},"required":["direction"]}
    };
    pub fn execute(self: *BrowserScroll, args_json: []const u8, ctx: *const tools_if.ToolContext) anyerror![]const u8 {
        _ = self;
        return stubExecute("browser_scroll", struct { direction: []const u8 = "" }, args_json, ctx);
    }
};

pub const BrowserSnapshot = struct {
    pub const SCHEMA = tools_if.ToolSchema{ .name = "browser_snapshot", .description = "Take a snapshot of the current page", .parameters_schema =
        \\{"type":"object","properties":{}}
    };
    pub fn execute(self: *BrowserSnapshot, _: []const u8, ctx: *const tools_if.ToolContext) anyerror![]const u8 {
        _ = self;
        return std.fmt.allocPrint(ctx.allocator, "[stub] browser_snapshot: captured", .{});
    }
};

pub const BrowserBack = struct {
    pub const SCHEMA = tools_if.ToolSchema{ .name = "browser_back", .description = "Navigate back in browser history", .parameters_schema =
        \\{"type":"object","properties":{}}
    };
    pub fn execute(self: *BrowserBack, _: []const u8, ctx: *const tools_if.ToolContext) anyerror![]const u8 {
        _ = self;
        return std.fmt.allocPrint(ctx.allocator, "[stub] browser_back: navigated back", .{});
    }
};

pub const BrowserClose = struct {
    pub const SCHEMA = tools_if.ToolSchema{ .name = "browser_close", .description = "Close the browser", .parameters_schema =
        \\{"type":"object","properties":{}}
    };
    pub fn execute(self: *BrowserClose, _: []const u8, ctx: *const tools_if.ToolContext) anyerror![]const u8 {
        _ = self;
        return std.fmt.allocPrint(ctx.allocator, "[stub] browser_close: closed", .{});
    }
};

pub const BrowserConsole = struct {
    pub const SCHEMA = tools_if.ToolSchema{ .name = "browser_console", .description = "Execute JavaScript in browser console", .parameters_schema =
        \\{"type":"object","properties":{"script":{"type":"string"}},"required":["script"]}
    };
    pub fn execute(self: *BrowserConsole, args_json: []const u8, ctx: *const tools_if.ToolContext) anyerror![]const u8 {
        _ = self;
        const parsed = std.json.parseFromSlice(struct { script: []const u8 = "" }, ctx.allocator, args_json, .{ .ignore_unknown_fields = true }) catch
            return error.InvalidArgs;
        defer parsed.deinit();
        return std.fmt.allocPrint(ctx.allocator, "[stub] browser_console: {s}", .{parsed.value.script});
    }
};

pub const BrowserPress = struct {
    pub const SCHEMA = tools_if.ToolSchema{ .name = "browser_press", .description = "Press a key in the browser", .parameters_schema =
        \\{"type":"object","properties":{"key":{"type":"string"}},"required":["key"]}
    };
    pub fn execute(self: *BrowserPress, args_json: []const u8, ctx: *const tools_if.ToolContext) anyerror![]const u8 {
        _ = self;
        return stubExecute("browser_press", struct { key: []const u8 = "" }, args_json, ctx);
    }
};

pub const BrowserGetImages = struct {
    pub const SCHEMA = tools_if.ToolSchema{ .name = "browser_get_images", .description = "Get all images from the current page", .parameters_schema =
        \\{"type":"object","properties":{}}
    };
    pub fn execute(self: *BrowserGetImages, _: []const u8, ctx: *const tools_if.ToolContext) anyerror![]const u8 {
        _ = self;
        return std.fmt.allocPrint(ctx.allocator, "[stub] browser_get_images: []", .{});
    }
};

pub const BrowserVision = struct {
    pub const SCHEMA = tools_if.ToolSchema{ .name = "browser_vision", .description = "Analyze page visually using vision model", .parameters_schema =
        \\{"type":"object","properties":{"prompt":{"type":"string"}},"required":["prompt"]}
    };
    pub fn execute(self: *BrowserVision, args_json: []const u8, ctx: *const tools_if.ToolContext) anyerror![]const u8 {
        _ = self;
        const parsed = std.json.parseFromSlice(struct { prompt: []const u8 = "" }, ctx.allocator, args_json, .{ .ignore_unknown_fields = true }) catch
            return error.InvalidArgs;
        defer parsed.deinit();
        return std.fmt.allocPrint(ctx.allocator, "[stub] browser_vision: {s}", .{parsed.value.prompt});
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
