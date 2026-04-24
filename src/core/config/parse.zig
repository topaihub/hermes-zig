//! Configuration parsing and loading for hermes-zig
//!
//! Simplified from nullclaw's config_parse.zig for Personal Agent use case.
//! Supports JSON config files with environment variable substitution.

const std = @import("std");
const types = @import("types.zig");

const Config = types.Config;
const ProviderEntry = types.ProviderEntry;

/// Parse a JSON configuration file
pub fn parseConfigFile(allocator: std.mem.Allocator, io: std.Io, dir: std.Io.Dir, path: []const u8) !Config {
    // Read file content
    const content = try dir.readFileAlloc(io, path, allocator, .limited(10 * 1024 * 1024)); // 10MB max
    defer allocator.free(content);
    
    // Expand environment variables
    const expanded = try expandEnvVars(allocator, content);
    defer allocator.free(expanded);
    
    // Parse JSON
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, expanded, .{});
    defer parsed.deinit();
    
    if (parsed.value != .object) {
        return error.InvalidConfigFormat;
    }
    
    return try parseConfig(allocator, parsed.value.object);
}

/// Parse configuration from JSON object
fn parseConfig(allocator: std.mem.Allocator, obj: std.json.ObjectMap) !Config {
    var config = Config{};
    
    // Parse providers
    if (obj.get("providers")) |providers_val| {
        if (providers_val == .array) {
            config.providers = try parseProviders(allocator, providers_val.array);
        }
    }
    
    // Parse default provider
    if (obj.get("default_provider")) |val| {
        if (val == .string) {
            config.default_provider = try allocator.dupe(u8, val.string);
        }
    }
    
    // Parse default model
    if (obj.get("default_model")) |val| {
        if (val == .string) {
            config.default_model = try allocator.dupe(u8, val.string);
        }
    }
    
    // Parse temperature
    if (obj.get("temperature")) |val| {
        if (val == .float) {
            config.temperature = @floatCast(val.float);
        } else if (val == .integer) {
            config.temperature = @floatFromInt(val.integer);
        }
    }
    
    // Parse max_tokens
    if (obj.get("max_tokens")) |val| {
        if (val == .integer) {
            config.max_tokens = @intCast(val.integer);
        }
    }
    
    // Parse tools config
    if (obj.get("tools")) |val| {
        if (val == .object) {
            config.tools = try parseToolsConfig(allocator, val.object);
        }
    }
    
    // Parse security config
    if (obj.get("security")) |val| {
        if (val == .object) {
            config.security = try parseSecurityConfig(allocator, val.object);
        }
    }
    
    // Parse memory config
    if (obj.get("memory")) |val| {
        if (val == .object) {
            config.memory = try parseMemoryConfig(allocator, val.object);
        }
    }
    
    // Parse gateway config
    if (obj.get("gateway")) |val| {
        if (val == .object) {
            config.gateway = try parseGatewayConfig(allocator, val.object);
        }
    }
    
    // Parse personality config
    if (obj.get("personality")) |val| {
        if (val == .object) {
            config.personality = try parsePersonalityConfig(allocator, val.object);
        }
    }
    
    // Parse routing config
    if (obj.get("routing")) |val| {
        if (val == .object) {
            config.routing = try parseRoutingConfig(allocator, val.object);
        }
    }
    
    return config;
}

/// Parse providers array
fn parseProviders(allocator: std.mem.Allocator, arr: std.json.Array) ![]const ProviderEntry {
    var list: std.ArrayListUnmanaged(ProviderEntry) = .empty;
    errdefer {
        for (list.items) |provider| {
            allocator.free(provider.name);
            if (provider.api_key) |key| allocator.free(key);
            if (provider.base_url) |url| allocator.free(url);
        }
        list.deinit(allocator);
    }
    
    for (arr.items) |item| {
        if (item != .object) continue;
        
        const provider = try parseProviderEntry(allocator, item.object);
        try list.append(allocator, provider);
    }
    
    return try list.toOwnedSlice(allocator);
}

