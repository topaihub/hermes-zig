const std = @import("std");

/// Atomically write content to a file
/// Writes to a temporary file first, then renames to target path (atomic on POSIX)
pub fn atomicWrite(io: std.Io, allocator: std.mem.Allocator, path: []const u8, content: []const u8) !void {
    // Create temporary file path
    const tmp_path = try std.fmt.allocPrint(allocator, "{s}.tmp", .{path});
    defer allocator.free(tmp_path);
    
    // Write to temporary file
    {
        const file = try std.Io.Dir.createFileAbsolute(io, tmp_path, .{ .truncate = true });
        defer file.close(io);
        
        var write_buffer: [8192]u8 = undefined;
        var w = file.writer(io, &write_buffer);
        try w.interface.writeAll(content);
        try w.interface.flush();
    }
    
    // Atomic rename
    try std.Io.Dir.renameAbsolute(tmp_path, path, io);
}

/// Ensure directory exists, creating it if necessary
pub fn ensureDir(io: std.Io, path: []const u8) !void {
    std.Io.Dir.createDirAbsolute(io, path, .default_dir) catch |err| switch (err) {
        error.PathAlreadyExists => return,
        else => return err,
    };
}

/// Expand ~ in path to home directory
pub fn expandHome(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    if (path.len == 0 or path[0] != '~') {
        return try allocator.dupe(u8, path);
    }
    
    // Get HOME environment variable (USERPROFILE on Windows)
    const environ = std.process.Environ{ .block = .global };
    const home = blk: {
        if (environ.getAlloc(allocator, "HOME")) |h| {
            break :blk h;
        } else |_| {
            // Try USERPROFILE on Windows
            if (environ.getAlloc(allocator, "USERPROFILE")) |h| {
                break :blk h;
            } else |_| {
                return error.HomeDirectoryNotFound;
            }
        }
    };
    defer allocator.free(home);
    
    if (path.len == 1) {
        // Just "~"
        return try allocator.dupe(u8, home);
    }
    
    if (path[1] == '/' or path[1] == '\\') {
        // "~/path"
        return try std.fs.path.join(allocator, &.{ home, path[2..] });
    }
    
    // "~something" - not supported, return as-is
    return try allocator.dupe(u8, path);
}

test "expandHome with tilde" {
    const allocator = std.testing.allocator;
    
    const expanded = try expandHome(allocator, "~/test/path");
    defer allocator.free(expanded);
    
    // Should not start with ~
    try std.testing.expect(expanded[0] != '~');
    try std.testing.expect(std.mem.endsWith(u8, expanded, "test/path") or 
                           std.mem.endsWith(u8, expanded, "test\\path"));
}

test "expandHome without tilde" {
    const allocator = std.testing.allocator;
    
    const expanded = try expandHome(allocator, "/absolute/path");
    defer allocator.free(expanded);
    
    try std.testing.expectEqualStrings("/absolute/path", expanded);
}

test "expandHome just tilde" {
    const allocator = std.testing.allocator;
    
    const expanded = try expandHome(allocator, "~");
    defer allocator.free(expanded);
    
    try std.testing.expect(expanded.len > 0);
    try std.testing.expect(expanded[0] != '~');
}

test "atomicWrite creates file" {
    const allocator = std.testing.allocator;
    
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    
    // Get absolute path
    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const tmp_path_len = try tmp.dir.realPath(std.testing.io, &path_buf);
    const tmp_path = path_buf[0..tmp_path_len];
    
    const test_file = try std.fs.path.join(allocator, &.{ tmp_path, "test.txt" });
    defer allocator.free(test_file);
    
    const content = "test content";
    try atomicWrite(std.testing.io, allocator, test_file, content);
    
    // Read back and verify
    const read_content = try tmp.dir.readFileAlloc(std.testing.io, "test.txt", allocator, .limited(1024));
    defer allocator.free(read_content);
    
    try std.testing.expectEqualStrings(content, read_content);
}

test "ensureDir creates directory" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    
    // Get absolute path
    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const tmp_path_len = try tmp.dir.realPath(std.testing.io, &path_buf);
    const tmp_path = path_buf[0..tmp_path_len];
    const test_dir = try std.fs.path.join(std.testing.allocator, &.{ tmp_path, "test_dir" });
    defer std.testing.allocator.free(test_dir);
    
    try ensureDir(std.testing.io, test_dir);
    
    // Verify directory exists
    var dir = try std.Io.Dir.openDirAbsolute(std.testing.io, test_dir, .{});
    dir.close(std.testing.io);
}

test "ensureDir handles existing directory" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    
    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const tmp_path_len = try tmp.dir.realPath(std.testing.io, &path_buf);
    const tmp_path = path_buf[0..tmp_path_len];
    const test_dir = try std.fs.path.join(std.testing.allocator, &.{ tmp_path, "existing_dir" });
    defer std.testing.allocator.free(test_dir);
    
    // Create directory first
    try ensureDir(std.testing.io, test_dir);
    
    // Should not error when called again
    try ensureDir(std.testing.io, test_dir);
}
