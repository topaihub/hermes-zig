const std = @import("std");

pub const MemoryEntry = struct {
    key: []const u8,
    content: []const u8,
    category: []const u8 = "general",
    timestamp: i64 = 0,
};

pub const Memory = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        store: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator, key: []const u8, content: []const u8, category: []const u8) anyerror!void,
        recall: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator, query: []const u8, limit: u32) anyerror![]MemoryEntry,
        get: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator, key: []const u8) anyerror!?[]const u8,
        forget: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator, key: []const u8) anyerror!void,
        count: *const fn (ptr: *anyopaque) anyerror!u64,
        deinit: *const fn (ptr: *anyopaque) void,
    };

    pub fn store(self: Memory, allocator: std.mem.Allocator, key: []const u8, content: []const u8, category: []const u8) !void {
        return self.vtable.store(self.ptr, allocator, key, content, category);
    }
    pub fn recall(self: Memory, allocator: std.mem.Allocator, query: []const u8, limit: u32) ![]MemoryEntry {
        return self.vtable.recall(self.ptr, allocator, query, limit);
    }
    pub fn get(self: Memory, allocator: std.mem.Allocator, key: []const u8) !?[]const u8 {
        return self.vtable.get(self.ptr, allocator, key);
    }
    pub fn forget(self: Memory, allocator: std.mem.Allocator, key: []const u8) !void {
        return self.vtable.forget(self.ptr, allocator, key);
    }
    pub fn count(self: Memory) !u64 {
        return self.vtable.count(self.ptr);
    }
    pub fn deinit(self: Memory) void {
        self.vtable.deinit(self.ptr);
    }
};
