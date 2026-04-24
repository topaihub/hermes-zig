const std = @import("std");
const builtin = @import("builtin");
const framework = @import("framework");
const compat = @import("compat.zig");
const compat_fs = @import("compat/fs.zig");
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
extern "kernel32" fn SetConsoleOutputCP(wCodePageID: std.os.windows.UINT) callconv(.winapi) std.os.windows.BOOL;
extern "kernel32" fn GetStdHandle(nStdHandle: std.os.windows.DWORD) callconv(.winapi) ?std.os.windows.HANDLE;
extern "kernel32" fn GetConsoleMode(hConsoleHandle: std.os.windows.HANDLE, lpMode: *std.os.windows.DWORD) callconv(.winapi) std.os.windows.BOOL;
extern "kernel32" fn SetConsoleMode(hConsoleHandle: std.os.windows.HANDLE, dwMode: std.os.windows.DWORD) callconv(.winapi) std.os.windows.BOOL;

/// Enable UTF-8 and ANSI on Windows console
fn initConsole() void {
    if (builtin.os.tag == .windows) {
        _ = SetConsoleCP(65001);
        _ = SetConsoleOutputCP(65001);
        const STD_OUTPUT_HANDLE: std.os.windows.DWORD = @bitCast(@as(i32, -11));
        const handle = GetStdHandle(STD_OUTPUT_HANDLE);
        if (handle) |h| {
            if (h != std.os.windows.INVALID_HANDLE_VALUE) {
                var mode: std.os.windows.DWORD = 0;
                if (GetConsoleMode(h, &mode) != .FALSE) {
                    _ = SetConsoleMode(h, mode | 0x0004);
                }
            }
        }
    }
}

fn readLine(stdin: std.Io.File, buf: []u8) !?[]const u8 {
    var io = std.Io.Threaded.init(std.heap.page_allocator, .{});
    defer io.deinit();
    
    // Use readStreaming for simple byte-by-byte read
    var i: usize = 0;
    while (i < buf.len) {
        var byte_buf: [1]u8 = undefined;
        const buffers = [_][]u8{&byte_buf};
        const n = stdin.readStreaming(io.io(), &buffers) catch return null;
        if (n == 0) return if (i > 0) buf[0..i] else null;
        buf[i] = byte_buf[0];
        if (buf[i] == '\n') return buf[0..i];
        i += 1;
    }
    return buf[0..i];
}

fn writeF(stdout: std.Io.File, allocator: std.mem.Allocator, comptime fmt: []const u8, args: anytype) !void {
    const msg = try std.fmt.allocPrint(allocator, fmt, args);
    defer allocator.free(msg);
    var io = std.Io.Threaded.init(allocator, .{});
    defer io.deinit();
    var buf: [4096]u8 = undefined;
    var writer = stdout.writer(io.io(), &buf);
    try writer.interface.writeAll(msg);
}

fn writeStr(stdout: std.Io.File, allocator: std.mem.Allocator, msg: []const u8) !void {
    var io = std.Io.Threaded.init(allocator, .{});
    defer io.deinit();
    var buf: [4096]u8 = undefined;
    var writer = stdout.writer(io.io(), &buf);
    try writer.interface.writeAll(msg);
}

fn renderChatErrorMessage(allocator: std.mem.Allocator, err_name: []const u8) ![]u8 {
    if (std.mem.eql(u8, err_name, "ResponsesEmptyOutput")) {
        return std.fmt.allocPrint(
            allocator,
            "Provider returned no usable output for the selected protocol. The relay may not fully support this model or wire format.",
            .{},
        );
    }
    if (std.mem.eql(u8, err_name, "CertificateBundleLoadFailure")) {
        return std.fmt.allocPrint(
            allocator,
            "TLS certificate bundle could not be loaded on this machine. The request could not be sent to the provider.",
            .{},
        );
    }
    return allocator.dupe(u8, err_name);
}

fn resolveConfigPathAlloc(allocator: std.mem.Allocator) ![]u8 {
    const exe_config = try exeRelativePathAlloc(allocator, config_filename);
    defer allocator.free(exe_config);
    return chooseConfigPathAlloc(allocator, exe_config, config_filename);
}

fn chooseConfigPathAlloc(
    allocator: std.mem.Allocator,
    preferred_path: []const u8,
    fallback_path: []const u8,
) ![]u8 {
    if (pathExists(preferred_path)) return allocator.dupe(u8, preferred_path);
    if (pathExists(fallback_path)) return allocator.dupe(u8, fallback_path);
    return allocator.dupe(u8, preferred_path);
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
    var io = std.Io.Threaded.init(allocator, .{});
    defer io.deinit();
    const exe_path = try std.process.executablePathAlloc(io.io(), allocator);
    defer allocator.free(exe_path);
    const exe_dir = std.fs.path.dirname(exe_path) orelse ".";
    return std.fs.path.join(allocator, &.{ exe_dir, filename });
}

fn pathExists(path: []const u8) bool {
    var io = std.Io.Threaded.init(std.heap.page_allocator, .{});
    defer io.deinit();
    
    if (std.fs.path.isAbsolute(path)) {
        const file = std.Io.Dir.openFileAbsolute(io.io(), path, .{}) catch return false;
        file.close(io.io());
        return true;
    }
    const cwd = std.Io.Dir.cwd();
    const file = std.Io.Dir.openFile(cwd, io.io(), path, .{}) catch return false;
    file.close(io.io());
    return true;
}

