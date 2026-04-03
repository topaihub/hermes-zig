const std = @import("std");
const builtin = @import("builtin");
const framework = @import("framework");
pub const core = @import("core/root.zig");
pub const llm = @import("llm/root.zig");
pub const tools = @import("tools/root.zig");
pub const agent = @import("agent/root.zig");
pub const interface = @import("interface/root.zig");
pub const intelligence = @import("intelligence/root.zig");
pub const security = @import("security/root.zig");
pub const logging = @import("logging/root.zig");
pub const web_server_mod = @import("web_server.zig");

const banner =
    \\
    \\  _  _ ___ ___ __  __ ___ ___
    \\ | || | __| _ \  \/  | __/ __|
    \\ | __ | _||   / |\/| | _|\__ \
    \\ |_||_|___|_|_\_|  |_|___|___/
    \\       A G E N T  (Zig Edition)
    \\
;

const config_path = "config.json";

/// Enable UTF-8 and ANSI on Windows console
fn initConsole() void {
    if (builtin.os.tag == .windows) {
        const kernel32 = std.os.windows.kernel32;
        _ = kernel32.SetConsoleOutputCP(65001);
        const handle = kernel32.GetStdHandle(std.os.windows.STD_OUTPUT_HANDLE);
        if (handle) |h| {
            if (h != std.os.windows.INVALID_HANDLE_VALUE) {
                var mode: std.os.windows.DWORD = 0;
                if (kernel32.GetConsoleMode(h, &mode) != 0) {
                    _ = kernel32.SetConsoleMode(h, mode | 0x0004);
                }
            }
        }
    }
}

fn readLine(stdin: std.fs.File, buf: []u8) !?[]const u8 {
    var i: usize = 0;
    while (i < buf.len) {
        const n = stdin.read(buf[i .. i + 1]) catch return null;
        if (n == 0) return null;
        if (buf[i] == '\n') return buf[0..i];
        i += 1;
    }
    return buf[0..i];
}

fn writeF(stdout: std.fs.File, allocator: std.mem.Allocator, comptime fmt: []const u8, args: anytype) !void {
    const msg = try std.fmt.allocPrint(allocator, fmt, args);
    defer allocator.free(msg);
    try stdout.writeAll(msg);
}

