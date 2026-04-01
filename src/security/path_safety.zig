const std = @import("std");

pub const PathError = error{UnsafePath};

pub fn resolveSafePath(base: []const u8, requested: []const u8) (PathError || error{OutOfMemory})![]const u8 {
    // Reject paths containing ..
    if (std.mem.indexOf(u8, requested, "..") != null) return PathError.UnsafePath;
    // Reject null bytes
    if (std.mem.indexOfScalar(u8, requested, 0) != null) return PathError.UnsafePath;
    // If absolute and not under base, reject
    if (requested.len > 0 and requested[0] == '/') {
        if (!std.mem.startsWith(u8, requested, base)) return PathError.UnsafePath;
        return requested;
    }
    return requested;
}

test "resolveSafePath rejects .." {
    const result = resolveSafePath("/home/user", "../etc/passwd");
    try std.testing.expectError(PathError.UnsafePath, result);
}

test "resolveSafePath allows safe relative path" {
    const result = try resolveSafePath("/home/user", "docs/file.txt");
    try std.testing.expectEqualStrings("docs/file.txt", result);
}
