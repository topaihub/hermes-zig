const std = @import("std");
const core_env = @import("../../core/env_loader.zig");

pub const loadEnvFile = core_env.loadEnvFile;
pub const deinitEnvMap = core_env.deinitEnvMap;

pub fn loadDotEnv(allocator: std.mem.Allocator) !core_env.EnvMap {
    const home = std.process.getEnvVarOwned(allocator, "HERMES_HOME") catch |err| switch (err) {
        error.EnvironmentVariableNotFound => return core_env.EnvMap.init(allocator),
        else => return err,
    };
    defer allocator.free(home);
    const path = try std.fmt.allocPrint(allocator, "{s}/.env", .{home});
    defer allocator.free(path);
    return core_env.loadEnvFile(allocator, path);
}

test "function exists" {
    // loadDotEnv is callable — will return empty map when HERMES_HOME is unset
    var map = try loadDotEnv(std.testing.allocator);
    defer deinitEnvMap(std.testing.allocator, &map);
    try std.testing.expectEqual(@as(usize, 0), map.count());
}