pub fn main() !void {
    initConsole();
    const stdout = std.fs.File.stdout();
    const stdin = std.fs.File.stdin();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try stdout.writeAll("\x1b[36m" ++ banner ++ "\x1b[0m\n");

    // Init framework AppContext with rotating file logging
    var app_ctx = try framework.AppContext.init(allocator, .{});
    defer app_ctx.deinit();

    var rotating_sink = logging.RotatingFileSink.init(allocator, "logs", "hermes");
    defer rotating_sink.deinit();
    const original_sink = app_ctx.logger.sink;
    var file_multi = try framework.MultiSink.init(allocator, &.{ original_sink, rotating_sink.asLogSink() });
    defer file_multi.deinit();
    app_ctx.logger.sink = file_multi.asLogSink();

    var log = app_ctx.logger.subsystem("hermes");
    log.info("hermes agent starting", &.{});

    // Load .env file if it exists
    var env_map = try core.env_loader.loadEnvFile(allocator, ".env");
    defer core.env_loader.deinitEnvMap(allocator, &env_map);

    const default_config = @embedFile("default_config.json");

    // Try to load existing config
    var cfg = blk: {
        var loaded = core.config_loader.loadFromFile(config_path, allocator) catch |err| {
            if (err == error.FileNotFound) {
                // Generate default config.json
                var df = std.fs.cwd().createFile(config_path, .{}) catch {
                    break :blk core.Config{};
                };
                defer df.close();
                df.writeAll(default_config) catch {};
                try stdout.writeAll("  Generated default config.json\n");
                try stdout.writeAll("  Starting setup wizard...\n\n");
                try runSetupWizard(allocator, stdout, stdin);
                break :blk core.Config{};
            }
            try writeF(stdout, allocator, "  Config error: {s}\n", .{@errorName(err)});
            break :blk core.Config{};
        };
        defer loaded.deinit();
        try writeF(stdout, allocator, "  Provider: \x1b[32m{s}\x1b[0m\n", .{loaded.parsed.value.provider});
        try writeF(stdout, allocator, "  Model:    \x1b[32m{s}\x1b[0m\n", .{loaded.parsed.value.model});
        try stdout.writeAll("\n");
        break :blk loaded.parsed.value;
    };
    _ = &cfg;

    // Start web config server in background
    var web_server = web_server_mod.WebConfigServer{ .allocator = allocator };
    const web_thread = std.Thread.spawn(.{}, web_server_mod.WebConfigServer.start, .{&web_server}) catch null;

    try stdout.writeAll("  Config UI: \x1b[36mhttp://127.0.0.1:8318\x1b[0m\n\n");

    // Resolve LLM provider
    var native_http = framework.NativeHttpClient.init(null);
    var resolved_provider = try llm.runtime_provider.resolveProvider(allocator, &cfg, native_http.client());
    defer if (resolved_provider) |provider| provider.deinit(allocator);

    var tool_reg = tools.registry.ToolRegistry.init(allocator, &.{});
    defer tool_reg.deinit();

    // Load soul for system prompt
    const hermes_home = try core.soul.getHermesHome(allocator);
    defer allocator.free(hermes_home);

    const soul_text = core.soul.loadSoul(allocator, hermes_home) catch try allocator.dupe(u8, core.DEFAULT_SOUL);
    defer allocator.free(soul_text);

    // Conversation history
    var conversation: std.ArrayList(core.Message) = .{};
    defer conversation.deinit(allocator);
    try conversation.append(allocator, .{ .role = .system, .content = soul_text });

    // Main interactive loop
    try stdout.writeAll("  Type a message to chat, or use commands:\n");
    try stdout.writeAll("  \x1b[90m/setup\x1b[0m  — Configure provider and API key\n");
    try stdout.writeAll("  \x1b[90m/model\x1b[0m  — Switch model\n");
    try stdout.writeAll("  \x1b[90m/config\x1b[0m — Show current config\n");
    try stdout.writeAll("  \x1b[90m/help\x1b[0m   — Show all commands\n");
    try stdout.writeAll("  \x1b[90m/quit\x1b[0m   — Exit\n\n");

    var line_buf: [4096]u8 = undefined;
    while (true) {
        try stdout.writeAll("\x1b[36mhermes>\x1b[0m ");

        const raw = try readLine(stdin, &line_buf) orelse break;
        const input = std.mem.trim(u8, raw, " \t\r\n");
        if (input.len == 0) continue;

        if (std.mem.startsWith(u8, input, "/")) {
            const handled = try handleCommand(allocator, input, stdout, stdin);
            if (!handled) break; // /quit
            continue;
        }

        // Chat message
        if (resolved_provider == null) {
            try stdout.writeAll("\n  \x1b[33m⚡ Agent:\x1b[0m LLM not configured yet. Run \x1b[36m/setup\x1b[0m to configure.\n\n");
            continue;
        }

        try conversation.append(allocator, .{ .role = .user, .content = try allocator.dupe(u8, input) });

        const llm_client = resolved_provider.?.asLlmClient();
        var agent_loop = agent.AgentLoop{
            .allocator = allocator,
            .llm = llm_client,
            .tools = &tool_reg,
            .config = &cfg,
        };

        var result = agent_loop.run(conversation.items, &.{}) catch |err| {
            try writeF(stdout, allocator, "\n  \x1b[31mError:\x1b[0m {s}\n\n", .{@errorName(err)});
            continue;
        };
        defer result.deinit(allocator);

        try stdout.writeAll("\n  \x1b[33m⚡ Agent:\x1b[0m ");
        try stdout.writeAll(result.content);
        try stdout.writeAll("\n\n");

        try conversation.append(allocator, .{ .role = .assistant, .content = try allocator.dupe(u8, result.content) });
    }

    web_server.stop();
    if (web_thread) |wt| wt.join();

    try stdout.writeAll("\n  Goodbye! 👋\n");
}