fn createConfigFile(config_path: []const u8, io: std.Io) !std.Io.File {
    if (std.fs.path.isAbsolute(config_path)) {
        return std.Io.Dir.createFileAbsolute(io, config_path, .{});
    }
    const cwd = std.Io.Dir.cwd();
    return cwd.createFile(io, config_path, .{});
}

fn readConfigFileAlloc(allocator: std.mem.Allocator, config_path: []const u8, max_bytes: usize) ![]u8 {
    var io_threaded: std.Io.Threaded = .init_single_threaded;
    const io_instance = io_threaded.io();
    
    if (std.fs.path.isAbsolute(config_path)) {
        const file = try std.Io.Dir.openFileAbsolute(io_instance, config_path, .{});
        defer file.close(io_instance);
        var stream_buf: [4096]u8 = undefined;
        var reader = file.readerStreaming(io_instance, &stream_buf);
        return try reader.interface.allocRemaining(allocator, .limited(max_bytes));
    }
    return std.Io.Dir.cwd().readFileAlloc(io_instance, config_path, allocator, @enumFromInt(max_bytes));
}

fn saveConfigAlloc(allocator: std.mem.Allocator, config_path: []const u8, cfg: core.Config) !void {
    const json = try std.json.Stringify.valueAlloc(allocator, cfg, .{ .whitespace = .indent_2 });
    defer allocator.free(json);
    var io = std.Io.Threaded.init(allocator, .{});
    defer io.deinit();
    var file = try createConfigFile(config_path, io.io());
    defer file.close(io.io());
    
    var write_buf: [4096]u8 = undefined;
    var writer = file.writer(io.io(), &write_buf);
    try writer.interface.writeAll(json);
    try writer.interface.flush();
}

fn clearLoadedConfig(loaded_cfg: *?core.LoadedConfig) void {
    if (loaded_cfg.*) |*loaded| {
        loaded.deinit();
        loaded_cfg.* = null;
    }
}

fn clearResolvedProvider(allocator: std.mem.Allocator, resolved_provider: *?llm.ResolvedProvider) void {
    if (resolved_provider.*) |provider| {
        provider.deinit(allocator);
        resolved_provider.* = null;
    }
}

fn clearModelOverride(allocator: std.mem.Allocator, owned_model_override: *?[]u8) void {
    if (owned_model_override.*) |model_name| {
        allocator.free(model_name);
        owned_model_override.* = null;
    }
}

const RuntimeReloadState = struct {
    loaded_cfg: core.LoadedConfig,
    resolved_provider: ?llm.ResolvedProvider,
    tools_runtime: interface.cli.ToolsRuntime,

    fn deinit(self: *RuntimeReloadState, allocator: std.mem.Allocator) void {
        self.tools_runtime.deinit();
        clearResolvedProvider(allocator, &self.resolved_provider);
        self.loaded_cfg.deinit();
    }
};

fn loadRuntimeState(
    allocator: std.mem.Allocator,
    config_path: []const u8,
    http: framework.HttpClient,
) !RuntimeReloadState {
    var new_loaded_cfg = try core.config_loader.loadFromFile(config_path, allocator);
    errdefer new_loaded_cfg.deinit();

    const new_cfg = new_loaded_cfg.parsed.value;
    var new_resolved_provider = try llm.runtime_provider.resolveProvider(allocator, &new_cfg, http);
    errdefer clearResolvedProvider(allocator, &new_resolved_provider);

    var new_tools_runtime = try interface.cli.ToolsRuntime.init(allocator, &new_cfg);
    errdefer new_tools_runtime.deinit();

    return .{
        .loaded_cfg = new_loaded_cfg,
        .resolved_provider = new_resolved_provider,
        .tools_runtime = new_tools_runtime,
    };
}

fn reloadRuntimeState(
    allocator: std.mem.Allocator,
    config_path: []const u8,
    cfg: *core.Config,
    loaded_cfg: *?core.LoadedConfig,
    resolved_provider: *?llm.ResolvedProvider,
    tools_runtime: *interface.cli.ToolsRuntime,
    owned_model_override: *?[]u8,
    http: framework.HttpClient,
) !void {
    const new_state = try loadRuntimeState(allocator, config_path, http);

    const old_loaded_cfg = loaded_cfg.*;
    const old_resolved_provider = resolved_provider.*;
    const old_tools_runtime = tools_runtime.*;

    loaded_cfg.* = new_state.loaded_cfg;
    resolved_provider.* = new_state.resolved_provider;
    tools_runtime.* = new_state.tools_runtime;
    cfg.* = loaded_cfg.*.?.parsed.value;

    clearModelOverride(allocator, owned_model_override);
    if (old_loaded_cfg) |loaded| {
        var loaded_mut = loaded;
        loaded_mut.deinit();
    }
    if (old_resolved_provider) |provider| provider.deinit(allocator);
    var old_tools_runtime_mut = old_tools_runtime;
    old_tools_runtime_mut.deinit();
}

