const std = @import("std");
const types = @import("types.zig");
const parse = @import("parse.zig");
const validate = @import("validate.zig");

const Config = types.Config;
const ProviderEntry = types.ProviderEntry;

/// 配置加载错误
pub const LoadError = error{
    ConfigNotFound,
    InvalidConfig,
} || std.mem.Allocator.Error || validate.ValidationError;

/// 配置搜索路径优先级
const ConfigSearchPaths = struct {
    /// 1. 当前目录
    current: []const u8 = "hermes.json",
    /// 2. 用户配置目录 (~/.config/hermes/config.json)
    user_config: ?[]const u8 = null,
    /// 3. 系统配置目录 (/etc/hermes/config.json)
    system_config: ?[]const u8 = null,
};

/// 从默认路径加载配置
/// 搜索顺序：当前目录 -> 用户配置目录 -> 系统配置目录
pub fn loadConfig(allocator: std.mem.Allocator, io: std.Io) LoadError!Config {
    const search_paths = try getSearchPaths(allocator);
    defer {
        if (search_paths.user_config) |p| allocator.free(p);
        if (search_paths.system_config) |p| allocator.free(p);
    }

    const cwd = std.Io.Dir.cwd();

    // 1. 尝试当前目录
    if (loadConfigFromPath(allocator, io, cwd, search_paths.current)) |config| {
        return config;
    } else |_| {}

    // 2. 尝试用户配置目录
    if (search_paths.user_config) |user_path| {
        if (loadConfigFromPath(allocator, io, cwd, user_path)) |config| {
            return config;
        } else |_| {}
    }

    // 3. 尝试系统配置目录
    if (search_paths.system_config) |sys_path| {
        if (loadConfigFromPath(allocator, io, cwd, sys_path)) |config| {
            return config;
        } else |_| {}
    }

    return error.ConfigNotFound;
}

/// 从指定路径加载配置
pub fn loadConfigFromPath(allocator: std.mem.Allocator, io: std.Io, dir: std.Io.Dir, path: []const u8) !Config {
    const config = try parse.parseConfigFile(allocator, io, dir, path);
    errdefer {
        for (config.providers) |provider| {
            allocator.free(provider.name);
            if (provider.api_key) |key| allocator.free(key);
            if (provider.base_url) |url| allocator.free(url);
        }
        allocator.free(config.providers);
        allocator.free(config.default_provider);
        allocator.free(config.default_model);
    }
    try validate.validateConfig(&config);
    return config;
}

/// 从文件句柄加载配置（已废弃，保留用于兼容）
fn loadConfigFromFile(allocator: std.mem.Allocator, file: std.Io.File) LoadError!Config {
    _ = file;
    _ = allocator;
    return error.InvalidConfig;
}

/// 获取配置搜索路径
fn getSearchPaths(allocator: std.mem.Allocator) !ConfigSearchPaths {
    var paths = ConfigSearchPaths{};

    // 用户配置目录
    if (std.c.getenv("HOME")) |home_ptr| {
        const home = std.mem.span(home_ptr);
        paths.user_config = try std.fs.path.join(allocator, &[_][]const u8{
            home,
            ".config",
            "hermes",
            "config.json",
        });
    }

    // 系统配置目录（仅 Unix-like 系统）
    if (@import("builtin").os.tag != .windows) {
        paths.system_config = try allocator.dupe(u8, "/etc/hermes/config.json");
    }

    return paths;
}

/// 合并两个配置（后者覆盖前者）
pub fn mergeConfig(allocator: std.mem.Allocator, base: Config, override: Config) !Config {
    var merged = Config{
        .default_provider = if (override.default_provider.len > 0) override.default_provider else base.default_provider,
        .default_model = if (override.default_model.len > 0) override.default_model else base.default_model,
        .temperature = override.temperature,
        .max_tokens = override.max_tokens,
        .providers = undefined,
    };

    // 合并 providers：override 中的 provider 覆盖 base 中同名的
    var provider_map = std.StringHashMap(ProviderEntry).init(allocator);
    defer provider_map.deinit();

    // 先添加 base 的 providers
    for (base.providers) |provider| {
        try provider_map.put(provider.name, provider);
    }

    // 再添加 override 的 providers（覆盖同名）
    for (override.providers) |provider| {
        try provider_map.put(provider.name, provider);
    }

    // 转换为数组
    const providers = try allocator.alloc(ProviderEntry, provider_map.count());
    var iter = provider_map.iterator();
    var i: usize = 0;
    while (iter.next()) |entry| : (i += 1) {
        providers[i] = entry.value_ptr.*;
    }
    merged.providers = providers;

    return merged;
}

// ============================================================================
// Tests
// ============================================================================

