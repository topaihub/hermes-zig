pub const AcpServer = struct {
    pub fn init() AcpServer {
        return .{};
    }
    pub fn deinit(_: *AcpServer) void {}
};