/// Parse a single provider entry
fn parseProviderEntry(allocator: std.mem.Allocator, obj: std.json.ObjectMap) !ProviderEntry {
    var provider = ProviderEntry{
        .name = "",
    };
    
    // Name (required)
    if (obj.get("name")) |val| {
        if (val == .string) {
            provider.name = try allocator.dupe(u8, val.string);
        }
    }
    
    // API key
    if (obj.get("api_key")) |val| {
        if (val == .string) {
            provider.api_key = try allocator.dupe(u8, val.string);
        }
    }
    
    // Base URL
    if (obj.get("base_url")) |val| {
        if (val == .string) {
            provider.base_url = try allocator.dupe(u8, val.string);
        }
    }
    
    // Native tools
    if (obj.get("native_tools")) |val| {
        if (val == .bool) {
            provider.native_tools = val.bool;
        }
    }
    
    // API mode
    if (obj.get("api_mode")) |val| {
        if (val == .string) {
            provider.api_mode = ProviderEntry.ApiMode.parse(val.string);
        }
    }
    
    return provider;
}

/// Parse tools configuration
fn parseToolsConfig(allocator: std.mem.Allocator, obj: std.json.ObjectMap) !types.ToolsConfig {
    var config = types.ToolsConfig{};
    
    if (obj.get("enabled_toolsets")) |val| {
        if (val == .array) {
            config.enabled_toolsets = try parseStringArray(allocator, val.array);
        }
    }
    
    if (obj.get("disabled_tools")) |val| {
        if (val == .array) {
            config.disabled_tools = try parseStringArray(allocator, val.array);
        }
    }
    
    if (obj.get("timeout_ms")) |val| {
        if (val == .integer) {
            config.timeout_ms = @intCast(val.integer);
        }
    }
    
    return config;
}

/// Parse security configuration
fn parseSecurityConfig(allocator: std.mem.Allocator, obj: std.json.ObjectMap) !types.SecurityConfig {
    _ = allocator;
    var config = types.SecurityConfig{};
    
    if (obj.get("autonomy_level")) |val| {
        if (val == .string) {
            if (std.mem.eql(u8, val.string, "full")) {
                config.autonomy_level = .full;
            } else if (std.mem.eql(u8, val.string, "supervised")) {
                config.autonomy_level = .supervised;
            } else if (std.mem.eql(u8, val.string, "restricted")) {
                config.autonomy_level = .restricted;
            }
        }
    }
    
    if (obj.get("command_approval")) |val| {
        if (val == .bool) {
            config.command_approval = val.bool;
        }
    }
    
    if (obj.get("injection_scanning")) |val| {
        if (val == .bool) {
            config.injection_scanning = val.bool;
        }
    }
    
    if (obj.get("path_safety")) |val| {
        if (val == .bool) {
            config.path_safety = val.bool;
        }
    }
    
    if (obj.get("audit_logging")) |val| {
        if (val == .bool) {
            config.audit_logging = val.bool;
        }
    }
    
    return config;
}

/// Parse memory configuration
fn parseMemoryConfig(allocator: std.mem.Allocator, obj: std.json.ObjectMap) !types.MemoryConfig {
    _ = allocator;
    var config = types.MemoryConfig{};
    
    if (obj.get("enabled")) |val| {
        if (val == .bool) {
            config.enabled = val.bool;
        }
    }
    
    if (obj.get("cache_enabled")) |val| {
        if (val == .bool) {
            config.cache_enabled = val.bool;
        }
    }
    
    if (obj.get("cache_size")) |val| {
        if (val == .integer) {
            config.cache_size = @intCast(val.integer);
        }
    }
    
    if (obj.get("nudge_interval")) |val| {
        if (val == .integer) {
            config.nudge_interval = @intCast(val.integer);
        }
    }
    
    return config;
}