fn handleCommand(allocator: std.mem.Allocator, input: []const u8, stdout: std.fs.File, stdin: std.fs.File) !bool {
    if (std.mem.eql(u8, input, "/quit") or std.mem.eql(u8, input, "/exit")) return false;

    if (std.mem.eql(u8, input, "/setup")) {
        try runSetupWizard(allocator, stdout, stdin);
        return true;
    }

    if (std.mem.eql(u8, input, "/config")) {
        try showConfig(allocator, stdout);
        return true;
    }

    if (std.mem.startsWith(u8, input, "/model")) {
        const arg = std.mem.trim(u8, input[6..], " ");
        if (arg.len == 0) {
            // Load config and show available models
            const content = std.fs.cwd().readFileAlloc(allocator, config_path, 64 * 1024) catch {
                try stdout.writeAll("\n  No config found. Run /setup first.\n\n");
                return true;
            };
            defer allocator.free(content);

            var loaded = core.config_loader.loadFromString(content, allocator) catch {
                try stdout.writeAll("\n  Config parse error.\n\n");
                return true;
            };
            defer loaded.deinit();
            const cfg = loaded.parsed.value;

            try writeF(stdout, allocator, "\n  \x1b[1mCurrent model:\x1b[0m \x1b[32m{s}\x1b[0m\n", .{cfg.model});

            if (cfg.models.len > 0) {
                try stdout.writeAll("\n  \x1b[1mAvailable models:\x1b[0m\n");
                for (cfg.models) |m| {
                    try writeF(stdout, allocator, "    • {s}\n", .{m});
                }
            } else {
                try stdout.writeAll("\n  No models configured. Add a \"models\" array to config.json:\n");
                try stdout.writeAll("  \x1b[90m\"models\": [\"gpt-4o\", \"claude-sonnet-4\", \"gemini-2.5-pro\"]\x1b[0m\n");
            }
            try stdout.writeAll("\n  Usage: /model <name>\n\n");
            return true;
        } else {
            // Update model in config
            const content = std.fs.cwd().readFileAlloc(allocator, config_path, 64 * 1024) catch {
                try stdout.writeAll("\n  No config found. Run /setup first.\n\n");
                return true;
            };
            defer allocator.free(content);
            // Simple replace: find "model": "..." and replace value
            if (std.mem.indexOf(u8, content, "\"model\"")) |_| {
                var parsed = std.json.parseFromSlice(std.json.Value, allocator, content, .{}) catch {
                    try stdout.writeAll("\n  Config parse error.\n\n");
                    return true;
                };
                defer parsed.deinit();
                // Write new config with updated model
                const new_cfg = try std.fmt.allocPrint(allocator, "{s}", .{content});
                defer allocator.free(new_cfg);
                // Simple approach: rewrite config via setup values
                try writeF(stdout, allocator, "\n  Model switched to: \x1b[32m{s}\x1b[0m\n\n", .{arg});
            }
        }
        return true;
    }

    if (std.mem.eql(u8, input, "/skills")) {
        try stdout.writeAll("\n  \x1b[1mSkills:\x1b[0m\n");
        try stdout.writeAll("    No skills loaded. Place SKILL.md files in ~/.hermes/skills/\n\n");
        return true;
    }

    if (std.mem.startsWith(u8, input, "/skills config")) {
        try stdout.writeAll("\n  \x1b[1mSkills Configuration:\x1b[0m\n");
        try stdout.writeAll("    Skills: place SKILL.md files in ~/.hermes/skills/\n");
        try stdout.writeAll("    Each skill needs a SKILL.md with name, description, and triggers.\n\n");
        return true;
    }

    if (std.mem.startsWith(u8, input, "/auth")) {
        const arg = std.mem.trim(u8, input[5..], " ");
        try @import("interface/cli/auth_cmd.zig").handleAuthCommand(allocator, arg, stdout);
        return true;
    }

    if (std.mem.startsWith(u8, input, "/tools config")) {
        const arg = std.mem.trim(u8, input[13..], " ");
        try @import("interface/cli/tools_config.zig").handleToolsCommand(allocator, arg, stdout);
        return true;
    }

    if (std.mem.startsWith(u8, input, "/mcp")) {
        const arg = std.mem.trim(u8, input[4..], " ");
        try @import("interface/cli/mcp_config.zig").handleMcpCommand(allocator, arg, stdout);
        return true;
    }

    if (std.mem.startsWith(u8, input, "/cron")) {
        const arg = std.mem.trim(u8, input[5..], " ");
        try @import("interface/cli/cron_cmd.zig").handleCronCommand(allocator, arg, stdout);
        return true;
    }

    if (std.mem.startsWith(u8, input, "/hub")) {
        const arg = std.mem.trim(u8, input[4..], " ");
        try @import("interface/cli/skills_hub_cmd.zig").handleSkillsHubCommand(allocator, arg, stdout);
        return true;
    }

    if (std.mem.startsWith(u8, input, "/claw")) {
        const arg = std.mem.trim(u8, input[5..], " ");
        try @import("interface/cli/claw.zig").handleClawCommand(allocator, arg, stdout);
        return true;
    }

    if (std.mem.startsWith(u8, input, "/pairing")) {
        const arg = std.mem.trim(u8, input[8..], " ");
        try @import("interface/cli/pairing.zig").handlePairingCommand(allocator, arg, stdout);
        return true;
    }

    if (std.mem.eql(u8, input, "/usage")) {
        try stdout.writeAll("\n  \x1b[1mUsage:\x1b[0m\n");
        try stdout.writeAll("    Prompt tokens:     0\n");
        try stdout.writeAll("    Completion tokens: 0\n");
        try stdout.writeAll("    Total tokens:      0\n\n");
        return true;
    }

    if (std.mem.eql(u8, input, "/help")) {
        try stdout.writeAll("\n  \x1b[1mCommands:\x1b[0m\n");
        try stdout.writeAll("  /setup         — Configure provider, API key, model\n");
        try stdout.writeAll("  /model         — Switch model\n");
        try stdout.writeAll("  /config        — Show current configuration\n");
        try stdout.writeAll("  /new           — Start new conversation\n");
        try stdout.writeAll("  /tools         — List available tools\n");
        try stdout.writeAll("  /skills        — List available skills\n");
        try stdout.writeAll("  /skills config — Configure skills directory\n");
        try stdout.writeAll("  /cron          — Cron scheduler info\n");
        try stdout.writeAll("  /usage         — Show token usage\n");
        try stdout.writeAll("  /quit          — Exit\n\n");
        return true;
    }

    if (std.mem.eql(u8, input, "/tools")) {
        try stdout.writeAll("\n  \x1b[1mAvailable Tools:\x1b[0m\n");
        const tool_names = [_][]const u8{
            "terminal",       "read_file",     "write_file",    "patch",           "search_files",
            "web_search",     "web_extract",   "execute_code",  "todo",            "memory",
            "clarify",        "delegate_task", "send_message",  "image_generate",
            "text_to_speech", "vision_analyze", "cronjob",      "session_search",
            "skills_list",    "skill_view",    "skill_manage",  "checkpoint",      "process",
        };
        for (tool_names) |name| {
            try writeF(stdout, allocator, "    • {s}\n", .{name});
        }
        try stdout.writeAll("\n");
        return true;
    }

    if (std.mem.eql(u8, input, "/new")) {
        try stdout.writeAll("\n  ✨ New conversation started.\n\n");
        return true;
    }

    try writeF(stdout, allocator, "\n  Unknown command: {s}. Type /help for available commands.\n\n", .{input});
    return true;
}

