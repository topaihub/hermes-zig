const std = @import("std");
const builtin = @import("builtin");
const commands = @import("commands.zig");
const history_mod = @import("history.zig");
const tui = @import("tui.zig");

const windows = std.os.windows;
const kernel32 = windows.kernel32;

extern "kernel32" fn GetConsoleMode(hConsoleHandle: windows.HANDLE, lpMode: *windows.DWORD) callconv(.winapi) windows.BOOL;
extern "kernel32" fn SetConsoleMode(hConsoleHandle: windows.HANDLE, dwMode: windows.DWORD) callconv(.winapi) windows.BOOL;

const KEY_EVENT: windows.WORD = 0x0001;
const ENABLE_PROCESSED_INPUT: windows.DWORD = 0x0001;
const ENABLE_LINE_INPUT: windows.DWORD = 0x0002;
const ENABLE_ECHO_INPUT: windows.DWORD = 0x0004;

const VK_TAB: windows.WORD = 0x09;
const VK_RETURN: windows.WORD = 0x0D;
const VK_ESCAPE: windows.WORD = 0x1B;
const VK_BACK: windows.WORD = 0x08;
const VK_UP: windows.WORD = 0x26;
const VK_DOWN: windows.WORD = 0x28;

const KeyEventRecord = extern struct {
    bKeyDown: windows.BOOL,
    wRepeatCount: windows.WORD,
    wVirtualKeyCode: windows.WORD,
    wVirtualScanCode: windows.WORD,
    uChar: extern union {
        UnicodeChar: windows.WCHAR,
        AsciiChar: u8,
    },
    dwControlKeyState: windows.DWORD,
};

const InputRecord = extern struct {
    EventType: windows.WORD,
    Event: extern union {
        KeyEvent: KeyEventRecord,
        padding: [16]u8,
    },
};

extern "kernel32" fn ReadConsoleInputW(
    hConsoleInput: ?windows.HANDLE,
    lpBuffer: [*]InputRecord,
    nLength: windows.DWORD,
    lpNumberOfEventsRead: *windows.DWORD,
) callconv(.winapi) windows.BOOL;

pub fn canUseInteractive(stdin: std.Io.File, stdout: std.Io.File) bool {
    if (builtin.os.tag == .windows) {
        var stdin_mode: windows.DWORD = 0;
        if (GetConsoleMode(stdin.handle, &stdin_mode) == .FALSE) return false;

        var stdout_mode: windows.DWORD = 0;
        if (GetConsoleMode(stdout.handle, &stdout_mode) == .FALSE) return false;

        return stdout.getOrEnableAnsiEscapeSupport();
    }

    return stdin.isTty() and stdout.getOrEnableAnsiEscapeSupport();
}

pub fn readInputLine(
    allocator: std.mem.Allocator,
    stdin: std.Io.File,
    stdout: std.Io.File,
    history: *history_mod.History,
) !?[]u8 {
    if (!canUseInteractive(stdin, stdout)) {
        const line = try readLineFallback(allocator, stdin);
        if (line) |text| {
            if (text.len > 0) try history.add(text);
        }
        return line;
    }

    return switch (builtin.os.tag) {
        .windows => readInteractiveWindows(allocator, stdin, stdout, history),
        else => readInteractivePosix(allocator, stdin, stdout, history),
    };
}

const Key = union(enum) {
    char: []u8,
    enter,
    backspace,
    tab,
    escape,
    up,
    down,
    unknown,
};

const max_visible_menu_items: usize = 5;

const Selector = struct {
    item_count: usize,
    selected_index: usize,
    viewport_start: usize = 0,

    fn init(item_count: usize, selected_index: usize) Selector {
        var selector = Selector{
            .item_count = item_count,
            .selected_index = if (item_count == 0) 0 else @min(selected_index, item_count - 1),
        };
        selector.ensureSelectionVisible();
        return selector;
    }

    fn moveSelection(self: *Selector, delta: i32) void {
        if (self.item_count == 0) return;
        const count: i32 = @intCast(self.item_count);
        var next: i32 = @intCast(self.selected_index);
        next = @mod(next + delta + count, count);
        self.selected_index = @intCast(next);
        self.ensureSelectionVisible();
    }

    fn ensureSelectionVisible(self: *Selector) void {
        if (self.item_count == 0) {
            self.viewport_start = 0;
            return;
        }
        if (self.selected_index < self.viewport_start) {
            self.viewport_start = self.selected_index;
            return;
        }
        const viewport_end = self.viewport_start + max_visible_menu_items;
        if (self.selected_index >= viewport_end) {
            self.viewport_start = self.selected_index + 1 - max_visible_menu_items;
        }
    }

    fn visibleCount(self: *const Selector) usize {
        if (self.item_count == 0) return 0;
        return @min(self.item_count - self.viewport_start, max_visible_menu_items);
    }
};