fn printLoadedConfigSummary(allocator: std.mem.Allocator, stdout: std.Io.File, cfg: *const core.Config) !void {
    try writeF(stdout, allocator, "  Provider: \x1b[32m{s}\x1b[0m\n", .{cfg.provider});
    try writeF(stdout, allocator, "  Model:    \x1b[32m{s}\x1b[0m\n", .{cfg.model});
    var io = std.Io.Threaded.init(allocator, .{});
    defer io.deinit();
    var buf: [4096]u8 = undefined;
    var writer = stdout.writer(io.io(), &buf);
    try writer.interface.writeAll("\n");
}

fn ensureUtf8BomFile(path: []const u8) !void {
    const parent = std.fs.path.dirname(path);
    if (parent) |dir_path| {
        var io_threaded = std.Io.Threaded.init(std.heap.page_allocator, .{});
        const io_instance = io_threaded.io();
        const cwd = std.Io.Dir.cwd();
        try std.Io.Dir.createDirPath(cwd, io_instance, dir_path);
    }

    const file = blk: {
        if (std.fs.path.isAbsolute(path)) {
            var io_threaded = std.Io.Threaded.init(std.heap.page_allocator, .{});
            const io_instance = io_threaded.io();
            break :blk try std.Io.Dir.openFileAbsolute(io_instance, path, .{ .mode = .read_write });
        } else {
            const cwd = std.Io.Dir.cwd();
            var io_threaded = std.Io.Threaded.init(std.heap.page_allocator, .{});
            const io_instance = io_threaded.io();
            break :blk try cwd.createFile(io_instance, path, .{});
        }
    };
    var io_threaded = std.Io.Threaded.init(std.heap.page_allocator, .{});
    const io_instance = io_threaded.io();
    defer file.close(io_instance);

    const stat = try file.stat(io_instance);
    if (stat.size == 0) {
        var buffer: [4096]u8 = undefined;
        var writer = file.writer(io_instance, &buffer);
        try writer.interface.writeAll("\xEF\xBB\xBF");
        try writer.interface.flush();
    }
}

fn isConfiguredModelAllowed(cfg: *const core.Config, target_model: []const u8) bool {
    if (cfg.models.len == 0) return std.mem.eql(u8, cfg.model, target_model);
    for (cfg.models) |model_name| {
        if (std.mem.eql(u8, model_name, target_model)) return true;
    }
    return false;
}

