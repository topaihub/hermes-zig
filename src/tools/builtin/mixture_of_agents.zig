const std = @import("std");
const tools_interface = @import("../interface.zig");

pub const MixtureOfAgentsTool = struct {
    pub const SCHEMA = tools_interface.ToolSchema{
        .name = "mixture_of_agents",
        .description = "Run a prompt through multiple models and synthesize results using Mixture of Agents methodology",
        .parameters_schema =
            \\{"type":"object","properties":{"prompt":{"type":"string","description":"Prompt to send to models"},"models":{"type":"array","items":{"type":"string"},"description":"List of model identifiers"}},"required":["prompt","models"]}
        ,
    };

    pub fn execute(self: *MixtureOfAgentsTool, args_json: []const u8, ctx: *const tools_interface.ToolContext) anyerror![]const u8 {
        _ = self;
        const parsed = std.json.parseFromSlice(struct { prompt: []const u8 = "" }, ctx.allocator, args_json, .{ .ignore_unknown_fields = true }) catch
            return error.InvalidArgs;
        defer parsed.deinit();
        return std.fmt.allocPrint(ctx.allocator, "MoA stub: Would distribute prompt across models, collect responses, then synthesize via aggregator layer. Prompt: \"{s}\"", .{parsed.value.prompt});
    }
};

test "MixtureOfAgentsTool schema" {
    var tool = MixtureOfAgentsTool{};
    const handler = tools_interface.makeToolHandler(MixtureOfAgentsTool, &tool);
    try std.testing.expectEqualStrings("mixture_of_agents", handler.schema.name);
}
