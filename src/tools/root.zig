pub const interface = @import("interface.zig");
pub const registry = @import("registry.zig");
pub const toolsets = @import("toolsets.zig");
pub const terminal = @import("terminal/root.zig");
pub const mcp = @import("mcp/root.zig");
pub const builtin = @import("builtin/root.zig");

// Re-export key types
pub const ToolHandler = interface.ToolHandler;
pub const ToolSchema = interface.ToolSchema;
pub const ToolContext = interface.ToolContext;
pub const makeToolHandler = interface.makeToolHandler;
pub const validateToolImpl = interface.validateToolImpl;
pub const ToolRegistry = registry.ToolRegistry;
pub const TerminalBackend = terminal.TerminalBackend;
pub const ExecResult = terminal.ExecResult;

comptime {
    @import("std").testing.refAllDecls(@This());
}
