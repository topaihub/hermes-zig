const std = @import("std");
const tools_interface = @import("../interface.zig");

fn stubExecute(comptime name: []const u8, comptime desc: []const u8) fn (*anyopaque, []const u8, *const tools_interface.ToolContext) anyerror![]const u8 {
    return struct {
        fn f(self: *anyopaque, args_json: []const u8, ctx: *const tools_interface.ToolContext) anyerror![]const u8 {
            _ = self;
            _ = args_json;
            return std.fmt.allocPrint(ctx.allocator, "[Tinker-Atropos] {s}: {s}", .{ name, desc });
        }
    }.f;
}

fn rlTool(comptime name: []const u8, comptime desc: []const u8, comptime schema: []const u8) type {
    return struct {
        pub const SCHEMA = tools_interface.ToolSchema{ .name = name, .description = desc, .parameters_schema = schema };
        pub fn execute(self: *@This(), args_json: []const u8, ctx: *const tools_interface.ToolContext) anyerror![]const u8 {
            _ = self;
            _ = args_json;
            return std.fmt.allocPrint(ctx.allocator, "[Tinker-Atropos] {s}: {s}", .{ name, desc });
        }
    };
}

pub const RlStartTraining = rlTool("rl_start_training", "Start a reinforcement learning training run",
    \\{"type":"object","properties":{"config":{"type":"string","description":"Training configuration"}},"required":["config"]}
);
pub const RlStopTraining = rlTool("rl_stop_training", "Stop a running training session",
    \\{"type":"object","properties":{"run_id":{"type":"string","description":"Training run ID"}},"required":["run_id"]}
);
pub const RlCheckStatus = rlTool("rl_check_status", "Check status of a training run",
    \\{"type":"object","properties":{"run_id":{"type":"string","description":"Training run ID"}},"required":["run_id"]}
);
pub const RlGetResults = rlTool("rl_get_results", "Retrieve results from a completed training run",
    \\{"type":"object","properties":{"run_id":{"type":"string","description":"Training run ID"}},"required":["run_id"]}
);
pub const RlListEnvironments = rlTool("rl_list_environments", "List available RL training environments",
    \\{"type":"object","properties":{}}
);
pub const RlSelectEnvironment = rlTool("rl_select_environment", "Select an RL environment for training",
    \\{"type":"object","properties":{"env_name":{"type":"string","description":"Environment name"}},"required":["env_name"]}
);
pub const RlEditConfig = rlTool("rl_edit_config", "Edit RL training configuration parameters",
    \\{"type":"object","properties":{"key":{"type":"string","description":"Config key"},"value":{"type":"string","description":"Config value"}},"required":["key","value"]}
);

test "RL training tool schemas" {
    inline for (.{ RlStartTraining, RlStopTraining, RlCheckStatus, RlGetResults, RlListEnvironments, RlSelectEnvironment, RlEditConfig }) |T| {
        var tool = T{};
        const handler = tools_interface.makeToolHandler(T, &tool);
        try std.testing.expect(handler.schema.name.len > 0);
    }
}
