pub const Platform = enum {
    telegram,
    discord,
    slack,
    whatsapp,
    signal,
    email,
    matrix,
    feishu,
    dingtalk,
    wecom,
    homeassistant,
    sms,
    mattermost,
    webhook,
    cli,

    pub fn displayName(self: Platform) []const u8 {
        return switch (self) {
            .telegram => "Telegram",
            .discord => "Discord",
            .slack => "Slack",
            .whatsapp => "WhatsApp",
            .signal => "Signal",
            .email => "Email",
            .matrix => "Matrix",
            .feishu => "飞书",
            .dingtalk => "钉钉",
            .wecom => "企业微信",
            .homeassistant => "Home Assistant",
            .sms => "SMS",
            .mattermost => "Mattermost",
            .webhook => "Webhook",
            .cli => "CLI",
        };
    }
};

pub const Role = enum { system, user, assistant, tool };

pub const Message = struct {
    role: Role = .user,
    content: []const u8 = "",
    tool_call_id: ?[]const u8 = null,
    name: ?[]const u8 = null,
};

pub const ToolCall = struct {
    id: []const u8 = "",
    name: []const u8 = "",
    arguments: []const u8 = "",
};

pub const TokenUsage = struct {
    prompt_tokens: u32 = 0,
    completion_tokens: u32 = 0,
    total_tokens: u32 = 0,
};

pub const SessionSource = struct {
    platform: Platform,
    chat_id: []const u8,
    user_id: ?[]const u8 = null,
    thread_id: ?[]const u8 = null,
    platform_metadata: ?[]const u8 = null,
};

pub const VALID_REASONING_EFFORTS = [_][]const u8{ "xhigh", "high", "medium", "low", "minimal" };

pub const OPENROUTER_BASE_URL = "https://openrouter.ai/api/v1";
pub const NOUS_API_BASE_URL = "https://inference-api.nousresearch.com/v1";
pub const OPENAI_BASE_URL = "https://api.openai.com/v1";
pub const ANTHROPIC_BASE_URL = "https://api.anthropic.com";
