const std = @import("std");
const Allocator = std.mem.Allocator;

pub const EnvMap = std.StringHashMap([]const u8);

/// Load environment variables from a .env file
pub fn loadEnvFile(allocator: Allocator, path: []const u8) !EnvMap {
    var map = EnvMap.init(allocator);
    errdefer {
        var it = map.iterator();
        while (it.next()) |entry| {
            allocator.free(entry.key_ptr.*);
            allocator.free(entry.value_ptr.*);
        }
        map.deinit();
    }

    var io_threaded: std.Io.Threaded = .init_single_threaded;
    const io = io_threaded.io();
    
    const content = blk: {
        const file = try std.Io.Dir.openFileAbsolute(io, path, .{});
        defer file.close(io);
        var stream_buf: [4096]u8 = undefined;
        var reader = file.readerStreaming(io, &stream_buf);
        break :blk try reader.interface.allocRemaining(allocator, .limited(10 * 1024 * 1024));
    };
    defer allocator.free(content);

    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        
        // Skip empty lines and comments
        if (trimmed.len == 0 or trimmed[0] == '#') continue;
        
        // Find '=' separator
        const eq_pos = std.mem.indexOfScalar(u8, trimmed, '=') orelse continue;
        
        const key = std.mem.trim(u8, trimmed[0..eq_pos], " \t");
        if (key.len == 0) continue;
        
        var value = std.mem.trim(u8, trimmed[eq_pos + 1 ..], " \t");
        
        // Handle quotes
        if (value.len >= 2) {
            if ((value[0] == '"' and value[value.len - 1] == '"') or
                (value[0] == '\'' and value[value.len - 1] == '\''))
            {
                value = value[1 .. value.len - 1];
            }
        }
        
        const key_owned = try allocator.dupe(u8, key);
        errdefer allocator.free(key_owned);
        const value_owned = try allocator.dupe(u8, value);
        errdefer allocator.free(value_owned);
        
        try map.put(key_owned, value_owned);
    }

    return map;
}

/// Free all keys and values in the map
pub fn freeEnvMap(map: *EnvMap) void {
    const allocator = map.allocator;
    var it = map.iterator();
    while (it.next()) |entry| {
        allocator.free(entry.key_ptr.*);
        allocator.free(entry.value_ptr.*);
    }
    map.deinit();
}

test "loadEnvFile parses basic KEY=VALUE" {
    const allocator = std.testing.allocator;
    
    // Create temp file
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    
    var io_threaded: std.Io.Threaded = .init_single_threaded;
    const io = io_threaded.io();
    
    const env_content = "API_KEY=sk-123\nMODEL=gpt-4o\n";
    try tmp.dir.writeFile(io, .{ .sub_path = ".env", .data = env_content });
    
    // Use std.Io.Dir.realPathFileAlloc
    const env_path_z = try tmp.dir.realPathFileAlloc(io, ".env", allocator);
    defer allocator.free(env_path_z);
    const env_path = try allocator.dupe(u8, env_path_z);
    defer allocator.free(env_path);
    
    var map = try loadEnvFile(allocator, env_path);
    defer freeEnvMap(&map);
    
    try std.testing.expectEqualStrings("sk-123", map.get("API_KEY").?);
    try std.testing.expectEqualStrings("gpt-4o", map.get("MODEL").?);
}

test "loadEnvFile skips comments and empty lines" {
    const allocator = std.testing.allocator;
    
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    
    var io_threaded: std.Io.Threaded = .init_single_threaded;
    const io = io_threaded.io();
    
    const env_content = "# This is a comment\nAPI_KEY=sk-123\n\n# Another comment\nMODEL=gpt-4o\n";
    try tmp.dir.writeFile(io, .{ .sub_path = ".env", .data = env_content });
    
    const env_path_z = try tmp.dir.realPathFileAlloc(io, ".env", allocator);
    defer allocator.free(env_path_z);
    const env_path = try allocator.dupe(u8, env_path_z);
    defer allocator.free(env_path);
    
    var map = try loadEnvFile(allocator, env_path);
    defer freeEnvMap(&map);
    
    try std.testing.expectEqual(@as(usize, 2), map.count());
    try std.testing.expectEqualStrings("sk-123", map.get("API_KEY").?);
}

test "loadEnvFile handles quoted values" {
    const allocator = std.testing.allocator;
    
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    
    var io_threaded: std.Io.Threaded = .init_single_threaded;
    const io = io_threaded.io();
    
    const env_content = "KEY1=\"value with spaces\"\nKEY2='single quoted'\nKEY3=unquoted\n";
    try tmp.dir.writeFile(io, .{ .sub_path = ".env", .data = env_content });
    
    const env_path_z = try tmp.dir.realPathFileAlloc(io, ".env", allocator);
    defer allocator.free(env_path_z);
    const env_path = try allocator.dupe(u8, env_path_z);
    defer allocator.free(env_path);
    
    var map = try loadEnvFile(allocator, env_path);
    defer freeEnvMap(&map);
    
    try std.testing.expectEqualStrings("value with spaces", map.get("KEY1").?);
    try std.testing.expectEqualStrings("single quoted", map.get("KEY2").?);
    try std.testing.expectEqualStrings("unquoted", map.get("KEY3").?);
}

test "loadEnvFile handles whitespace around keys and values" {
    const allocator = std.testing.allocator;
    
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    
    var io_threaded: std.Io.Threaded = .init_single_threaded;
    const io = io_threaded.io();
    
    const env_content = "  KEY1  =  value1  \n\tKEY2\t=\tvalue2\t\n";
    try tmp.dir.writeFile(io, .{ .sub_path = ".env", .data = env_content });
    
    const env_path_z = try tmp.dir.realPathFileAlloc(io, ".env", allocator);
    defer allocator.free(env_path_z);
    const env_path = try allocator.dupe(u8, env_path_z);
    defer allocator.free(env_path);
    
    var map = try loadEnvFile(allocator, env_path);
    defer freeEnvMap(&map);
    
    try std.testing.expectEqualStrings("value1", map.get("KEY1").?);
    try std.testing.expectEqualStrings("value2", map.get("KEY2").?);
}
