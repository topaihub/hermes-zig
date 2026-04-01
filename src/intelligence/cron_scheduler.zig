pub const CronScheduler = struct {
    pub fn init() CronScheduler {
        return .{};
    }
    pub fn deinit(_: *CronScheduler) void {}
};