const Editor = struct {
    allocator: std.mem.Allocator,
    buffer: std.ArrayList(u8),
    suggestions: [16]usize = undefined,
    suggestion_count: usize = 0,
    selected_index: usize = 0,
    viewport_start: usize = 0,
    suggestions_visible: bool = false,
    rendered_menu_lines: usize = 0,

    fn deinit(self: *Editor) void {
        self.buffer.deinit();
    }

    fn appendText(self: *Editor, text: []const u8) !void {
        try self.buffer.appendSlice(text);
        self.refreshSuggestions();
    }

    fn backspace(self: *Editor) void {
        if (self.buffer.items.len == 0) return;
        var idx = self.buffer.items.len - 1;
        while (idx > 0 and (self.buffer.items[idx] & 0b1100_0000) == 0b1000_0000) : (idx -= 1) {}
        self.buffer.items.len = idx;
        self.refreshSuggestions();
    }

    fn setBuffer(self: *Editor, value: []const u8) !void {
        self.buffer.clearRetainingCapacity();
        try self.buffer.appendSlice(value);
        self.refreshSuggestions();
    }

    fn refreshSuggestions(self: *Editor) void {
        self.selected_index = 0;
        self.viewport_start = 0;
        if (self.buffer.items.len == 0 or self.buffer.items[0] != '/') {
            self.suggestions_visible = false;
            self.suggestion_count = 0;
            return;
        }
        const prefix = self.buffer.items[1..];
        self.suggestion_count = commands.matchesForPrefix(prefix, &self.suggestions);
        self.suggestions_visible = self.suggestion_count > 0;
    }

    fn moveSelection(self: *Editor, delta: i32) void {
        if (!self.suggestions_visible or self.suggestion_count == 0) return;
        var selector = Selector{
            .item_count = self.suggestion_count,
            .selected_index = self.selected_index,
            .viewport_start = self.viewport_start,
        };
        selector.moveSelection(delta);
        self.selected_index = selector.selected_index;
        self.viewport_start = selector.viewport_start;
    }

    fn completeSelection(self: *Editor) !void {
        if (!self.suggestions_visible or self.suggestion_count == 0) return;
        const spec = commands.allPrimarySpecs()[self.suggestions[self.selected_index]];
        self.buffer.clearRetainingCapacity();
        try self.buffer.append('/');
        try self.buffer.appendSlice(spec.literal);
        if (spec.takes_arg) {
            try self.buffer.append(' ');
        }
        self.refreshSuggestions();
    }

    fn visibleSuggestionCount(self: *const Editor) usize {
        if (!self.suggestions_visible or self.suggestion_count == 0) return 0;
        const selector = Selector{
            .item_count = self.suggestion_count,
            .selected_index = self.selected_index,
            .viewport_start = self.viewport_start,
        };
        return selector.visibleCount();
    }
};

pub fn runSelectionMenu(
    allocator: std.mem.Allocator,
    stdin: std.fs.File,
    stdout: std.fs.File,
    title: []const u8,
    items: []const []const u8,
    selected_index: usize,
) !?usize {
    if (items.len == 0 or !canUseInteractive(stdin, stdout)) return null;

    return switch (builtin.os.tag) {
        .windows => runSelectionMenuWindows(allocator, stdin, stdout, title, items, selected_index),
        else => runSelectionMenuPosix(allocator, stdin, stdout, title, items, selected_index),
    };
}

fn readInteractiveWindows(
    allocator: std.mem.Allocator,
    stdin: std.fs.File,
    stdout: std.fs.File,
    history: *history_mod.History,
) !?[]u8 {
    const guard = try ConsoleInputModeGuard.enable(stdin);
    defer guard.disable();

    var editor = Editor{ 
        .allocator = allocator,
        .buffer = std.ArrayList(u8).init(allocator),
    };
    defer editor.deinit();

    while (true) {
        try renderEditor(stdout, &editor);
        const key = try readKeyWindows(allocator, stdin);
        defer switch (key) {
            .char => |text| allocator.free(text),
            else => {},
        };

        switch (key) {
            .char => |text| try editor.appendText(text),
            .backspace => editor.backspace(),
            .tab => try editor.completeSelection(),
            .escape => {
                editor.suggestions_visible = false;
                editor.suggestion_count = 0;
                editor.selected_index = 0;
            },
            .up => if (editor.suggestions_visible)
                editor.moveSelection(-1)
            else if (history.up()) |entry|
                try editor.setBuffer(entry),
            .down => if (editor.suggestions_visible)
                editor.moveSelection(1)
            else if (history.down()) |entry|
                try editor.setBuffer(entry)
            else
                try editor.setBuffer(""),
            .enter => {
                if (editor.suggestions_visible and editor.suggestion_count > 0) {
                    try editor.completeSelection();
                }
                const line = try finalizeEditor(allocator, stdout, &editor);
                if (line.len > 0) try history.add(line);
                return line;
            },
            .unknown => {},
        }
    }
}

