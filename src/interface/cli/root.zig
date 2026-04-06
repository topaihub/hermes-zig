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
pub const auth_cmd = @import("auth_cmd.zig");
pub const tools_config = @import("tools_config.zig");
pub const mcp_config = @import("mcp_config.zig");
pub const cron_cmd = @import("cron_cmd.zig");
pub const skills_hub_cmd = @import("skills_hub_cmd.zig");
pub const clipboard = @import("clipboard.zig");
pub const main_entry = @import("main_entry.zig");
pub const uninstall = @import("uninstall.zig");
pub const checklist = @import("checklist.zig");
pub const claw = @import("claw.zig");
pub const codex_models = @import("codex_models.zig");
pub const copilot_auth = @import("copilot_auth.zig");
pub const curses_ui = @import("curses_ui.zig");
pub const pairing = @import("pairing.zig");
pub const skills_runtime = @import("skills_runtime.zig");
pub const input_controller = @import("input_controller.zig");

// Re-export key types
pub const RawMode = tui.RawMode;
pub const InputReader = tui.InputReader;
pub const CommandId = commands.CommandId;
pub const CommandSpec = commands.CommandSpec;
pub const ParsedCommand = commands.ParsedCommand;
pub const parseCommand = commands.parseCommand;
pub const renderCommandHelp = commands.renderHelp;
pub const StreamDisplay = display.StreamDisplay;
pub const History = history.History;
pub const renderPrompt = tui.renderPrompt;
pub const ansi = tui.ansi;
pub const readInputLine = input_controller.readInputLine;
pub const canUseInteractiveInput = input_controller.canUseInteractive;
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
pub const handleAuthCommand = auth_cmd.handleAuthCommand;
pub const handleToolsCommand = tools_config.handleToolsCommand;
pub const handleMcpCommand = mcp_config.handleMcpCommand;
pub const handleCronCommand = cron_cmd.handleCronCommand;
pub const handleSkillsHubCommand = skills_hub_cmd.handleSkillsHubCommand;
pub const saveClipboardImage = clipboard.saveClipboardImage;
pub const MainCommand = main_entry.Command;
pub const parseSubcommand = main_entry.parseSubcommand;
pub const handleUninstall = uninstall.handleUninstall;
pub const SkillsRuntime = skills_runtime.SkillsRuntime;

comptime {
    @import("std").testing.refAllDecls(@This());
}

test {
    _ = @import("commands.zig");
    _ = @import("history.zig");
    _ = @import("skills_runtime.zig");
    _ = @import("input_controller.zig");
}
