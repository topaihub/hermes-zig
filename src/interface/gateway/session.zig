const std = @import("std");
const types = @import("../../core/types.zig");

pub const SessionRouter = struct {
    pub fn route(_: SessionRouter, platform: types.Platform, chat_id: []const u8) []const u8 {
        _ = platform;
        return chat_id; // stub: returns chat_id as session_id
    }
};
