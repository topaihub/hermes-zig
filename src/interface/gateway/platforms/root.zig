const std = @import("std");
const types = @import("../../../core/types.zig");
const platform = @import("../platform.zig");

pub const telegram = @import("telegram.zig");
pub const discord = @import("discord.zig");
pub const slack = @import("slack.zig");
pub const whatsapp = @import("whatsapp.zig");
pub const signal = @import("signal.zig");
pub const email = @import("email.zig");
pub const matrix = @import("matrix.zig");
pub const feishu = @import("feishu.zig");
pub const dingtalk = @import("dingtalk.zig");
pub const wecom = @import("wecom.zig");
pub const homeassistant = @import("homeassistant.zig");
pub const sms = @import("sms.zig");
pub const mattermost = @import("mattermost.zig");
pub const webhook = @import("webhook.zig");
pub const api_server = @import("api_server.zig");
pub const telegram_network = @import("telegram_network.zig");

pub const TelegramAdapter = telegram.TelegramAdapter;
pub const DiscordAdapter = discord.DiscordAdapter;
pub const SlackAdapter = slack.SlackAdapter;
pub const WhatsAppAdapter = whatsapp.WhatsAppAdapter;
pub const SignalAdapter = signal.SignalAdapter;
pub const EmailAdapter = email.EmailAdapter;
pub const MatrixAdapter = matrix.MatrixAdapter;
pub const FeishuAdapter = feishu.FeishuAdapter;
pub const DingtalkAdapter = dingtalk.DingtalkAdapter;
pub const WecomAdapter = wecom.WecomAdapter;
pub const HomeAssistantAdapter = homeassistant.HomeAssistantAdapter;
pub const SmsAdapter = sms.SmsAdapter;
pub const MattermostAdapter = mattermost.MattermostAdapter;
pub const WebhookAdapter = webhook.WebhookAdapter;
pub const ApiServerAdapter = api_server.ApiServerAdapter;
pub const TelegramNetwork = telegram_network.TelegramNetwork;

comptime {
    @import("std").testing.refAllDecls(@This());
}

test "all 14 adapters return correct platform enum" {
    const TestCase = struct { adapter: platform.PlatformAdapter, expected: types.Platform };

    var tg = TelegramAdapter{};
    var dc = DiscordAdapter{ .bot_token = "", .guild_id = "" };
    var sl = SlackAdapter{ .bot_token = "", .signing_secret = "" };
    var wa = WhatsAppAdapter{ .phone_number_id = "", .access_token = "" };
    var sg = SignalAdapter{ .account = "", .http_url = "" };
    var em = EmailAdapter{ .imap_host = "", .smtp_host = "", .username = "" };
    var mx = MatrixAdapter{ .homeserver = "", .access_token = "" };
    var fs = FeishuAdapter{ .app_id = "", .app_secret = "" };
    var dt = DingtalkAdapter{ .client_id = "", .client_secret = "" };
    var wc = WecomAdapter{ .bot_id = "", .secret = "" };
    var ha = HomeAssistantAdapter{ .ha_url = "", .token = "" };
    var sm = SmsAdapter{ .account_sid = "", .auth_token = "", .from_number = "" };
    var mm = MattermostAdapter{ .server_url = "", .bot_token = "" };
    var wh = WebhookAdapter{ .listen_port = 0, .secret = "" };

    const cases = [_]TestCase{
        .{ .adapter = tg.adapter(), .expected = .telegram },
        .{ .adapter = dc.adapter(), .expected = .discord },
        .{ .adapter = sl.adapter(), .expected = .slack },
        .{ .adapter = wa.adapter(), .expected = .whatsapp },
        .{ .adapter = sg.adapter(), .expected = .signal },
        .{ .adapter = em.adapter(), .expected = .email },
        .{ .adapter = mx.adapter(), .expected = .matrix },
        .{ .adapter = fs.adapter(), .expected = .feishu },
        .{ .adapter = dt.adapter(), .expected = .dingtalk },
        .{ .adapter = wc.adapter(), .expected = .wecom },
        .{ .adapter = ha.adapter(), .expected = .homeassistant },
        .{ .adapter = sm.adapter(), .expected = .sms },
        .{ .adapter = mm.adapter(), .expected = .mattermost },
        .{ .adapter = wh.adapter(), .expected = .webhook },
    };

    for (cases) |tc| {
        try std.testing.expectEqual(tc.expected, tc.adapter.platform());
    }
}