/// Parse gateway configuration
fn parseGatewayConfig(allocator: std.mem.Allocator, obj: std.json.ObjectMap) !types.GatewayConfig {
    _ = allocator;
    var config = types.GatewayConfig{};
    
    if (obj.get("enabled")) |val| {
        if (val == .bool) {
            config.enabled = val.bool;
        }
    }
    
    if (obj.get("listen_port")) |val| {
        if (val == .integer) {
            config.listen_port = @intCast(val.integer);
        }
    }
    
    if (obj.get("auth_enabled")) |val| {
        if (val == .bool) {
            config.auth_enabled = val.bool;
        }
    }
    
    if (obj.get("rate_limit_enabled")) |val| {
        if (val == .bool) {
            config.rate_limit_enabled = val.bool;
        }
    }
    
    if (obj.get("websocket_enabled")) |val| {
        if (val == .bool) {
            config.websocket_enabled = val.bool;
        }
    }
    
    return config;
}

/// Parse personality configuration
fn parsePersonalityConfig(allocator: std.mem.Allocator, obj: std.json.ObjectMap) !types.PersonalityConfig {
    _ = allocator;
    var config = types.PersonalityConfig{};
    
    if (obj.get("enabled")) |val| {
        if (val == .bool) {
            config.enabled = val.bool;
        }
    }
    
    if (obj.get("memory_isolation")) |val| {
        if (val == .bool) {
            config.memory_isolation = val.bool;
        }
    }
    
    return config;
}

/// Parse routing configuration
fn parseRoutingConfig(allocator: std.mem.Allocator, obj: std.json.ObjectMap) !types.RoutingConfig {
    _ = allocator;
    var config = types.RoutingConfig{};
    
    if (obj.get("enabled")) |val| {
        if (val == .bool) {
            config.enabled = val.bool;
        }
    }
    
    return config;
}

/// Parse string array from JSON
fn parseStringArray(allocator: std.mem.Allocator, arr: std.json.Array) ![]const []const u8 {
    var list: std.ArrayListUnmanaged([]const u8) = .empty;
    errdefer {
        for (list.items) |item| allocator.free(item);
        list.deinit(allocator);
    }
    
    for (arr.items) |item| {
        if (item == .string) {
            try list.append(allocator, try allocator.dupe(u8, item.string));
        }
    }
    
    return try list.toOwnedSlice(allocator);
}

/// Expand environment variables in format ${VAR_NAME}
fn expandEnvVars(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var result: std.ArrayListUnmanaged(u8) = .empty;
    errdefer result.deinit(allocator);
    
    var i: usize = 0;
    while (i < input.len) {
        if (i + 1 < input.len and input[i] == '$' and input[i + 1] == '{') {
            // Find closing brace
            const start = i + 2;
            var end = start;
            while (end < input.len and input[end] != '}') : (end += 1) {}
            
            if (end < input.len) {
                const var_name = input[start..end];
                
                // Create null-terminated string for C API
                const var_name_z = try allocator.dupeZ(u8, var_name);
                defer allocator.free(var_name_z);
                
                // Try to get environment variable using C getenv
                if (std.c.getenv(var_name_z)) |var_value_ptr| {
                    const var_value = std.mem.span(var_value_ptr);
                    try result.appendSlice(allocator, var_value);
                } else {
                    // Keep original ${VAR} if not found
                    try result.appendSlice(allocator, input[i..end + 1]);
                }
                
                i = end + 1;
                continue;
            }
        }
        
        try result.append(allocator, input[i]);
        i += 1;
    }
    
    return result.toOwnedSlice(allocator);
}

