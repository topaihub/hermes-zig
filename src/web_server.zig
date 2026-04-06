const std = @import("std");
const net = std.net;
const http = std.http;

const html_content = @embedFile("web_config.html");

pub const WebConfigServer = struct {
    allocator: std.mem.Allocator,
    port: u16 = 8318,
    config_path: []const u8 = "config.json",
    running: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
    listener: ?net.Server = null,

    pub fn start(self: *WebConfigServer) void {
        const addr = net.Address.parseIp("127.0.0.1", self.port) catch return;
        var server = addr.listen(.{ .reuse_address = true }) catch return;
        self.listener = server;
        self.running.store(true, .release);
        defer {
            if (self.listener != null) {
                server.deinit();
                self.listener = null;
            }
        }

        while (self.running.load(.acquire)) {
            const conn = server.accept() catch |err| {
                if (!self.running.load(.acquire) or err == error.ConnectionAborted or err == error.Unexpected) {
                    return;
                }
                return;
            };
            self.handleConnection(conn.stream) catch {};
            conn.stream.close();
        }
    }

    pub fn stop(self: *WebConfigServer) void {
        self.running.store(false, .release);
        const addr = net.Address.parseIp("127.0.0.1", self.port) catch return;
        const stream = net.tcpConnectToAddress(addr) catch return;
        stream.close();
    }

    fn handleConnection(self: *WebConfigServer, stream: net.Stream) !void {
        var read_buf: [8192]u8 = undefined;
        var write_buf: [8192]u8 = undefined;
        var net_reader = net.Stream.Reader.init(stream, &read_buf);
        var net_writer = net.Stream.Writer.init(stream, &write_buf);

        var server = http.Server.init(net_reader.interface(), &net_writer.interface);
        var req = server.receiveHead() catch return;

        const target = req.head.target;
        const method = req.head.method;

        if (method == .GET and std.mem.eql(u8, target, "/")) {
            try req.respond(html_content, .{
                .extra_headers = &.{.{ .name = "content-type", .value = "text/html; charset=utf-8" }},
                .keep_alive = false,
            });
        } else if (method == .GET and std.mem.eql(u8, target, "/api/config")) {
            const data = readConfigFileAlloc(self.allocator, self.config_path, 1024 * 1024) catch |err| {
                const msg = if (err == error.FileNotFound) "{}" else "{\"error\":\"read failed\"}";
                try req.respond(msg, .{
                    .extra_headers = &.{.{ .name = "content-type", .value = "application/json" }},
                    .keep_alive = false,
                });
                return;
            };
            defer self.allocator.free(data);
            try req.respond(data, .{
                .extra_headers = &.{.{ .name = "content-type", .value = "application/json" }},
                .keep_alive = false,
            });
        } else if (method == .POST and std.mem.eql(u8, target, "/api/config")) {
            const content_len = req.head.content_length orelse 0;
            if (content_len > 0 and content_len <= 1024 * 1024) {
                var body_buf: [4096]u8 = undefined;
                const body_reader = req.readerExpectNone(&body_buf);
                const body = body_reader.readAlloc(self.allocator, 1024 * 1024) catch {
                    try req.respond("{\"error\":\"read body failed\"}", .{
                        .status = .bad_request,
                        .extra_headers = &.{.{ .name = "content-type", .value = "application/json" }},
                        .keep_alive = false,
                    });
                    return;
                };
                defer self.allocator.free(body);

                var file = createConfigFile(self.config_path) catch {
                    try req.respond("{\"error\":\"write failed\"}", .{
                        .status = .internal_server_error,
                        .extra_headers = &.{.{ .name = "content-type", .value = "application/json" }},
                        .keep_alive = false,
                    });
                    return;
                };
                defer file.close();
                file.writeAll(body) catch {
                    try req.respond("{\"error\":\"write failed\"}", .{
                        .status = .internal_server_error,
                        .extra_headers = &.{.{ .name = "content-type", .value = "application/json" }},
                        .keep_alive = false,
                    });
                    return;
                };
                try req.respond("{\"ok\":true}", .{
                    .extra_headers = &.{.{ .name = "content-type", .value = "application/json" }},
                    .keep_alive = false,
                });
            } else {
                try req.respond("{\"ok\":true}", .{
                    .extra_headers = &.{.{ .name = "content-type", .value = "application/json" }},
                    .keep_alive = false,
                });
            }
        } else if (method == .POST and std.mem.eql(u8, target, "/api/test")) {
            try req.respond("{\"ok\":true,\"message\":\"Connection test placeholder\"}", .{
                .extra_headers = &.{.{ .name = "content-type", .value = "application/json" }},
                .keep_alive = false,
            });
        } else if (method == .GET and std.mem.eql(u8, target, "/api/status")) {
            try req.respond("{\"status\":\"ok\"}", .{
                .extra_headers = &.{.{ .name = "content-type", .value = "application/json" }},
                .keep_alive = false,
            });
        } else {
            try req.respond("Not Found", .{
                .status = .not_found,
                .keep_alive = false,
            });
        }
    }
};

fn createConfigFile(config_path: []const u8) !std.fs.File {
    if (std.fs.path.isAbsolute(config_path)) {
        return std.fs.createFileAbsolute(config_path, .{});
    }
    return std.fs.cwd().createFile(config_path, .{});
}

fn readConfigFileAlloc(allocator: std.mem.Allocator, config_path: []const u8, max_bytes: usize) ![]u8 {
    if (std.fs.path.isAbsolute(config_path)) {
        const file = try std.fs.openFileAbsolute(config_path, .{});
        defer file.close();
        return file.readToEndAlloc(allocator, max_bytes);
    }
    return std.fs.cwd().readFileAlloc(allocator, config_path, max_bytes);
}

test "WebConfigServer struct init" {
    var server = WebConfigServer{
        .allocator = std.testing.allocator,
    };
    try std.testing.expectEqual(@as(u16, 8318), server.port);
    try std.testing.expectEqualStrings("config.json", server.config_path);
    try std.testing.expectEqual(false, server.running.load(.acquire));
}
