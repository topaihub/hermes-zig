pub const SkillDefinition = struct {
    name: []const u8 = "",
    description: []const u8 = "",
    body: []const u8 = "",
};

pub fn loadSkill(_: []const u8) ?SkillDefinition {
    return null; // stub
}