fn readInteractivePosix(
    allocator: std.mem.Allocator,
    stdin: std.fs.File,
    stdout: std.fs.File,
    history: *history_mod.History,
) !?[]u8 {
    const raw = try tui.RawMode.enable(stdin.handle);
    defer raw.disable();

    const reader = tui.InputReader{ .fd = stdin.handle };
    var editor = Editor{ 
        .allocator = allocator,
        .buffer = std.ArrayList(u8).init(allocator),
    };
    defer editor.deinit();

    while (true) {
        try renderEditor(stdout, &editor);
        const key = try readKeyPosix(allocator, reader);
        defer switch (key) {
            .char => |text| allocator.free(text),
            else => {},
        };

        switch (key) {
            .char => |text| try editor.appendText(text),
            .backspace => editor.backspace(),
            .tab => try editor.completeSelection(),
            .escape => {
                editor.suggestions_visible = false;
                editor.suggestion_count = 0;
                editor.selected_index = 0;
            },
            .up => if (editor.suggestions_visible)
                editor.moveSelection(-1)
            else if (history.up()) |entry|
                try editor.setBuffer(entry),
            .down => if (editor.suggestions_visible)
                editor.moveSelection(1)
            else if (history.down()) |entry|
                try editor.setBuffer(entry)
            else
                try editor.setBuffer(""),
            .enter => {
                if (editor.suggestions_visible and editor.suggestion_count > 0) {
                    try editor.completeSelection();
                }
                const line = try finalizeEditor(allocator, stdout, &editor);
                if (line.len > 0) try history.add(line);
                return line;
            },
            .unknown => {},
        }
    }
}

fn runSelectionMenuWindows(
    allocator: std.mem.Allocator,
    stdin: std.fs.File,
    stdout: std.fs.File,
    title: []const u8,
    items: []const []const u8,
    selected_index: usize,
) !?usize {
    const guard = try ConsoleInputModeGuard.enable(stdin);
    defer guard.disable();

    var selector = Selector.init(items.len, selected_index);
    var rendered_lines: usize = 0;
    defer if (rendered_lines > 0) clearRenderedArea(stdout, rendered_lines) catch {};

    while (true) {
        rendered_lines = try renderSelectionMenu(stdout, title, items, &selector, rendered_lines);
        const key = try readKeyWindows(allocator, stdin);
        defer switch (key) {
            .char => |text| allocator.free(text),
            else => {},
        };

        switch (key) {
            .up => selector.moveSelection(-1),
            .down => selector.moveSelection(1),
            .enter => return selector.selected_index,
            .escape => return null,
            else => {},
        }
    }
}

fn runSelectionMenuPosix(
    allocator: std.mem.Allocator,
    stdin: std.fs.File,
    stdout: std.fs.File,
    title: []const u8,
    items: []const []const u8,
    selected_index: usize,
) !?usize {
    const raw = try tui.RawMode.enable(stdin.handle);
    defer raw.disable();

    const reader = tui.InputReader{ .fd = stdin.handle };
    var selector = Selector.init(items.len, selected_index);
    var rendered_lines: usize = 0;
    defer if (rendered_lines > 0) clearRenderedArea(stdout, rendered_lines) catch {};

    while (true) {
        rendered_lines = try renderSelectionMenu(stdout, title, items, &selector, rendered_lines);
        const key = try readKeyPosix(allocator, reader);
        defer switch (key) {
            .char => |text| allocator.free(text),
            else => {},
        };

        switch (key) {
            .up => selector.moveSelection(-1),
            .down => selector.moveSelection(1),
            .enter => return selector.selected_index,
            .escape => return null,
            else => {},
        }
    }
}

fn finalizeEditor(allocator: std.mem.Allocator, stdout: std.fs.File, editor: *Editor) ![]u8 {
    try clearRenderedArea(stdout, editor.rendered_menu_lines);
    const line = try editor.buffer.toOwnedSlice(allocator);
    editor.buffer = .{};
    editor.rendered_menu_lines = 0;

    var buf: [4096]u8 = undefined;
    var writer = stdout.writer(&buf);
    try tui.renderPrompt(&writer.interface);
    try writer.interface.writeAll(line);
    try writer.interface.writeAll("\n");
    try writer.interface.flush();
    return line;
}

