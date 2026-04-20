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

        var model_list = std.ArrayList(u8){};
        defer model_list.deinit(allocator);

        if (args.get("models")) |models_val| {
            switch (models_val) {
                .array => |arr| {
                    for (arr.items, 0..) |item, i| {
                        switch (item) {
                            .string => |s| {
                                if (i > 0) model_list.appendSlice(allocator, ", ") catch {};
                                model_list.appendSlice(allocator, s) catch {};
                            },
                            else => {},
                        }
                    }
                },
                else => {},
            }
        }

        const models_str = if (model_list.items.len > 0) model_list.items else "(none specified)";

        return .{ .output = try std.fmt.allocPrint(allocator,
            \\[Mixture of Agents]
            \\  Prompt: {s}
            \\  Models: {s}
            \\Pipeline:
            \\  1. Fan-out: Send prompt to each model independently
            \\  2. Collect: Gather all model responses
            \\  3. Aggregate: Synthesize responses via aggregator model
            \\  4. Return: Final synthesized answer
            \\Requires configured LLM providers for each model.
        , .{ prompt, models_str }) };
    }
};

test "MixtureOfAgentsTool schema" {
    var tool = MixtureOfAgentsTool{};
    const handler = tools_interface.makeToolHandler(MixtureOfAgentsTool, &tool);
    try std.testing.expectEqualStrings("mixture_of_agents", handler.schema.name);
}