fn findCurrentModelIndex(cfg: *const core.Config) usize {
    for (cfg.models, 0..) |model_name, index| {
        if (std.mem.eql(u8, model_name, cfg.model)) return index;
    }
    return 0;
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
    
    var io = std.Io.Threaded.init(std.heap.page_allocator, .{});
    defer io.deinit();
    
    const stdout = std.Io.File.stdout();
    const stdin = std.Io.File.stdin();

    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    const config_path = try resolveConfigPathAlloc(allocator);
    defer allocator.free(config_path);
    const config_base_dir = try configBaseDirAlloc(allocator, config_path);
    defer allocator.free(config_base_dir);

    var write_buf: [1024]u8 = undefined;
    var writer = stdout.writer(io.io(), &write_buf);
    try writer.interface.writeAll("\x1b[36m" ++ banner ++ "\x1b[0m\n");

    // Load .env file if it exists
    var env_map = try core.env_loader.loadEnvFile(allocator, ".env");
    defer core.env_loader.freeEnvMap(&env_map);

    const default_config = @embedFile("default_config.json");
    var loaded_cfg: ?core.LoadedConfig = null;
    defer clearLoadedConfig(&loaded_cfg);

    var cfg = core.Config{};
    var tools_runtime = try interface.cli.ToolsRuntime.init(allocator, &cfg);
    defer tools_runtime.deinit();

    var io_threaded: std.Io.Threaded = .init_single_threaded;
    const io_instance = io_threaded.io();

    var native_http = framework.NativeHttpClient.init(null, io_instance);
    var resolved_provider: ?llm.ResolvedProvider = null;
    defer clearResolvedProvider(allocator, &resolved_provider);

    var owned_model_override: ?[]u8 = null;
    defer clearModelOverride(allocator, &owned_model_override);

    // Try to load existing config
    if (pathExists(config_path)) {
        reloadRuntimeState(
            allocator,
            config_path,
            &cfg,
            &loaded_cfg,
            &resolved_provider,
            &tools_runtime,
            &owned_model_override,
            native_http.client(),
        ) catch |err| {
            try writeF(stdout, allocator, "  Config error: {s}\n", .{@errorName(err)});
        };
        if (loaded_cfg != null) {
            try printLoadedConfigSummary(allocator, stdout, &cfg);
        }
    } else {
        // Generate default config.json
        var df = createConfigFile(config_path, allocator) catch null;
        if (df) |*file| {
            defer file.close(io.io());
            var file_write_buf: [4096]u8 = undefined;
            var file_writer = file.writer(io.io(), &file_write_buf);
            file_writer.interface.writeAll(default_config) catch {};
            try writer.interface.writeAll("  Generated default config.json\n");
            try writer.interface.writeAll("  Starting setup wizard...\n\n");
            try runSetupWizard(allocator, stdout, stdin, config_path);
            try reloadRuntimeState(
                allocator,
                config_path,
                &cfg,
                &loaded_cfg,
                &resolved_provider,
                &tools_runtime,
                &owned_model_override,
                native_http.client(),
            );
            try printLoadedConfigSummary(allocator, stdout, &cfg);
        }
    }

    var app_ctx = try framework.AppContext.init(allocator, io_instance, .{
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
        try ensureUtf8BomFile(trace_log_path);
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

    try writeStr(stdout, allocator, "  Config UI: \x1b[36mhttp://127.0.0.1:8318\x1b[0m\n\n");

    var skills_runtime = try interface.cli.SkillsRuntime.init(allocator);
    defer skills_runtime.deinit();
    skills_runtime.reload() catch {};
    var session_usage = core.TokenUsage{};

    // Load soul for system prompt
    const hermes_home = try core.soul.getHermesHome(allocator);
    defer allocator.free(hermes_home);

    const soul_text = core.soul.loadSoul(allocator, hermes_home) catch try allocator.dupe(u8, core.DEFAULT_SOUL);
    defer allocator.free(soul_text);

    // Conversation history
    var conversation: std.ArrayList(core.Message) = .empty;
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
    try writeStr(stdout, allocator, "  Type a message to chat, or use commands:\n");
    try writeStr(stdout, allocator, "  \x1b[90m/setup\x1b[0m  — Configure provider and API key\n");
    try writeStr(stdout, allocator, "  \x1b[90m/model\x1b[0m  — Switch model\n");
    try writeStr(stdout, allocator, "  \x1b[90m/config\x1b[0m — Show current config\n");
    try writeStr(stdout, allocator, "  \x1b[90m/skills\x1b[0m — Browse or activate installed skills\n");
    if (interface.cli.canUseInteractiveInput(stdin, stdout)) {
        try writeStr(stdout, allocator, "  Type \x1b[90m/\x1b[0m for command suggestions, \x1b[90mTab\x1b[0m to complete\n");
    }
    try writeStr(stdout, allocator, "  \x1b[90m/help\x1b[0m   — Show all commands\n");
    try writeStr(stdout, allocator, "  \x1b[90m/quit\x1b[0m   — Exit\n\n");

    var history = interface.cli.History.init(allocator);
    defer history.deinit();

    var request_seq: u64 = 0;
    while (true) {
        if (!interface.cli.canUseInteractiveInput(stdin, stdout)) {
            try writeStr(stdout, allocator, "\x1b[36mhermes>\x1b[0m ");
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
                &loaded_cfg,
                &resolved_provider,
                &owned_model_override,
                &skills_runtime,
                &tools_runtime,
                &session_usage,
                native_http.client(),
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
            try writeStr(stdout, allocator, "\n  \x1b[33m⚡ Agent:\x1b[0m LLM not configured yet. Run \x1b[36m/setup\x1b[0m to configure.\n\n");
            continue;
        }

        try conversation.append(allocator, .{ .role = .user, .content = try allocator.dupe(u8, input) });
        const request_messages = try buildRequestMessages(allocator, &cfg, soul_text, &skills_runtime, conversation.items);
        defer freeRequestMessages(allocator, request_messages);

        const llm_client = resolved_provider.?.asLlmClient();
        const tool_schemas = try collectLlmToolSchemas(allocator, &tools_runtime);
        defer allocator.free(tool_schemas);
        var agent_loop = agent.AgentLoop{
            .allocator = allocator,
            .llm = llm_client,
            .tools = &tools_runtime.registry,
            .config = &cfg,
            .logger = app_ctx.logger,
        };

        var result = agent_loop.run(request_messages, tool_schemas) catch |err| {
            const err_name = @errorName(err);
            framework.observability.request_trace.complete(app_ctx.logger, &request_trace, 500, err_name);
            const msg = try renderChatErrorMessage(allocator, err_name);
            defer allocator.free(msg);
            try writeF(stdout, allocator, "\n  \x1b[31mError:\x1b[0m {s}\n\n", .{msg});
            continue;
        };
        defer result.deinit(allocator);

        framework.observability.request_trace.complete(app_ctx.logger, &request_trace, 200, null);
        session_usage.prompt_tokens += result.usage.prompt_tokens;
        session_usage.completion_tokens += result.usage.completion_tokens;
        session_usage.total_tokens += result.usage.total_tokens;

        try writeStr(stdout, allocator, "\n  \x1b[33m⚡ Agent:\x1b[0m ");
        try writeStr(stdout, allocator, result.content);
        try writeStr(stdout, allocator, "\n\n");

        try conversation.append(allocator, .{ .role = .assistant, .content = try allocator.dupe(u8, result.content) });
    }

    web_server.stop();
    if (web_thread) |wt| wt.join();

    try writeStr(stdout, allocator, "\n  Goodbye! 👋\n");
}

fn handleCommand(
    allocator: std.mem.Allocator,
    input: []const u8,
    stdout: std.Io.File,
    stdin: std.Io.File,
    config_path: []const u8,
    cfg: *core.Config,
    loaded_cfg: *?core.LoadedConfig,
    resolved_provider: *?llm.ResolvedProvider,
    owned_model_override: *?[]u8,
    skills_runtime: *interface.cli.SkillsRuntime,
    tools_runtime: *interface.cli.ToolsRuntime,
    session_usage: *core.TokenUsage,
    http: framework.HttpClient,
) !CommandAction {
    const parsed = interface.cli.parseCommand(input) orelse return .continue_session;

    switch (parsed.spec.id) {
        .quit => return .quit,
        .setup => {
            try runSetupWizard(allocator, stdout, stdin, config_path);
            try reloadRuntimeState(
                allocator,
                config_path,
                cfg,
                loaded_cfg,
                resolved_provider,
                tools_runtime,
                owned_model_override,
                http,
            );
            try printLoadedConfigSummary(allocator, stdout, cfg);
            return .continue_session;
        },
        .config => {
            try showConfig(allocator, stdout, config_path);
            return .continue_session;
        },
        .model => {
            if (parsed.arg == null) {
                if (cfg.models.len > 0) {
                    if (try interface.cli.runSelectionMenu(allocator, stdin, stdout, "Select model", cfg.models, findCurrentModelIndex(cfg))) |selected_index| {
                        const selected_model = cfg.models[selected_index];
                        _ = try switchModel(allocator, config_path, cfg, owned_model_override, selected_model);
                        try writeF(stdout, allocator, "\n  Model switched to: \x1b[32m{s}\x1b[0m\n\n", .{selected_model});
                        return .continue_session;
                    }
                }

                try writeF(stdout, allocator, "\n  \x1b[1mCurrent model:\x1b[0m \x1b[32m{s}\x1b[0m\n", .{cfg.model});
                if (cfg.models.len > 0) {
                    try writeStr(stdout, allocator, "\n  \x1b[1mAvailable models:\x1b[0m\n");
                    for (cfg.models) |m| {
                        try writeF(stdout, allocator, "    • {s}\n", .{m});
                    }
                } else {
                    try writeStr(stdout, allocator, "\n  No models configured. Add a \"models\" array to config.json:\n");
                    try writeStr(stdout, allocator, "  \x1b[90m\"models\": [\"gpt-4o\", \"claude-sonnet-4\", \"gemini-2.5-pro\"]\x1b[0m\n");
                }
                try writeStr(stdout, allocator, "\n  Usage: /model <name>\n\n");
                return .continue_session;
            }

            const target_model = parsed.arg.?;
            if (!(try switchModel(allocator, config_path, cfg, owned_model_override, target_model))) {
                try writeF(stdout, allocator, "\n  Invalid model: {s}\n", .{target_model});
                if (cfg.models.len > 0) {
                    try writeStr(stdout, allocator, "  Choose one of the configured models:\n");
                    for (cfg.models) |m| {
                        try writeF(stdout, allocator, "    • {s}\n", .{m});
                    }
                }
                try writeStr(stdout, allocator, "\n");
                return .continue_session;
            }
            try writeF(stdout, allocator, "\n  Model switched to: \x1b[32m{s}\x1b[0m\n\n", .{target_model});
            return .continue_session;
        },
        .skills => {
            try interface.cli.skills_config.handleSkillsCommand(allocator, stdin, stdout, skills_runtime);
            return .continue_session;
        },
        .skills_config => {
            try interface.cli.skills_config.renderSkillsDirectory(allocator, stdout, skills_runtime);
            return .continue_session;
        },
        .skills_view => {
            const name = parsed.arg orelse {
                try writeStr(stdout, allocator, "\n  Usage: /skills view <name>\n\n");
                return .continue_session;
            };
            try interface.cli.skills_config.renderSkillView(allocator, stdout, skills_runtime, name);
            return .continue_session;
        },
        .skills_use => {
            const name = parsed.arg orelse {
                try writeStr(stdout, allocator, "\n  Usage: /skills use <name>\n\n");
                return .continue_session;
            };
            try interface.cli.skills_config.activateSkill(allocator, stdout, skills_runtime, name);
            return .continue_session;
        },
        .skills_clear => {
            try interface.cli.skills_config.clearActiveSkill(allocator, stdout, skills_runtime);
            return .continue_session;
        },
        .usage => {
            try writeStr(stdout, allocator, "\n  \x1b[1mUsage:\x1b[0m\n");
            try writeF(stdout, allocator, "    Prompt tokens:     {d}\n", .{session_usage.prompt_tokens});
            try writeF(stdout, allocator, "    Completion tokens: {d}\n", .{session_usage.completion_tokens});
            try writeF(stdout, allocator, "    Total tokens:      {d}\n\n", .{session_usage.total_tokens});
            return .continue_session;
        },
        .help => {
            var io_threaded: std.Io.Threaded = .init_single_threaded;
            const io_instance = io_threaded.io();
            var buf: [8192]u8 = undefined;
            var writer = stdout.writer(io_instance, &buf);
            try interface.cli.commands.renderHelp(&writer.interface);
            try writer.interface.flush();
            return .continue_session;
        },
        .tools => {
            try @import("interface/cli/tools_config.zig").handleToolsCommand(allocator, parsed.arg orelse "", stdin, stdout, cfg, config_path, tools_runtime);
            return .continue_session;
        },
        .new_session => {
            try writeStr(stdout, allocator, "\n  ✨ New conversation started.\n\n");
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

fn collectLlmToolSchemas(
    allocator: std.mem.Allocator,
    tools_runtime: *interface.cli.ToolsRuntime,
) ![]llm.ToolSchema {
    const runtime_schemas = try tools_runtime.collectSchemas(allocator);
    defer allocator.free(runtime_schemas);

    const schemas = try allocator.alloc(llm.ToolSchema, runtime_schemas.len);
    for (runtime_schemas, 0..) |schema, index| {
        schemas[index] = .{
            .name = schema.name,
            .description = schema.description,
            .parameters_schema = schema.parameters_schema,
        };
    }
    return schemas;
}

fn freeRequestMessages(allocator: std.mem.Allocator, messages: []core.Message) void {
    if (messages.len > 0) allocator.free(messages[0].content);
    allocator.free(messages);
}

fn runSetupWizard(allocator: std.mem.Allocator, stdout: std.Io.File, stdin: std.Io.File, config_path: []const u8) !void {
    try writeStr(stdout, allocator, "\n  \x1b[1m═══ Setup Wizard ═══\x1b[0m\n\n");

    // Provider selection
    try writeStr(stdout, allocator, "  Select a provider:\n");
    try writeStr(stdout, allocator, "    \x1b[36m1\x1b[0m) OpenRouter (200+ models, recommended)\n");
    try writeStr(stdout, allocator, "    \x1b[36m2\x1b[0m) OpenAI\n");
    try writeStr(stdout, allocator, "    \x1b[36m3\x1b[0m) Anthropic (Claude)\n");
    try writeStr(stdout, allocator, "    \x1b[36m4\x1b[0m) Nous Research\n");
    try writeStr(stdout, allocator, "    \x1b[36m5\x1b[0m) Custom endpoint\n");
    try writeStr(stdout, allocator, "\n  Choice [1]: ");

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
    try writeStr(stdout, allocator, "\n  Enter API key: ");
    var key_buf: [512]u8 = undefined;
    const key_raw = try readLine(stdin, &key_buf) orelse "";
    const api_key = std.mem.trim(u8, key_raw, " \t\r\n");

    if (api_key.len > 0) {
        const masked_len = @min(api_key.len, 4);
        try writeF(stdout, allocator, "  API key: \x1b[32m{s}...****\x1b[0m\n", .{api_key[0..masked_len]});
    }

    const api_base_url = if (std.mem.eql(u8, provider, "custom")) blk: {
        while (true) {
            try writeStr(stdout, allocator, "\n  API base URL: ");
            var url_buf: [512]u8 = undefined;
            const url_raw = try readLine(stdin, &url_buf) orelse "";
            const url = std.mem.trim(u8, url_raw, " \t\r\n");
            if (url.len > 0) {
                try writeF(stdout, allocator, "  API base URL: \x1b[32m{s}\x1b[0m\n", .{url});
                break :blk url;
            }
            try writeStr(stdout, allocator, "  API base URL is required for custom provider.\n");
        }
    } else "";

    const wire_api = if (std.mem.eql(u8, provider, "custom") or std.mem.eql(u8, provider, "openai")) blk: {
        try writeStr(stdout, allocator, "\n  Select API protocol:\n");
        try writeStr(stdout, allocator, "    \x1b[36m1\x1b[0m) Chat Completions\n");
        try writeStr(stdout, allocator, "    \x1b[36m2\x1b[0m) Responses\n");
        try writeStr(stdout, allocator, "\n  Choice [1]: ");

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

    var file = try createConfigFile(config_path, allocator);
    var io_inst = std.Io.Threaded.init(allocator, .{});
    defer io_inst.deinit();
    defer file.close(io_inst.io());
    
    var write_buf: [4096]u8 = undefined;
    var writer = file.writer(io_inst.io(), &write_buf);
    try writer.interface.writeAll(config_json);

    try writeStr(stdout, allocator, "\n  \x1b[32m✓ Configuration saved to config.json\x1b[0m\n\n");
}

fn buildSetupConfigJson(
    allocator: std.mem.Allocator,
    provider: []const u8,
    model: []const u8,
    api_key: []const u8,
    api_base_url: []const u8,
    wire_api: []const u8,
) ![]u8 {
    const default_config = @embedFile("default_config.json");
    var loaded = try core.config_loader.loadFromString(default_config, allocator);
    defer loaded.deinit();

    var cfg = loaded.parsed.value;
    const setup_models = try buildSetupModels(allocator, provider, model);
    defer freeOwnedStringSlice(allocator, setup_models);

    cfg.provider = try allocator.dupe(u8, provider);
    defer allocator.free(cfg.provider);
    cfg.model = try allocator.dupe(u8, model);
    defer allocator.free(cfg.model);
    cfg.api_key = try allocator.dupe(u8, api_key);
    defer allocator.free(cfg.api_key);
    cfg.api_base_url = try allocator.dupe(u8, api_base_url);
    defer allocator.free(cfg.api_base_url);
    cfg.wire_api = try allocator.dupe(u8, wire_api);
    defer allocator.free(cfg.wire_api);
    cfg.models = setup_models;

    return std.json.Stringify.valueAlloc(allocator, cfg, .{ .whitespace = .indent_2 });
}

fn buildSetupModels(
    allocator: std.mem.Allocator,
    provider: []const u8,
    selected_model: []const u8,
) ![][]u8 {
    const candidates = if (std.mem.eql(u8, provider, "openrouter"))
        &[_][]const u8{
            selected_model,
            "openrouter/nous-hermes",
            "openrouter/anthropic/claude-sonnet-4",
            "openrouter/openai/gpt-4o",
            "gpt-4o",
            "gpt-4o-mini",
            "claude-sonnet-4-20250514",
            "claude-haiku-3.5",
            "gemini-2.5-pro",
        }
    else if (std.mem.eql(u8, provider, "anthropic"))
        &[_][]const u8{
            selected_model,
            "claude-sonnet-4-20250514",
            "claude-haiku-3.5",
        }
    else if (std.mem.eql(u8, provider, "nous"))
        &[_][]const u8{
            selected_model,
            "nous/hermes-3-llama-3.1-405b",
        }
    else
        &[_][]const u8{
            selected_model,
            "gpt-4o",
            "gpt-4o-mini",
            "gpt-5.4",
            "gpt-5.3-codex",
        };

    var models: std.ArrayList([]u8) = .empty;
    errdefer {
        for (models.items) |item| allocator.free(item);
        models.deinit(allocator);
    }

    for (candidates) |candidate| {
        var exists = false;
        for (models.items) |existing| {
            if (std.mem.eql(u8, existing, candidate)) {
                exists = true;
                break;
            }
        }
        if (exists) continue;
        try models.append(allocator, try allocator.dupe(u8, candidate));
    }

    return models.toOwnedSlice(allocator);
}

fn freeOwnedStringSlice(allocator: std.mem.Allocator, items: [][]u8) void {
    for (items) |item| allocator.free(item);
    allocator.free(items);
}

fn usesTextLogFormat(log_format: []const u8) bool {
    return std.mem.eql(u8, log_format, "text") or std.mem.eql(u8, log_format, "both") or log_format.len == 0;
}

fn usesJsonLogFormat(log_format: []const u8) bool {
    return std.mem.eql(u8, log_format, "json") or std.mem.eql(u8, log_format, "both");
}

fn showConfig(allocator: std.mem.Allocator, stdout: std.Io.File, config_path: []const u8) !void {
    const content = readConfigFileAlloc(allocator, config_path, 64 * 1024) catch |err| {
        try writeF(stdout, allocator, "\n  No config found: {s}\n\n", .{@errorName(err)});
        return;
    };
    defer allocator.free(content);
    try writeStr(stdout, allocator, "\n  \x1b[1mCurrent Configuration:\x1b[0m\n\x1b[90m");
    try writeStr(stdout, allocator, content);
    try writeStr(stdout, allocator, "\x1b[0m\n\n");
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

test "setup config json preserves runtime defaults needed by model and tools" {
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
    try std.testing.expect(loaded.parsed.value.models.len >= 1);
    try std.testing.expectEqualStrings("gpt-5.4", loaded.parsed.value.models[0]);
    try std.testing.expectEqual(@as(usize, 1), loaded.parsed.value.tools.enabled_toolsets.len);
    try std.testing.expectEqualStrings("default", loaded.parsed.value.tools.enabled_toolsets[0]);
}

test "chooseConfigPathAlloc prefers executable config over cwd fallback" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const tmp_dir_rel = try std.fs.path.join(std.testing.allocator, &.{ ".zig-cache", "tmp", tmp.sub_path[0..] });
    defer std.testing.allocator.free(tmp_dir_rel);
    const cwd = compat.Dir.wrap(std.Io.Dir.cwd());
    const tmp_dir_abs = try cwd.realpathAlloc(std.testing.allocator, tmp_dir_rel);
    defer std.testing.allocator.free(tmp_dir_abs);
    const config_path = try std.fs.path.join(std.testing.allocator, &.{ tmp_dir_abs, "config.json" });
    defer std.testing.allocator.free(config_path);

    const cfg = core.Config{
        .provider = "custom",
        .model = "gpt-5.4",
        .models = &.{"gpt-5.4"},
        .api_base_url = "https://example.com",
        .wire_api = "responses",
    };
    try saveConfigAlloc(std.testing.allocator, config_path, cfg);
}


test "switchModel updates in-memory config and writes file" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const tmp_dir_rel = try std.fs.path.join(std.testing.allocator, &.{ ".zig-cache", "tmp", tmp.sub_path[0..] });
    defer std.testing.allocator.free(tmp_dir_rel);
    const cwd = compat.Dir.wrap(std.Io.Dir.cwd());
    const tmp_dir_abs = try cwd.realpathAlloc(std.testing.allocator, tmp_dir_rel);
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

    const file = try compat_fs.openFileAbsolute(config_path, .{});
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
    const cwd = compat.Dir.wrap(std.Io.Dir.cwd());
    const tmp_dir_abs = try cwd.realpathAlloc(std.testing.allocator, tmp_dir_rel);
    defer std.testing.allocator.free(tmp_dir_abs);
    const config_path = try std.fs.path.join(std.testing.allocator, &.{ tmp_dir_abs, "config.json" });
    defer std.testing.allocator.free(config_path);

    var cfg = core.Config{
        .model = "gpt-5.4",
        .models = &.{"gpt-5.4"},
    };
    var owned_model_override: ?[]u8 = null;
    defer if (owned_model_override) |m| std.testing.allocator.free(m);

    try std.testing.expect(!(try switchModel(std.testing.allocator, config_path, &cfg, &owned_model_override, "gpt-4.1")));
    try std.testing.expectEqualStrings("gpt-5.4", cfg.model);
    try std.testing.expect(owned_model_override == null);
}

test "renderChatErrorMessage expands responses empty output" {
    const msg = try renderChatErrorMessage(std.testing.allocator, "ResponsesEmptyOutput");
    defer std.testing.allocator.free(msg);
    try std.testing.expect(std.mem.indexOf(u8, msg, "no usable output") != null);
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

// ============================================================================
// Phase 1 Integration Tests
// ============================================================================

test "Phase 1 Integration: Config + Model Metadata + Pricing" {
    // 1. 配置系统集成
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    
    const config_content =
        \\{
        \\  "provider": "openai",
        \\  "model": "gpt-4",
        \\  "api_key": "sk-test123"
        \\}
    ;
    
    var io_threaded: std.Io.Threaded = .init_single_threaded;
    const io = io_threaded.io();
    try tmp.dir.writeFile(io, .{ .sub_path = "config.json", .data = config_content });
    
    const tmp_wrapped = compat.Dir.wrap(tmp.dir);
    const tmp_path = try tmp_wrapped.realpathAlloc(std.testing.allocator, ".");
    defer std.testing.allocator.free(tmp_path);
    const config_path = try std.fs.path.join(std.testing.allocator, &.{ tmp_path, "config.json" });
    defer std.testing.allocator.free(config_path);
    
    var loaded = try core.config_loader.loadFromFile(config_path, std.testing.allocator);
    defer loaded.deinit();
    
    try std.testing.expectEqualStrings("openai", loaded.parsed.value.provider);
    try std.testing.expectEqualStrings("gpt-4", loaded.parsed.value.model);
    
    // 2. 模型元数据查询
    const gpt4o_info = agent.model_metadata.lookup("gpt-4o");
    try std.testing.expect(gpt4o_info != null);
    try std.testing.expectEqual(@as(u32, 128000), gpt4o_info.?.context_window);
    
    // 3. 成本计算
    const cost = agent.usage_pricing.calculateCost("gpt-4o", 1000, 500);
    try std.testing.expect(cost.total_cost > 0.0);
    try std.testing.expect(cost.input_cost > 0.0);
    try std.testing.expect(cost.output_cost > 0.0);
}

test "Phase 1 Integration: Database + Tool Messages" {
    const db = try core.sqlite.Database.open(":memory:");
    defer db.close();
    
    try core.database.initSchema(db);
    try core.database.createSession(db, "integration-test", "cli", "gpt-4");
    try core.database.appendMessage(db, "integration-test", "user", "Hello");
    try core.database.appendMessage(db, "integration-test", "assistant", "Hi there!");
    try core.database.appendToolMessage(db, "integration-test", "Tool result", "call_123", "test_tool");
    
    const count = try core.database.getMessageCount(db, "integration-test");
    try std.testing.expectEqual(@as(i64, 3), count);
}

test "Phase 1 Integration: Environment + Constants + Soul" {
    const hermes_home = try core.constants.getHermesHome(std.testing.allocator);
    defer std.testing.allocator.free(hermes_home);
    try std.testing.expect(hermes_home.len > 0);
    
    const soul = try core.soul.loadSoul(std.testing.allocator, "nonexistent-integration-test");
    defer std.testing.allocator.free(soul);
    try std.testing.expectEqualStrings(core.soul.DEFAULT_SOUL, soul);
}

test "Phase 1 Integration: Time Utils + Formatting" {
    const timestamp = core.time_utils.getCurrentTimestamp();
    try std.testing.expect(timestamp > 0);
    
    const formatted = try core.time_utils.formatTimestamp(std.testing.allocator, timestamp);
    defer std.testing.allocator.free(formatted);
    try std.testing.expect(formatted.len >= 10);
    try std.testing.expect(std.mem.indexOf(u8, formatted, "-") != null);
}

test "Phase 1 Integration: Utils + Atomic Write" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    
    var io_threaded: std.Io.Threaded = .init_single_threaded;
    const io = io_threaded.io();
    const tmp_wrapped = compat.Dir.wrap(tmp.dir);
    const tmp_path = try tmp_wrapped.realpathAlloc(std.testing.allocator, ".");
    defer std.testing.allocator.free(tmp_path);
    const test_file = try std.fs.path.join(std.testing.allocator, &.{ tmp_path, "atomic_test.txt" });
    defer std.testing.allocator.free(test_file);
    
    try core.utils.atomicWrite(io, std.testing.allocator, test_file, "test content");
    
    const content = try tmp.dir.readFileAlloc(io, "atomic_test.txt", std.testing.allocator, @enumFromInt(1024));
    defer std.testing.allocator.free(content);
    try std.testing.expectEqualStrings("test content", content);
}