test "loadConfigFromPath - valid config" {
    const allocator = std.testing.allocator;

    // 创建临时配置文件
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const config_content =
        \\{
        \\  "default_provider": "anthropic",
        \\  "default_model": "claude-3-5-sonnet",
        \\  "temperature": 0.7,
        \\  "max_tokens": 4096,
        \\  "providers": [
        \\    {
        \\      "name": "anthropic",
        \\      "api_key": "test-key",
        \\      "base_url": "https://api.anthropic.com",
        \\      "api_mode": "chat_completions"
        \\    }
        \\  ]
        \\}
    ;

    const file = try tmp.dir.createFile(std.testing.io, "test_config.json", .{});
    var write_buffer: [4096]u8 = undefined;
    var w = file.writer(std.testing.io, &write_buffer);
    try w.interface.writeAll(config_content);
    try w.interface.flush();
    file.close(std.testing.io);

    const config = try loadConfigFromPath(allocator, std.testing.io, tmp.dir, "test_config.json");
    defer {
        for (config.providers) |provider| {
            allocator.free(provider.name);
            if (provider.api_key) |key| allocator.free(key);
            if (provider.base_url) |url| allocator.free(url);
        }
        allocator.free(config.providers);
        allocator.free(config.default_provider);
        allocator.free(config.default_model);
    }

    try std.testing.expectEqualStrings("anthropic", config.default_provider);
    try std.testing.expectEqualStrings("claude-3-5-sonnet", config.default_model);
    try std.testing.expectEqual(@as(f32, 0.7), config.temperature);
    try std.testing.expectEqual(@as(u32, 4096), config.max_tokens);
    try std.testing.expectEqual(@as(usize, 1), config.providers.len);
}

test "loadConfigFromPath - invalid config" {
    const allocator = std.testing.allocator;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const config_content =
        \\{
        \\  "default_provider": "",
        \\  "default_model": "claude-3-5-sonnet",
        \\  "temperature": 0.7,
        \\  "max_tokens": 4096,
        \\  "providers": []
        \\}
    ;

    const file = try tmp.dir.createFile(std.testing.io, "invalid_config.json", .{});
    var write_buffer: [4096]u8 = undefined;
    var w = file.writer(std.testing.io, &write_buffer);
    try w.interface.writeAll(config_content);
    try w.interface.flush();
    file.close(std.testing.io);

    const result = loadConfigFromPath(allocator, std.testing.io, tmp.dir, "invalid_config.json");
    try std.testing.expectError(error.MissingDefaultProvider, result);
}

test "mergeConfig - basic merge" {
    const allocator = std.testing.allocator;

    const base_providers = try allocator.alloc(ProviderEntry, 1);
    defer allocator.free(base_providers);
    base_providers[0] = ProviderEntry{
        .name = "anthropic",
        .api_key = "base-key",
        .base_url = "https://api.anthropic.com",
        .api_mode = .chat_completions,
    };

    const override_providers = try allocator.alloc(ProviderEntry, 1);
    defer allocator.free(override_providers);
    override_providers[0] = ProviderEntry{
        .name = "openai",
        .api_key = "override-key",
        .base_url = "https://api.openai.com",
        .api_mode = .chat_completions,
    };

    const base = Config{
        .default_provider = "anthropic",
        .default_model = "claude-3-5-sonnet",
        .temperature = 0.7,
        .max_tokens = 4096,
        .providers = base_providers,
    };

    const override = Config{
        .default_provider = "openai",
        .default_model = "gpt-4",
        .temperature = 0.9,
        .max_tokens = 8192,
        .providers = override_providers,
    };

    const merged = try mergeConfig(allocator, base, override);
    defer allocator.free(merged.providers);

    try std.testing.expectEqualStrings("openai", merged.default_provider);
    try std.testing.expectEqualStrings("gpt-4", merged.default_model);
    try std.testing.expectEqual(@as(f32, 0.9), merged.temperature);
    try std.testing.expectEqual(@as(u32, 8192), merged.max_tokens);
    try std.testing.expectEqual(@as(usize, 2), merged.providers.len);
}

test "mergeConfig - override same provider" {
    const allocator = std.testing.allocator;

    const base_providers = try allocator.alloc(ProviderEntry, 1);
    defer allocator.free(base_providers);
    base_providers[0] = ProviderEntry{
        .name = "anthropic",
        .api_key = "base-key",
        .base_url = "https://api.anthropic.com",
        .api_mode = .chat_completions,
    };

    const override_providers = try allocator.alloc(ProviderEntry, 1);
    defer allocator.free(override_providers);
    override_providers[0] = ProviderEntry{
        .name = "anthropic",
        .api_key = "override-key",
        .base_url = "https://custom.anthropic.com",
        .api_mode = .chat_completions,
    };

    const base = Config{
        .default_provider = "anthropic",
        .default_model = "claude-3-5-sonnet",
        .temperature = 0.7,
        .max_tokens = 4096,
        .providers = base_providers,
    };

    const override = Config{
        .default_provider = "",
        .default_model = "",
        .temperature = 0.7,
        .max_tokens = 4096,
        .providers = override_providers,
    };

    const merged = try mergeConfig(allocator, base, override);
    defer allocator.free(merged.providers);

    try std.testing.expectEqual(@as(usize, 1), merged.providers.len);
    try std.testing.expectEqualStrings("override-key", merged.providers[0].api_key.?);
    try std.testing.expectEqualStrings("https://custom.anthropic.com", merged.providers[0].base_url.?);
}