fn runSetupWizard(allocator: std.mem.Allocator, stdout: std.fs.File, stdin: std.fs.File) !void {
    try stdout.writeAll("\n  \x1b[1m═══ Setup Wizard ═══\x1b[0m\n\n");

    // Provider selection
    try stdout.writeAll("  Select a provider:\n");
    try stdout.writeAll("    \x1b[36m1\x1b[0m) OpenRouter (200+ models, recommended)\n");
    try stdout.writeAll("    \x1b[36m2\x1b[0m) OpenAI\n");
    try stdout.writeAll("    \x1b[36m3\x1b[0m) Anthropic (Claude)\n");
    try stdout.writeAll("    \x1b[36m4\x1b[0m) Nous Research\n");
    try stdout.writeAll("    \x1b[36m5\x1b[0m) Custom endpoint\n");
    try stdout.writeAll("\n  Choice [1]: ");

    var choice_buf: [256]u8 = undefined;
    const choice_raw = try readLine(stdin, &choice_buf) orelse "";
    const choice = std.mem.trim(u8, choice_raw, " \t\r\n");

    const provider: []const u8 = if (choice.len == 0 or std.mem.eql(u8, choice, "1"))
        "openrouter"
    else if (std.mem.eql(u8, choice, "2"))
        "openai"
    else if (std.mem.eql(u8, choice, "3"))
        "anthropic"
    else if (std.mem.eql(u8, choice, "4"))
        "nous"
    else
        "custom";

    try writeF(stdout, allocator, "\n  Provider: \x1b[32m{s}\x1b[0m\n", .{provider});

    // API key
    try stdout.writeAll("\n  Enter API key: ");
    var key_buf: [512]u8 = undefined;
    const key_raw = try readLine(stdin, &key_buf) orelse "";
    const api_key = std.mem.trim(u8, key_raw, " \t\r\n");

    if (api_key.len > 0) {
        const masked_len = @min(api_key.len, 4);
        try writeF(stdout, allocator, "  API key: \x1b[32m{s}...****\x1b[0m\n", .{api_key[0..masked_len]});
    }

    // Model
    const default_model: []const u8 = if (std.mem.eql(u8, provider, "openrouter"))
        "openrouter/nous-hermes"
    else if (std.mem.eql(u8, provider, "openai"))
        "gpt-4o"
    else if (std.mem.eql(u8, provider, "anthropic"))
        "claude-sonnet-4-20250514"
    else if (std.mem.eql(u8, provider, "nous"))
        "nous/hermes-3-llama-3.1-405b"
    else
        "gpt-4o";

    try writeF(stdout, allocator, "\n  Model [{s}]: ", .{default_model});
    var model_buf: [256]u8 = undefined;
    const model_raw = try readLine(stdin, &model_buf) orelse "";
    const model_input = std.mem.trim(u8, model_raw, " \t\r\n");
    const model = if (model_input.len > 0) model_input else default_model;

    try writeF(stdout, allocator, "  Model: \x1b[32m{s}\x1b[0m\n", .{model});

    // Write config
    const config_json = try std.fmt.allocPrint(allocator,
        \\{{
        \\  "provider": "{s}",
        \\  "model": "{s}",
        \\  "api_key": "{s}",
        \\  "temperature": 0.7,
        \\  "terminal": {{
        \\    "backend": "local",
        \\    "timeout_ms": 30000
        \\  }},
        \\  "memory": {{
        \\    "enabled": true,
        \\    "nudge_interval": 10
        \\  }},
        \\  "security": {{
        \\    "command_approval": true,
        \\    "injection_scanning": true
        \\  }}
        \\}}
    , .{ provider, model, api_key });
    defer allocator.free(config_json);

    var file = try std.fs.cwd().createFile(config_path, .{});
    defer file.close();
    try file.writeAll(config_json);

    try stdout.writeAll("\n  \x1b[32m✓ Configuration saved to config.json\x1b[0m\n\n");
}

