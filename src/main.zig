const std = @import("std");
const framework = @import("framework");
pub const core = @import("core/root.zig");
pub const llm = @import("llm/root.zig");
pub const tools = @import("tools/root.zig");
pub const agent = @import("agent/root.zig");
pub const interface = @import("interface/root.zig");
pub const intelligence = @import("intelligence/root.zig");
pub const security = @import("security/root.zig");
pub const web_server_mod = @import("web_server.zig");

const banner =
    \\
    \\  ╦ ╦┌─┐┬─┐┌┬┐┌─┐┌─┐  ╔═╗┌─┐┌─┐┌┐┌┌┬┐
    \\  ╠═╣├┤ ├┬┘│││├┤ └─┐  ╠═╣│ ┬├┤ │││ │
    \\  ╩ ╩└─┘┴└─┴ ┴└─┘└─┘  ╩ ╩└─┘└─┘┘└┘ ┴
    \\  ── Zig Edition ──
    \\
;

const config_path = "config.json";

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
    const stdout = std.fs.File.stdout();
    const stdin = std.fs.File.stdin();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try stdout.writeAll("\x1b[36m" ++ banner ++ "\x1b[0m\n");

    // Try to load existing config
    var cfg = blk: {
        var loaded = core.config_loader.loadFromFile(config_path, allocator) catch |err| {
            if (err == error.FileNotFound) {
                try stdout.writeAll("  No config.json found. Starting setup wizard...\n\n");
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

        // Chat message — would go to AgentLoop
        try stdout.writeAll("\n  \x1b[33m⚡ Agent:\x1b[0m LLM not configured yet. Run \x1b[36m/setup\x1b[0m to configure.\n\n");
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

    if (std.mem.eql(u8, input, "/help")) {
        try stdout.writeAll("\n  \x1b[1mCommands:\x1b[0m\n");
        try stdout.writeAll("  /setup     — Configure provider, API key, model\n");
        try stdout.writeAll("  /model     — Switch model\n");
        try stdout.writeAll("  /config    — Show current configuration\n");
        try stdout.writeAll("  /new       — Start new conversation\n");
        try stdout.writeAll("  /tools     — List available tools\n");
        try stdout.writeAll("  /skills    — List available skills\n");
        try stdout.writeAll("  /usage     — Show token usage\n");
        try stdout.writeAll("  /quit      — Exit\n\n");
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

test "Soul loading returns null when file doesn't exist" {
    const result = try core.soul.loadSoul(std.testing.allocator, "nonexistent-hermes-test-dir");
    try std.testing.expectEqual(null, result);
}

test "SQLite file-based integration" {
    const db = try core.sqlite.Database.open(":memory:");
    defer db.close();
    try core.database.initSchema(db);
    try core.database.createSession(db, "test-1", "cli", "gpt-4");
    try core.database.appendMessage(db, "test-1", "user", "hello");
    try std.testing.expectEqual(@as(i64, 1), try core.database.getMessageCount(db, "test-1"));
}
