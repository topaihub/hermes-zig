const std = @import("std");
const types = @import("../../core/types.zig");

pub const IncomingMessage = struct {
    source: types.SessionSource,
    content: []const u8,
    reply_to: ?[]const u8 = null,
    timestamp: i64 = 0,
    allocator: ?std.mem.Allocator = null,

    pub fn deinit(self: *IncomingMessage) void {
        if (self.allocator) |a| {
            a.free(self.content);
            if (self.reply_to) |r| a.free(r);
        }
    }
};

pub const SendResult = struct {
    message_id: []const u8 = "",
    allocator: ?std.mem.Allocator = null,

    pub fn deinit(self: *SendResult) void {
        if (self.allocator) |a| {
            if (self.message_id.len > 0) a.free(self.message_id);
        }
    }
};

pub const MessageHandler = struct {
    ctx: *anyopaque,
    handleFn: *const fn (ctx: *anyopaque, msg: IncomingMessage) void,

    pub fn handle(self: MessageHandler, msg: IncomingMessage) void {
        self.handleFn(self.ctx, msg);
    }
};

pub const PlatformAdapter = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        platform: *const fn (ptr: *anyopaque) types.Platform,
        connect: *const fn (ptr: *anyopaque) anyerror!void,
        send: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator, chat_id: []const u8, content: []const u8, reply_to: ?[]const u8) anyerror!SendResult,
        setMessageHandler: *const fn (ptr: *anyopaque, handler: MessageHandler) void,
        deinit: *const fn (ptr: *anyopaque) void,
    };

    pub fn platform(self: PlatformAdapter) types.Platform {
        return self.vtable.platform(self.ptr);
    }
    pub fn connect(self: PlatformAdapter) !void {
        return self.vtable.connect(self.ptr);
    }
    pub fn send(self: PlatformAdapter, allocator: std.mem.Allocator, chat_id: []const u8, content: []const u8, reply_to: ?[]const u8) !SendResult {
        return self.vtable.send(self.ptr, allocator, chat_id, content, reply_to);
    }
    pub fn setMessageHandler(self: PlatformAdapter, handler: MessageHandler) void {
        self.vtable.setMessageHandler(self.ptr, handler);
    }
    pub fn deinit(self: PlatformAdapter) void {
        self.vtable.deinit(self.ptr);
    }
};

pub const MessageQueue = struct {
    mutex: std.Thread.Mutex = .{},
    cond: std.Thread.Condition = .{},
    items: std.ArrayListUnmanaged(IncomingMessage) = .empty,
    closed: bool = false,

    pub fn push(self: *MessageQueue, allocator: std.mem.Allocator, msg: IncomingMessage) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.items.append(allocator, msg) catch return;
        self.cond.signal();
    }

    pub fn pop(self: *MessageQueue, timeout_ns: u64) ?IncomingMessage {
        self.mutex.lock();
        defer self.mutex.unlock();
        while (self.items.items.len == 0 and !self.closed) {
            self.cond.timedWait(&self.mutex, timeout_ns) catch return null;
        }
        if (self.items.items.len == 0) return null;
        return self.items.orderedRemove(0);
    }

    pub fn close(self: *MessageQueue) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.closed = true;
        self.cond.broadcast();
    }

    pub fn deinit(self: *MessageQueue, allocator: std.mem.Allocator) void {
        self.items.deinit(allocator);
    }
};

test "MessageQueue push and pop" {
    const allocator = std.testing.allocator;
    var q = MessageQueue{};
    defer q.deinit(allocator);

    const msg = IncomingMessage{
        .source = .{ .platform = .cli, .chat_id = "test" },
        .content = "hello",
    };
    q.push(allocator, msg);
    const popped = q.pop(1_000_000);
    try std.testing.expect(popped != null);
    try std.testing.expectEqualStrings("hello", popped.?.content);
}

test "MessageQueue pop returns null on timeout" {
    const allocator = std.testing.allocator;
    var q = MessageQueue{};
    defer q.deinit(allocator);
    const result = q.pop(1_000); // 1µs timeout
    try std.testing.expect(result == null);
}

test "MessageQueue close unblocks pop" {
    const allocator = std.testing.allocator;
    var q = MessageQueue{};
    defer q.deinit(allocator);
    q.close();
    const result = q.pop(1_000_000_000);
    try std.testing.expect(result == null);
}