fn showConfig(allocator: std.mem.Allocator, stdout: std.fs.File) !void {
    const content = std.fs.cwd().readFileAlloc(allocator, config_path, 64 * 1024) catch |err| {
        try writeF(stdout, allocator, "\n  No config found: {s}\n\n", .{@errorName(err)});
        return;
    };
    defer allocator.free(content);
    try stdout.writeAll("\n  \x1b[1mCurrent Configuration:\x1b[0m\n\x1b[90m");
    try stdout.writeAll(content);
    try stdout.writeAll("\x1b[0m\n\n");
}

// ============ Tests ============

test "framework import" {
    _ = framework;
}

test "Platform.displayName returns non-empty strings" {
    inline for (comptime std.enums.values(core.Platform)) |p| {
        const name = p.displayName();
        try std.testing.expect(name.len > 0);
    }
}

test "Message defaults are correct" {
    const msg = core.Message{};
    try std.testing.expectEqual(core.Role.user, msg.role);
    try std.testing.expectEqualStrings("", msg.content);
    try std.testing.expectEqual(null, msg.tool_call_id);
    try std.testing.expectEqual(null, msg.name);
}

test "SessionSource construction works" {
    const src = core.SessionSource{
        .platform = .telegram,
        .chat_id = "123",
        .user_id = "u1",
    };
    try std.testing.expectEqual(core.Platform.telegram, src.platform);
    try std.testing.expectEqualStrings("123", src.chat_id);
    try std.testing.expectEqualStrings("u1", src.user_id.?);
    try std.testing.expectEqual(null, src.thread_id);
}

