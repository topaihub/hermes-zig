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

const CommandAction = enum { continue_session, new_session, quit };

const banner =
    \\
    \\  _  _ ___ ___ __  __ ___ ___
    \\ | || | __| _ \  \/  | __/ __|
    \\ | __ | _||   / |\/| | _|\__ \
    \\ |_||_|___|_|_\_|  |_|___|___/
    \\       A G E N T  (Zig Edition)
    \\
;

const config_filename = "config.json";

extern "kernel32" fn SetConsoleCP(wCodePageID: std.os.windows.UINT) callconv(.winapi) std.os.windows.BOOL;

/// Enable UTF-8 and ANSI on Windows console
fn initConsole() void {
    if (builtin.os.tag == .windows) {
        const kernel32 = std.os.windows.kernel32;
        _ = SetConsoleCP(65001);
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

fn resolveConfigPathAlloc(allocator: std.mem.Allocator) ![]u8 {
    const exe_config = try exeRelativePathAlloc(allocator, config_filename);
    errdefer allocator.free(exe_config);

    if (pathExists(exe_config)) {
        return exe_config;
    }
    if (pathExists(config_filename)) {
        allocator.free(exe_config);
        return allocator.dupe(u8, config_filename);
    }
    return exe_config;
}

fn configBaseDirAlloc(allocator: std.mem.Allocator, config_path: []const u8) ![]u8 {
    const dir = std.fs.path.dirname(config_path) orelse ".";
    return allocator.dupe(u8, dir);
}

fn resolvePathFromBaseAlloc(allocator: std.mem.Allocator, base_dir: []const u8, maybe_relative_path: []const u8) ![]u8 {
    if (std.fs.path.isAbsolute(maybe_relative_path)) {
        return allocator.dupe(u8, maybe_relative_path);
    }
    return std.fs.path.join(allocator, &.{ base_dir, maybe_relative_path });
}

fn exeRelativePathAlloc(allocator: std.mem.Allocator, filename: []const u8) ![]u8 {
    const exe_path = try std.fs.selfExePathAlloc(allocator);
    defer allocator.free(exe_path);
    const exe_dir = std.fs.path.dirname(exe_path) orelse ".";
    return std.fs.path.join(allocator, &.{ exe_dir, filename });
}

fn pathExists(path: []const u8) bool {
    if (std.fs.path.isAbsolute(path)) {
        std.fs.accessAbsolute(path, .{}) catch return false;
        return true;
    }
    std.fs.cwd().access(path, .{}) catch return false;
    return true;
}

fn createConfigFile(config_path: []const u8) !std.fs.File {
    if (std.fs.path.isAbsolute(config_path)) {
        return std.fs.createFileAbsolute(config_path, .{});
    }
    return std.fs.cwd().createFile(config_path, .{});
}

fn readConfigFileAlloc(allocator: std.mem.Allocator, config_path: []const u8, max_bytes: usize) ![]u8 {
    if (std.fs.path.isAbsolute(config_path)) {
        const file = try std.fs.openFileAbsolute(config_path, .{});
        defer file.close();
        return file.readToEndAlloc(allocator, max_bytes);
    }
    return std.fs.cwd().readFileAlloc(allocator, config_path, max_bytes);
}

fn saveConfigAlloc(allocator: std.mem.Allocator, config_path: []const u8, cfg: core.Config) !void {
    const json = try std.json.Stringify.valueAlloc(allocator, cfg, .{ .whitespace = .indent_2 });
    defer allocator.free(json);
    var file = try createConfigFile(config_path);
    defer file.close();
    try file.writeAll(json);
}

fn isConfiguredModelAllowed(cfg: *const core.Config, target_model: []const u8) bool {
    if (cfg.models.len == 0) return std.mem.eql(u8, cfg.model, target_model);
    for (cfg.models) |model_name| {
        if (std.mem.eql(u8, model_name, target_model)) return true;
    }
    return false;
}

fn switchModel(
    allocator: std.mem.Allocator,
    config_path: []const u8,
    cfg: *core.Config,
    owned_model_override: *?[]u8,
    target_model: []const u8,
) !bool {
    if (!isConfiguredModelAllowed(cfg, target_model)) return false;

    const owned_model = try allocator.dupe(u8, target_model);
    errdefer allocator.free(owned_model);
    if (owned_model_override.*) |previous| allocator.free(previous);
    owned_model_override.* = owned_model;
    cfg.model = owned_model;
    try saveConfigAlloc(allocator, config_path, cfg.*);
    return true;
}

pub fn main() !void {
    initConsole();
    const stdout = std.fs.File.stdout();
    const stdin = std.fs.File.stdin();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    const config_path = try resolveConfigPathAlloc(allocator);
    defer allocator.free(config_path);
    const config_base_dir = try configBaseDirAlloc(allocator, config_path);
    defer allocator.free(config_base_dir);

    try stdout.writeAll("\x1b[36m" ++ banner ++ "\x1b[0m\n");

    // Load .env file if it exists
    var env_map = try core.env_loader.loadEnvFile(allocator, ".env");
    defer core.env_loader.deinitEnvMap(allocator, &env_map);

    const default_config = @embedFile("default_config.json");
    var loaded_cfg: ?core.LoadedConfig = null;
    defer if (loaded_cfg) |*loaded| loaded.deinit();

    // Try to load existing config
    var cfg = blk: {
        loaded_cfg = core.config_loader.loadFromFile(config_path, allocator) catch |err| {
            if (err == error.FileNotFound) {
                // Generate default config.json
                var df = createConfigFile(config_path) catch {
                    break :blk core.Config{};
                };
                defer df.close();
                df.writeAll(default_config) catch {};
                try stdout.writeAll("  Generated default config.json\n");
                try stdout.writeAll("  Starting setup wizard...\n\n");
                try runSetupWizard(allocator, stdout, stdin, config_path);
                break :blk core.Config{};
            }
            try writeF(stdout, allocator, "  Config error: {s}\n", .{@errorName(err)});
            break :blk core.Config{};
        };
        try writeF(stdout, allocator, "  Provider: \x1b[32m{s}\x1b[0m\n", .{loaded_cfg.?.parsed.value.provider});
        try writeF(stdout, allocator, "  Model:    \x1b[32m{s}\x1b[0m\n", .{loaded_cfg.?.parsed.value.model});
        try stdout.writeAll("\n");
        break :blk loaded_cfg.?.parsed.value;
    };
    _ = &cfg;

    var app_ctx = try framework.AppContext.init(allocator, .{
        .log_level = .debug,
        .console_log_style = .pretty,
    });
    defer app_ctx.deinit();

    const original_sink = app_ctx.logger.sink;
    var sink_storage: [3]framework.LogSink = undefined;
    var sink_count: usize = 0;
    sink_storage[sink_count] = original_sink;
    sink_count += 1;

    var trace_file_sink: framework.TraceTextFileSink = undefined;
    var has_trace_file_sink = false;
    defer if (has_trace_file_sink) trace_file_sink.deinit();

    var json_file_sink: framework.RotatingFileSink = undefined;
    var has_json_file_sink = false;
    defer if (has_json_file_sink) json_file_sink.deinit();

    if (usesTextLogFormat(cfg.logging.log_format)) {
        const trace_log_dir = try resolvePathFromBaseAlloc(allocator, config_base_dir, cfg.logging.log_dir);
        defer allocator.free(trace_log_dir);
        const trace_log_path = try std.fs.path.join(allocator, &.{ trace_log_dir, "hermes-trace.log" });
        defer allocator.free(trace_log_path);

        trace_file_sink = try framework.TraceTextFileSink.init(
            allocator,
            trace_log_path,
            cfg.logging.max_file_bytes,
            .{
                .include_observer = false,
                .include_runtime_dispatch = false,
                .include_framework_method_trace = true,
            },
        );
        has_trace_file_sink = true;
        sink_storage[sink_count] = trace_file_sink.asLogSink();
        sink_count += 1;
    }

    if (usesJsonLogFormat(cfg.logging.log_format)) {
        const json_log_dir = try resolvePathFromBaseAlloc(allocator, config_base_dir, cfg.logging.log_dir);
        defer allocator.free(json_log_dir);
        json_file_sink = framework.RotatingFileSink.init(allocator, .{
            .log_dir = json_log_dir,
            .prefix = if (usesTextLogFormat(cfg.logging.log_format)) "hermes-json" else "hermes",
            .max_file_bytes = cfg.logging.max_file_bytes,
            .format = .json,
        });
        has_json_file_sink = true;
        sink_storage[sink_count] = json_file_sink.sink();
        sink_count += 1;
    }

    var file_multi = try framework.MultiSink.init(allocator, sink_storage[0..sink_count]);
    defer file_multi.deinit();
    app_ctx.logger.sink = file_multi.asLogSink();
    defer app_ctx.logger.sink = original_sink;

    var log = app_ctx.logger.subsystem("hermes");
    log.info("hermes agent starting", &.{});

    // Start web config server in background
    var web_server = web_server_mod.WebConfigServer{
        .allocator = allocator,
        .config_path = config_path,
    };
    const web_thread = std.Thread.spawn(.{}, web_server_mod.WebConfigServer.start, .{&web_server}) catch null;

    try stdout.writeAll("  Config UI: \x1b[36mhttp://127.0.0.1:8318\x1b[0m\n\n");

    // Resolve LLM provider
    var native_http = framework.NativeHttpClient.init(null);
    var resolved_provider = try llm.runtime_provider.resolveProvider(allocator, &cfg, native_http.client());
    defer if (resolved_provider) |provider| provider.deinit(allocator);

    var tool_reg = tools.registry.ToolRegistry.init(allocator, &.{});
    defer tool_reg.deinit();

    var skills_runtime = try interface.cli.SkillsRuntime.init(allocator);
    defer skills_runtime.deinit();
    skills_runtime.reload() catch {};
    var session_usage = core.TokenUsage{};
    var owned_model_override: ?[]u8 = null;
    defer if (owned_model_override) |model_name| allocator.free(model_name);

    // Load soul for system prompt
    const hermes_home = try core.soul.getHermesHome(allocator);
    defer allocator.free(hermes_home);

    const soul_text = core.soul.loadSoul(allocator, hermes_home) catch try allocator.dupe(u8, core.DEFAULT_SOUL);
    defer allocator.free(soul_text);

    // Conversation history
    var conversation: std.ArrayList(core.Message) = .{};
    defer {
        if (conversation.items.len > 1) {
            for (conversation.items[1..]) |msg| {
                allocator.free(msg.content);
            }
        }
        conversation.deinit(allocator);
    }
    try conversation.append(allocator, .{ .role = .system, .content = soul_text });

    // Main interactive loop
    try stdout.writeAll("  Type a message to chat, or use commands:\n");
    try stdout.writeAll("  \x1b[90m/setup\x1b[0m  — Configure provider and API key\n");
    try stdout.writeAll("  \x1b[90m/model\x1b[0m  — Switch model\n");
    try stdout.writeAll("  \x1b[90m/config\x1b[0m — Show current config\n");
    try stdout.writeAll("  \x1b[90m/skills\x1b[0m — List or activate installed skills\n");
    if (interface.cli.canUseInteractiveInput(stdin, stdout)) {
        try stdout.writeAll("  Type \x1b[90m/\x1b[0m for command suggestions, \x1b[90mTab\x1b[0m to complete\n");
    }
    try stdout.writeAll("  \x1b[90m/help\x1b[0m   — Show all commands\n");
    try stdout.writeAll("  \x1b[90m/quit\x1b[0m   — Exit\n\n");

    var history = interface.cli.History.init(allocator);
    defer history.deinit();

    var request_seq: u64 = 0;
    while (true) {
        if (!interface.cli.canUseInteractiveInput(stdin, stdout)) {
            try stdout.writeAll("\x1b[36mhermes>\x1b[0m ");
        }

        const raw = try interface.cli.readInputLine(allocator, stdin, stdout, &history) orelse break;
        defer allocator.free(raw);
        const input = std.mem.trim(u8, raw, " \t\r\n");
        if (input.len == 0) continue;

        if (std.mem.startsWith(u8, input, "/")) {
            request_seq += 1;
            const request_id = try std.fmt.allocPrint(allocator, "cli-command-{d}", .{request_seq});
            defer allocator.free(request_id);

            var request_trace = try framework.observability.request_trace.begin(allocator, app_ctx.logger, .cli, request_id, "COMMAND", input, null);
            defer request_trace.deinit();

            const action = handleCommand(
                allocator,
                input,
                stdout,
                stdin,
                config_path,
                &cfg,
                &owned_model_override,
                &skills_runtime,
                &session_usage,
            ) catch |err| {
                framework.observability.request_trace.complete(app_ctx.logger, &request_trace, 500, @errorName(err));
                return err;
            };

            const status_code: u16 = switch (action) {
                .continue_session => 200,
                .new_session => 200,
                .quit => 204,
            };
            framework.observability.request_trace.complete(app_ctx.logger, &request_trace, status_code, null);

            switch (action) {
                .continue_session => {},
                .new_session => {
                    skills_runtime.clearActive();
                    try resetConversation(allocator, &conversation, soul_text);
                },
                .quit => break,
            }
            continue;
        }

        // Chat message
        request_seq += 1;
        const request_id = try std.fmt.allocPrint(allocator, "cli-chat-{d}", .{request_seq});
        defer allocator.free(request_id);

        var request_trace = try framework.observability.request_trace.begin(allocator, app_ctx.logger, .cli, request_id, "CHAT", "/chat", null);
        defer request_trace.deinit();

        if (resolved_provider == null) {
            framework.observability.request_trace.complete(app_ctx.logger, &request_trace, 503, "LLM_NOT_CONFIGURED");
            try stdout.writeAll("\n  \x1b[33m⚡ Agent:\x1b[0m LLM not configured yet. Run \x1b[36m/setup\x1b[0m to configure.\n\n");
            continue;
        }

        try conversation.append(allocator, .{ .role = .user, .content = try allocator.dupe(u8, input) });
        const request_messages = try buildRequestMessages(allocator, &cfg, soul_text, &skills_runtime, conversation.items);
        defer freeRequestMessages(allocator, request_messages);

        const llm_client = resolved_provider.?.asLlmClient();
        var agent_loop = agent.AgentLoop{
            .allocator = allocator,
            .llm = llm_client,
            .tools = &tool_reg,
            .config = &cfg,
            .logger = app_ctx.logger,
        };

        var result = agent_loop.run(request_messages, &.{}) catch |err| {
            framework.observability.request_trace.complete(app_ctx.logger, &request_trace, 500, @errorName(err));
            try writeF(stdout, allocator, "\n  \x1b[31mError:\x1b[0m {s}\n\n", .{@errorName(err)});
            continue;
        };
        defer result.deinit(allocator);

        framework.observability.request_trace.complete(app_ctx.logger, &request_trace, 200, null);
        session_usage.prompt_tokens += result.usage.prompt_tokens;
        session_usage.completion_tokens += result.usage.completion_tokens;
        session_usage.total_tokens += result.usage.total_tokens;

        try stdout.writeAll("\n  \x1b[33m⚡ Agent:\x1b[0m ");
        try stdout.writeAll(result.content);
        try stdout.writeAll("\n\n");

        try conversation.append(allocator, .{ .role = .assistant, .content = try allocator.dupe(u8, result.content) });
    }

    web_server.stop();
    if (web_thread) |wt| wt.join();

    try stdout.writeAll("\n  Goodbye! 👋\n");
}

fn handleCommand(
    allocator: std.mem.Allocator,
    input: []const u8,
    stdout: std.fs.File,
    stdin: std.fs.File,
    config_path: []const u8,
    cfg: *core.Config,
    owned_model_override: *?[]u8,
    skills_runtime: *interface.cli.SkillsRuntime,
    session_usage: *core.TokenUsage,
) !CommandAction {
    const parsed = interface.cli.parseCommand(input) orelse return .continue_session;

    switch (parsed.spec.id) {
        .quit => return .quit,
        .setup => {
            try runSetupWizard(allocator, stdout, stdin, config_path);
            return .continue_session;
        },
        .config => {
            try showConfig(allocator, stdout, config_path);
            return .continue_session;
        },
        .model => {
            if (parsed.arg == null) {
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
                return .continue_session;
            }

            const target_model = parsed.arg.?;
            if (!(try switchModel(allocator, config_path, cfg, owned_model_override, target_model))) {
                try writeF(stdout, allocator, "\n  Invalid model: {s}\n", .{target_model});
                if (cfg.models.len > 0) {
                    try stdout.writeAll("  Choose one of the configured models:\n");
                    for (cfg.models) |m| {
                        try writeF(stdout, allocator, "    • {s}\n", .{m});
                    }
                }
                try stdout.writeAll("\n");
                return .continue_session;
            }
            try writeF(stdout, allocator, "\n  Model switched to: \x1b[32m{s}\x1b[0m\n\n", .{target_model});
            return .continue_session;
        },
        .skills => {
            try renderSkillsList(allocator, stdout, skills_runtime);
            return .continue_session;
        },
        .skills_config => {
            try writeF(stdout, allocator, "\n  \x1b[1mSkills Directory:\x1b[0m\n    {s}\n\n", .{skills_runtime.skills_dir});
            return .continue_session;
        },
        .skills_view => {
            const name = parsed.arg orelse {
                try stdout.writeAll("\n  Usage: /skills view <name>\n\n");
                return .continue_session;
            };
            try renderSkillView(allocator, stdout, skills_runtime, name);
            return .continue_session;
        },
        .skills_use => {
            const name = parsed.arg orelse {
                try stdout.writeAll("\n  Usage: /skills use <name>\n\n");
                return .continue_session;
            };
            try activateSkill(allocator, stdout, skills_runtime, name);
            return .continue_session;
        },
        .skills_clear => {
            skills_runtime.clearActive();
            try stdout.writeAll("\n  Cleared active skill for this session.\n\n");
            return .continue_session;
        },
        .usage => {
            try stdout.writeAll("\n  \x1b[1mUsage:\x1b[0m\n");
            try writeF(stdout, allocator, "    Prompt tokens:     {d}\n", .{session_usage.prompt_tokens});
            try writeF(stdout, allocator, "    Completion tokens: {d}\n", .{session_usage.completion_tokens});
            try writeF(stdout, allocator, "    Total tokens:      {d}\n\n", .{session_usage.total_tokens});
            return .continue_session;
        },
        .help => {
            var buf: [8192]u8 = undefined;
            var writer = stdout.writer(&buf);
            try interface.cli.commands.renderHelp(&writer.interface);
            try writer.interface.flush();
            return .continue_session;
        },
        .tools => {
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
            return .continue_session;
        },
        .new_session => {
            try stdout.writeAll("\n  ✨ New conversation started.\n\n");
            return .new_session;
        },
        .unknown => {
            try writeF(stdout, allocator, "\n  Unknown command: {s}. Type /help for available commands.\n\n", .{input});
            return .continue_session;
        },
    }
}

fn resetConversation(allocator: std.mem.Allocator, conversation: *std.ArrayList(core.Message), soul_text: []const u8) !void {
    if (conversation.items.len > 1) {
        for (conversation.items[1..]) |msg| {
            allocator.free(msg.content);
        }
    }
    try conversation.resize(allocator, 1);
    conversation.items[0] = .{ .role = .system, .content = soul_text };
}

fn buildRequestMessages(
    allocator: std.mem.Allocator,
    cfg: *const core.Config,
    soul_text: []const u8,
    skills_runtime: *const interface.cli.SkillsRuntime,
    conversation: []const core.Message,
) ![]core.Message {
    const prompt = try agent.prompt_builder.buildSystemPrompt(
        allocator,
        cfg,
        soul_text,
        if (skills_runtime.active) |*skill| skill else null,
    );
    errdefer allocator.free(prompt);

    var messages = try allocator.alloc(core.Message, conversation.len);
    messages[0] = .{ .role = .system, .content = prompt };
    for (conversation[1..], 1..) |msg, index| {
        messages[index] = msg;
    }
    return messages;
}

fn freeRequestMessages(allocator: std.mem.Allocator, messages: []core.Message) void {
    if (messages.len > 0) allocator.free(messages[0].content);
    allocator.free(messages);
}

fn renderSkillsList(allocator: std.mem.Allocator, stdout: std.fs.File, skills_runtime: *interface.cli.SkillsRuntime) !void {
    try skills_runtime.reload();
    try stdout.writeAll("\n  \x1b[1mSkills:\x1b[0m\n");
    if (!skills_runtime.hasInstalledSkills()) {
        try writeF(stdout, allocator, "    No skills found in {s}\n\n", .{skills_runtime.skills_dir});
        return;
    }

    for (skills_runtime.installed) |skill| {
        const active_marker = if (skills_runtime.activeName()) |active_name|
            if (std.mem.eql(u8, active_name, skill.name)) " (active)" else ""
        else
            "";
        try writeF(stdout, allocator, "    • {s}{s}\n", .{ skill.name, active_marker });
        if (skill.description.len > 0) {
            try writeF(stdout, allocator, "      {s}\n", .{skill.description});
        }
    }
    try stdout.writeAll("\n");
}

fn renderSkillView(
    allocator: std.mem.Allocator,
    stdout: std.fs.File,
    skills_runtime: *interface.cli.SkillsRuntime,
    name: []const u8,
) !void {
    try skills_runtime.reload();
    const skill = skills_runtime.findInstalled(name) orelse {
        try writeF(stdout, allocator, "\n  Skill not found: {s}\n\n", .{name});
        return;
    };

    try writeF(stdout, allocator, "\n  \x1b[1mSkill:\x1b[0m {s}\n", .{skill.name});
    if (skill.description.len > 0) {
        try writeF(stdout, allocator, "  \x1b[1mDescription:\x1b[0m {s}\n", .{skill.description});
    }
    try stdout.writeAll("\n");
    try stdout.writeAll(skill.body);
    try stdout.writeAll("\n\n");
}

fn activateSkill(
    allocator: std.mem.Allocator,
    stdout: std.fs.File,
    skills_runtime: *interface.cli.SkillsRuntime,
    name: []const u8,
) !void {
    try skills_runtime.reload();
    if (!(try skills_runtime.activate(name))) {
        try writeF(stdout, allocator, "\n  Skill not found: {s}\n\n", .{name});
        return;
    }
    try writeF(stdout, allocator, "\n  Activated skill: {s}\n\n", .{skills_runtime.active.?.name});
}

fn runSetupWizard(allocator: std.mem.Allocator, stdout: std.fs.File, stdin: std.fs.File, config_path: []const u8) !void {
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

    const api_base_url = if (std.mem.eql(u8, provider, "custom")) blk: {
        while (true) {
            try stdout.writeAll("\n  API base URL: ");
            var url_buf: [512]u8 = undefined;
            const url_raw = try readLine(stdin, &url_buf) orelse "";
            const url = std.mem.trim(u8, url_raw, " \t\r\n");
            if (url.len > 0) {
                try writeF(stdout, allocator, "  API base URL: \x1b[32m{s}\x1b[0m\n", .{url});
                break :blk url;
            }
            try stdout.writeAll("  API base URL is required for custom provider.\n");
        }
    } else "";

    const wire_api = if (std.mem.eql(u8, provider, "custom") or std.mem.eql(u8, provider, "openai")) blk: {
        try stdout.writeAll("\n  Select API protocol:\n");
        try stdout.writeAll("    \x1b[36m1\x1b[0m) Chat Completions\n");
        try stdout.writeAll("    \x1b[36m2\x1b[0m) Responses\n");
        try stdout.writeAll("\n  Choice [1]: ");

        var wire_buf: [64]u8 = undefined;
        const wire_raw = try readLine(stdin, &wire_buf) orelse "";
        const wire_choice = std.mem.trim(u8, wire_raw, " \t\r\n");
        const selected = if (std.mem.eql(u8, wire_choice, "2")) "responses" else "chat_completions";
        try writeF(stdout, allocator, "  API protocol: \x1b[32m{s}\x1b[0m\n", .{selected});
        break :blk selected;
    } else "chat_completions";

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
    const config_json = try buildSetupConfigJson(allocator, provider, model, api_key, api_base_url, wire_api);
    defer allocator.free(config_json);

    var file = try createConfigFile(config_path);
    defer file.close();
    try file.writeAll(config_json);

    try stdout.writeAll("\n  \x1b[32m✓ Configuration saved to config.json\x1b[0m\n\n");
}

fn buildSetupConfigJson(
    allocator: std.mem.Allocator,
    provider: []const u8,
    model: []const u8,
    api_key: []const u8,
    api_base_url: []const u8,
    wire_api: []const u8,
) ![]u8 {
    return std.fmt.allocPrint(allocator,
        \\{{
        \\  "provider": "{s}",
        \\  "model": "{s}",
        \\  "api_key": "{s}",
        \\  "api_base_url": "{s}",
        \\  "wire_api": "{s}",
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
    , .{ provider, model, api_key, api_base_url, wire_api });
}

fn usesTextLogFormat(log_format: []const u8) bool {
    return std.mem.eql(u8, log_format, "text") or std.mem.eql(u8, log_format, "both") or log_format.len == 0;
}

fn usesJsonLogFormat(log_format: []const u8) bool {
    return std.mem.eql(u8, log_format, "json") or std.mem.eql(u8, log_format, "both");
}

fn showConfig(allocator: std.mem.Allocator, stdout: std.fs.File, config_path: []const u8) !void {
    const content = readConfigFileAlloc(allocator, config_path, 64 * 1024) catch |err| {
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

test "cli command and skill modules are included in root test suite" {
    _ = @import("interface/cli/commands.zig");
    _ = @import("interface/cli/history.zig");
    _ = @import("interface/cli/input_controller.zig");
    _ = @import("interface/cli/skills_runtime.zig");
    _ = @import("agent/prompt_builder.zig");
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
    try std.testing.expectEqualStrings("chat_completions", cfg.wire_api);
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

test "setup config json includes api_base_url" {
    const json = try buildSetupConfigJson(
        std.testing.allocator,
        "custom",
        "gpt-5.4",
        "sk-test",
        "https://api.example.com/v1",
        "responses",
    );
    defer std.testing.allocator.free(json);

    var loaded = try core.config_loader.loadFromString(json, std.testing.allocator);
    defer loaded.deinit();

    try std.testing.expectEqualStrings("custom", loaded.parsed.value.provider);
    try std.testing.expectEqualStrings("https://api.example.com/v1", loaded.parsed.value.api_base_url);
    try std.testing.expectEqualStrings("responses", loaded.parsed.value.wire_api);
}

test "isConfiguredModelAllowed matches configured list" {
    const cfg = core.Config{
        .model = "gpt-5.4",
        .models = &.{ "gpt-5.4", "gpt-4.1" },
    };
    try std.testing.expect(isConfiguredModelAllowed(&cfg, "gpt-5.4"));
    try std.testing.expect(!isConfiguredModelAllowed(&cfg, "claude-sonnet"));
}

test "saveConfigAlloc writes configured model list" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const tmp_dir_rel = try std.fs.path.join(std.testing.allocator, &.{ ".zig-cache", "tmp", tmp.sub_path[0..] });
    defer std.testing.allocator.free(tmp_dir_rel);
    const tmp_dir_abs = try std.fs.cwd().realpathAlloc(std.testing.allocator, tmp_dir_rel);
    defer std.testing.allocator.free(tmp_dir_abs);
    const config_path = try std.fs.path.join(std.testing.allocator, &.{ tmp_dir_abs, "config.json" });
    defer std.testing.allocator.free(config_path);

    const cfg = core.Config{
        .provider = "custom",
        .model = "gpt-5.4",
        .models = &.{ "gpt-5.4" },
        .api_base_url = "https://example.com",
        .wire_api = "responses",
    };
    try saveConfigAlloc(std.testing.allocator, config_path, cfg);

    const file = try std.fs.openFileAbsolute(config_path, .{});
    defer file.close();
    const content = try file.readToEndAlloc(std.testing.allocator, 4096);
    defer std.testing.allocator.free(content);
    try std.testing.expect(std.mem.indexOf(u8, content, "\"models\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, content, "\"gpt-5.4\"") != null);
}

test "switchModel updates in-memory config and writes file" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const tmp_dir_rel = try std.fs.path.join(std.testing.allocator, &.{ ".zig-cache", "tmp", tmp.sub_path[0..] });
    defer std.testing.allocator.free(tmp_dir_rel);
    const tmp_dir_abs = try std.fs.cwd().realpathAlloc(std.testing.allocator, tmp_dir_rel);
    defer std.testing.allocator.free(tmp_dir_abs);
    const config_path = try std.fs.path.join(std.testing.allocator, &.{ tmp_dir_abs, "config.json" });
    defer std.testing.allocator.free(config_path);

    var cfg = core.Config{
        .provider = "custom",
        .model = "gpt-5.4",
        .models = &.{ "gpt-5.4", "gpt-4.1" },
        .api_base_url = "https://example.com",
        .wire_api = "responses",
    };
    var owned_model_override: ?[]u8 = null;
    defer if (owned_model_override) |m| std.testing.allocator.free(m);

    try std.testing.expect(try switchModel(std.testing.allocator, config_path, &cfg, &owned_model_override, "gpt-4.1"));
    try std.testing.expectEqualStrings("gpt-4.1", cfg.model);

    const file = try std.fs.openFileAbsolute(config_path, .{});
    defer file.close();
    const content = try file.readToEndAlloc(std.testing.allocator, 4096);
    defer std.testing.allocator.free(content);
    try std.testing.expect(std.mem.indexOf(u8, content, "\"model\": \"gpt-4.1\"") != null);
}

test "switchModel rejects invalid model without mutating config" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const tmp_dir_rel = try std.fs.path.join(std.testing.allocator, &.{ ".zig-cache", "tmp", tmp.sub_path[0..] });
    defer std.testing.allocator.free(tmp_dir_rel);
    const tmp_dir_abs = try std.fs.cwd().realpathAlloc(std.testing.allocator, tmp_dir_rel);
    defer std.testing.allocator.free(tmp_dir_abs);
    const config_path = try std.fs.path.join(std.testing.allocator, &.{ tmp_dir_abs, "config.json" });
    defer std.testing.allocator.free(config_path);

    var cfg = core.Config{
        .model = "gpt-5.4",
        .models = &.{ "gpt-5.4" },
    };
    var owned_model_override: ?[]u8 = null;
    defer if (owned_model_override) |m| std.testing.allocator.free(m);

    try std.testing.expect(!(try switchModel(std.testing.allocator, config_path, &cfg, &owned_model_override, "gpt-4.1")));
    try std.testing.expectEqualStrings("gpt-5.4", cfg.model);
    try std.testing.expect(owned_model_override == null);
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
