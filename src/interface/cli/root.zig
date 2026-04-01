pub const tui = @import("tui.zig");
pub const commands = @import("commands.zig");
pub const display = @import("display.zig");
pub const history = @import("history.zig");

// Re-export key types
pub const RawMode = tui.RawMode;
pub const InputReader = tui.InputReader;
pub const Command = commands.Command;
pub const ParsedCommand = commands.ParsedCommand;
pub const parseCommand = commands.parseCommand;
pub const handleCommand = commands.handleCommand;
pub const StreamDisplay = display.StreamDisplay;
pub const History = history.History;
pub const renderPrompt = tui.renderPrompt;
pub const ansi = tui.ansi;

comptime {
    @import("std").testing.refAllDecls(@This());
}