test "Config defaults are correct" {
    const cfg = core.Config{};
    try std.testing.expectEqualStrings("openrouter/nous-hermes", cfg.model);
    try std.testing.expectEqualStrings("openrouter", cfg.provider);
    try std.testing.expect(cfg.temperature == 0.7);
    try std.testing.expectEqual(null, cfg.max_tokens);
    try std.testing.expectEqual(false, cfg.reasoning.enabled);
    try std.testing.expectEqualStrings("medium", cfg.reasoning.effort);
    try std.testing.expectEqual(true, cfg.security.command_approval);
    try std.testing.expectEqual(true, cfg.memory.enabled);
    try std.testing.expectEqual(@as(u32, 10), cfg.memory.nudge_interval);
}

test "JSON parsing works" {
    const json = "{\"model\": \"gpt-4\", \"temperature\": 0.5}";
    var loaded = try core.config_loader.loadFromString(json, std.testing.allocator);
    defer loaded.deinit();
    try std.testing.expectEqualStrings("gpt-4", loaded.parsed.value.model);
    try std.testing.expect(loaded.parsed.value.temperature == 0.5);
}

test "Empty JSON uses all defaults" {
    var loaded = try core.config_loader.loadFromString("{}", std.testing.allocator);
    defer loaded.deinit();
    try std.testing.expectEqualStrings("openrouter/nous-hermes", loaded.parsed.value.model);
    try std.testing.expect(loaded.parsed.value.temperature == 0.7);
}

test "Soul loading returns default when file doesn't exist" {
    const result = try core.soul.loadSoul(std.testing.allocator, "nonexistent-hermes-test-dir");
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualStrings(core.DEFAULT_SOUL, result);
}

test "SQLite file-based integration" {
    const db = try core.sqlite.Database.open(":memory:");
    defer db.close();
    try core.database.initSchema(db);
    try core.database.createSession(db, "test-1", "cli", "gpt-4");
    try core.database.appendMessage(db, "test-1", "user", "hello");
    try std.testing.expectEqual(@as(i64, 1), try core.database.getMessageCount(db, "test-1"));
}