/// Load configuration from standard paths
pub fn loadConfig(allocator: std.mem.Allocator) !Config {
    // Try ~/.hermes/config.json first
    const home = std.process.getEnvVarOwned(allocator, "HOME") catch |err| {
        if (err == error.EnvironmentVariableNotFound) {
            // Try USERPROFILE on Windows
            return std.process.getEnvVarOwned(allocator, "USERPROFILE") catch {
                return error.HomeDirectoryNotFound;
            };
        }
        return err;
    };
    defer allocator.free(home);
    
    const config_path = try std.fs.path.join(allocator, &.{ home, ".hermes", "config.json" });
    defer allocator.free(config_path);
    
    // Try to load from ~/.hermes/config.json
    if (parseConfigFile(allocator, config_path)) |config| {
        return config;
    } else |err| {
        if (err != error.FileNotFound) {
            return err;
        }
    }
    
    // Try ./config.json
    if (parseConfigFile(allocator, "config.json")) |config| {
        return config;
    } else |err| {
        if (err != error.FileNotFound) {
            return err;
        }
    }
    
    // No config file found, return default
    return Config{};
}

// ── Tests ──────────────────────────────────────────────────────────

test "expandEnvVars - no variables" {
    const allocator = std.testing.allocator;
    const input = "hello world";
    const output = try expandEnvVars(allocator, input);
    defer allocator.free(output);
    
    try std.testing.expectEqualStrings(input, output);
}

test "expandEnvVars - with variable" {
    const allocator = std.testing.allocator;
    
    // Note: This test depends on PATH environment variable being set
    // which is typically available in all environments
    const input = "prefix ${PATH} suffix";
    const output = try expandEnvVars(allocator, input);
    defer allocator.free(output);
    
    // Just verify it doesn't keep the ${PATH} literal
    try std.testing.expect(std.mem.indexOf(u8, output, "${PATH}") == null);
    try std.testing.expect(std.mem.startsWith(u8, output, "prefix "));
    try std.testing.expect(std.mem.endsWith(u8, output, " suffix"));
}

test "expandEnvVars - undefined variable" {
    const allocator = std.testing.allocator;
    const input = "hello ${UNDEFINED_VAR} world";
    const output = try expandEnvVars(allocator, input);
    defer allocator.free(output);
    
    // Should keep original ${UNDEFINED_VAR}
    try std.testing.expectEqualStrings(input, output);
}

test "parseConfigFile - valid JSON" {
    const allocator = std.testing.allocator;
    
    // Create temporary config file
    var tmp_dir = std.testing.tmpDir(.{});
    defer tmp_dir.cleanup();
    
    const config_content =
        \\{
        \\  "default_provider": "anthropic",
        \\  "default_model": "claude-3-5-sonnet",
        \\  "temperature": 0.7,
        \\  "providers": [
        \\    {
        \\      "name": "anthropic",
        \\      "api_key": "test-key",
        \\      "base_url": "https://api.anthropic.com"
        \\    }
        \\  ]
        \\}
    ;
    
    const file = try tmp_dir.dir.createFile(std.testing.io, "config.json", .{});
    
    // Write using Writer interface
    var write_buffer: [4096]u8 = undefined;
    var w = file.writer(std.testing.io, &write_buffer);
    try w.interface.writeAll(config_content);
    try w.interface.flush();
    
    // Close file after writing
    file.close(std.testing.io);
    
    // Parse config file directly
    const config = try parseConfigFile(allocator, std.testing.io, tmp_dir.dir, "config.json");
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
    try std.testing.expectEqual(@as(usize, 1), config.providers.len);
}

test "parseStringArray" {
    const allocator = std.testing.allocator;
    
    var arr = std.json.Array.init(allocator);
    defer arr.deinit();
    
    try arr.append(.{ .string = "item1" });
    try arr.append(.{ .string = "item2" });
    try arr.append(.{ .string = "item3" });
    
    const result = try parseStringArray(allocator, arr);
    defer {
        for (result) |item| allocator.free(item);
        allocator.free(result);
    }
    
    try std.testing.expectEqual(@as(usize, 3), result.len);
    try std.testing.expectEqualStrings("item1", result[0]);
    try std.testing.expectEqualStrings("item2", result[1]);
    try std.testing.expectEqualStrings("item3", result[2]);
}
