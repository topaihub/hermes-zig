const std = @import("std");
const builtin = @import("builtin");

pub fn getEnvVarOwned(allocator: std.mem.Allocator, key: []const u8) !?[]u8 {
    return std.process.getEnvVarOwned(allocator, key) catch |err| switch (err) {
        error.EnvironmentVariableNotFound => null,
        else => return err,
    };
}

pub fn getHomeDirOwned(allocator: std.mem.Allocator) ![]u8 {
    if (try getEnvVarOwned(allocator, "HOME")) |home| {
        return home;
    }

    if (builtin.os.tag == .windows) {
        if (try getEnvVarOwned(allocator, "USERPROFILE")) |profile| {
            return profile;
        }

        const home_drive = try getEnvVarOwned(allocator, "HOMEDRIVE");
        const home_path = try getEnvVarOwned(allocator, "HOMEPATH");

        if (home_drive) |drive| {
            if (home_path) |path| {
                defer allocator.free(drive);
                defer allocator.free(path);
                return std.fmt.allocPrint(allocator, "{s}{s}", .{ drive, path });
            }
            allocator.free(drive);
        }

        if (home_path) |path| {
            allocator.free(path);
        }
    }

    return allocator.dupe(u8, ".");
}

test "getEnvVarOwned returns null for missing values" {
    const value = try getEnvVarOwned(std.testing.allocator, "HERMES_ZIG_TEST_MISSING_ENV");
    try std.testing.expect(value == null);
}