fn renderSelectionMenu(
    stdout: std.fs.File,
    title: []const u8,
    items: []const []const u8,
    selector: *const Selector,
    previous_lines: usize,
) !usize {
    try clearRenderedArea(stdout, previous_lines);

    var buf: [8192]u8 = undefined;
    var writer = stdout.writer(&buf);
    try writer.interface.writeAll("\r");
    try writer.interface.print("\x1b[1m{s}\x1b[0m", .{title});

    const visible_count = selector.visibleCount();
    for (0..visible_count) |offset| {
        const absolute_index = selector.viewport_start + offset;
        const item = items[absolute_index];
        const is_selected = absolute_index == selector.selected_index;
        try writer.interface.writeAll("\n");
        if (is_selected) {
            try writer.interface.writeAll("  \x1b[36m>\x1b[0m ");
            try writer.interface.print("\x1b[1m{s}\x1b[0m", .{item});
        } else {
            try writer.interface.print("    {s}", .{item});
        }
    }
    if (visible_count > 0) {
        try writer.interface.print("\x1b[{d}A\r", .{visible_count});
    }
    try writer.interface.flush();
    return visible_count;
}

fn renderEditor(stdout: std.fs.File, editor: *Editor) !void {
    try clearRenderedArea(stdout, editor.rendered_menu_lines);
    var buf: [8192]u8 = undefined;
    var writer = stdout.writer(&buf);
    try tui.renderPrompt(&writer.interface);
    try writer.interface.writeAll(editor.buffer.items);
    const visible_count = editor.visibleSuggestionCount();
    if (visible_count > 0) {
        for (0..visible_count) |offset| {
            const absolute_index = editor.viewport_start + offset;
            const spec = commands.allPrimarySpecs()[editor.suggestions[absolute_index]];
            const is_selected = absolute_index == editor.selected_index;

            try writer.interface.writeAll("\n");
            if (is_selected) {
                try writer.interface.writeAll("  \x1b[36m>\x1b[0m ");
                try writer.interface.print("\x1b[1m/{s}\x1b[0m", .{spec.literal});
                const summary = truncatedSummary(spec.summary);
                if (summary.len > 0) {
                    try writer.interface.print(" — {s}", .{summary});
                }
            } else {
                try writer.interface.print("    /{s}", .{spec.literal});
            }
        }
        try writer.interface.print("\x1b[{d}A\r", .{visible_count});
        try tui.renderPrompt(&writer.interface);
        try writer.interface.writeAll(editor.buffer.items);
    }
    try writer.interface.flush();
    editor.rendered_menu_lines = visible_count;
}

fn clearRenderedArea(stdout: std.fs.File, rendered_menu_lines: usize) !void {
    try stdout.writeAll("\r\x1b[2K");
    for (0..rendered_menu_lines) |_| {
        try stdout.writeAll("\n\r\x1b[2K");
    }
    if (rendered_menu_lines > 0) {
        var buf: [32]u8 = undefined;
        const seq = try std.fmt.bufPrint(&buf, "\x1b[{d}A\r", .{rendered_menu_lines});
        try stdout.writeAll(seq);
    }
}

fn truncatedSummary(summary: []const u8) []const u8 {
    const max_len = 48;
    if (summary.len <= max_len) return summary;
    return summary[0..max_len];
}

fn readLineFallback(allocator: std.mem.Allocator, stdin: std.Io.File) !?[]u8 {
    var out = std.ArrayList(u8).empty;
    defer out.deinit(allocator);

    var buf: [1]u8 = undefined;
    while (true) {
        const n = try stdin.read(&buf);
        if (n == 0) {
            if (out.items.len == 0) return null;
            break;
        }
        if (buf[0] == '\n') break;
        if (buf[0] != '\r') try out.append(allocator, buf[0]);
    }
    return try out.toOwnedSlice(allocator);
}

fn readKeyWindows(allocator: std.mem.Allocator, stdin: std.fs.File) !Key {
    while (true) {
        var record: InputRecord = undefined;
        var events_read: windows.DWORD = 0;
        if (ReadConsoleInputW(stdin.handle, @ptrCast(&record), 1, &events_read) == 0 or events_read == 0) {
            return .unknown;
        }
        if (record.EventType != KEY_EVENT) continue;

        const key_event = record.Event.KeyEvent;
        if (key_event.bKeyDown == 0) continue;

        switch (key_event.wVirtualKeyCode) {
            VK_BACK => return .backspace,
            VK_TAB => return .tab,
            VK_RETURN => return .enter,
            VK_ESCAPE => return .escape,
            VK_UP => return .up,
            VK_DOWN => return .down,
            else => {},
        }

        if (key_event.uChar.UnicodeChar != 0) {
            return .{ .char = try utf16CodeUnitsToUtf8Alloc(allocator, &.{key_event.uChar.UnicodeChar}) };
        }
    }
}

