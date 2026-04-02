pub const tui = @import("tui.zig");
pub const commands = @import("commands.zig");
pub const display = @import("display.zig");
pub const history = @import("history.zig");
pub const setup = @import("setup.zig");
pub const auth = @import("auth.zig");
pub const profiles = @import("profiles.zig");
pub const doctor = @import("doctor.zig");
pub const skin = @import("skin.zig");
pub const banner = @import("banner.zig");
pub const status = @import("status.zig");
pub const plugins = @import("plugins.zig");
pub const colors = @import("colors.zig");
pub const config_manager = @import("config_manager.zig");
pub const model_manager = @import("model_manager.zig");
pub const gateway_cmd = @import("gateway_cmd.zig");
pub const env_loader = @import("env_loader.zig");

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
pub const SetupWizard = setup.SetupWizard;
pub const AuthManager = auth.AuthManager;
pub const ProfileManager = profiles.ProfileManager;
pub const Doctor = doctor.Doctor;
pub const SkinEngine = skin.SkinEngine;
pub const renderBanner = banner.renderBanner;
pub const StatusBar = status.StatusBar;
pub const PluginManager = plugins.PluginManager;
pub const ConfigManager = config_manager.ConfigManager;
pub const ModelManager = model_manager.ModelManager;
pub const GatewayCmd = gateway_cmd.GatewayCmd;
pub const loadDotEnv = env_loader.loadDotEnv;

comptime {
    @import("std").testing.refAllDecls(@This());
}
