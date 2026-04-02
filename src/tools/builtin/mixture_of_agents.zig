const std = @import("std");
const tools_interface = @import("../interface.zig");
const ToolResult = tools_interface.ToolResult;

pub const MixtureOfAgentsTool = struct {
    pub const SCHEMA = tools_interface.ToolSchema{
        .name = "mixture_of_agents",
        .description = "Run a prompt through multiple models and synthesize results using Mixture of Agents methodology",
        .parameters_schema =
            \\{"type":"object","properties":{"prompt":{"type":"string","description":"Prompt to send to models"},"models":{"type":"array","items":{"type":"string"},"description":"List of model identifiers"}},"required":["prompt","models"]}
        ,
    };

    pub fn execute(self: *MixtureOfAgentsTool, allocator: std.mem.Allocator, args: std.json.ObjectMap) anyerror!ToolResult {
        _ = self;
        const prompt = tools_interface.getString(args, "prompt") orelse return .{ .output = "missing prompt", .is_error = true };
        return .{ .output = try std.fmt.allocPrint(allocator, "MoA stub: Would distribute prompt across models, collect responses, then synthesize via aggregator layer. Prompt: \"{s}\"", .{prompt}) };
    }
};

test "MixtureOfAgentsTool schema" {
    var tool = MixtureOfAgentsTool{};
    const handler = tools_interface.makeToolHandler(MixtureOfAgentsTool, &tool);
    try std.testing.expectEqualStrings("mixture_of_agents", handler.schema.name);
}