fn readKeyPosix(allocator: std.mem.Allocator, reader: tui.InputReader) !Key {
    var buf: [8]u8 = undefined;
    while (true) {
        const bytes = try reader.read(&buf);
        if (bytes.len == 0) continue;

        const first = bytes[0];
        return switch (first) {
            9 => .tab,
            10, 13 => .enter,
            27 => blk: {
                if (bytes.len >= 3 and bytes[1] == '[') {
                    break :blk switch (bytes[2]) {
                        'A' => .up,
                        'B' => .down,
                        else => .escape,
                    };
                }
                break :blk .escape;
            },
            127, 8 => .backspace,
            else => .{ .char = try allocator.dupe(u8, bytes[0..1]) },
        };
    }
}

fn utf16CodeUnitsToUtf8Alloc(allocator: std.mem.Allocator, code_units: []const u16) ![]u8 {
    return std.unicode.utf16LeToUtf8Alloc(allocator, code_units);
}

const ConsoleInputModeGuard = struct {
    handle: windows.HANDLE,
    original_mode: windows.DWORD,
    enabled: bool,

    fn enable(stdin: std.fs.File) !ConsoleInputModeGuard {
        var original_mode: windows.DWORD = 0;
        if (kernel32.GetConsoleMode(stdin.handle, &original_mode) == 0) {
            return .{ .handle = stdin.handle, .original_mode = 0, .enabled = false };
        }

        const new_mode = original_mode & ~(ENABLE_PROCESSED_INPUT | ENABLE_LINE_INPUT | ENABLE_ECHO_INPUT);
        if (kernel32.SetConsoleMode(stdin.handle, new_mode) == 0) {
            return .{ .handle = stdin.handle, .original_mode = original_mode, .enabled = false };
        }

        return .{
            .handle = stdin.handle,
            .original_mode = original_mode,
            .enabled = true,
        };
    }

    fn disable(self: ConsoleInputModeGuard) void {
        if (!self.enabled) return;
        _ = kernel32.SetConsoleMode(self.handle, self.original_mode);
    }
};

test "editor slash prefix opens suggestions" {
    var editor = Editor{ .allocator = std.testing.allocator };
    defer editor.deinit();

    try editor.appendText("/");

    try std.testing.expect(editor.suggestions_visible);
    try std.testing.expect(editor.suggestion_count > 0);
}

test "editor tab completion appends trailing space for arg commands" {
    var editor = Editor{ .allocator = std.testing.allocator };
    defer editor.deinit();

    try editor.appendText("/skills u");
    try std.testing.expect(editor.suggestions_visible);
    try editor.completeSelection();

    try std.testing.expectEqualStrings("/skills use ", editor.buffer.items);
}

test "editor leaving slash mode hides suggestions" {
    var editor = Editor{ .allocator = std.testing.allocator };
    defer editor.deinit();

    try editor.appendText("/");
    try std.testing.expect(editor.suggestions_visible);
    editor.backspace();
    try std.testing.expect(!editor.suggestions_visible);
}

test "editor selection scrolls viewport" {
    var editor = Editor{ .allocator = std.testing.allocator };
    defer editor.deinit();

    try editor.appendText("/");
    try std.testing.expect(editor.suggestion_count > max_visible_menu_items);

    for (0..max_visible_menu_items) |_| {
        editor.moveSelection(1);
    }

    try std.testing.expect(editor.viewport_start > 0);
    try std.testing.expect(editor.selected_index >= editor.viewport_start);
}

test "editor enter can submit selected slash command" {
    var editor = Editor{ .allocator = std.testing.allocator };
    defer editor.deinit();

    try editor.appendText("/");
    try std.testing.expect(editor.suggestions_visible);
    try editor.completeSelection();

    try std.testing.expect(std.mem.startsWith(u8, editor.buffer.items, "/"));
    try std.testing.expect(editor.buffer.items.len > 1);
}

test "selector scrolls viewport" {
    var selector = Selector.init(10, 0);
    for (0..max_visible_menu_items) |_| {
        selector.moveSelection(1);
    }
    try std.testing.expect(selector.viewport_start > 0);
    try std.testing.expect(selector.selected_index >= selector.viewport_start);
}
