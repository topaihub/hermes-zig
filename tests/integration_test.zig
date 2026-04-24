const std = @import("std");
const core = @import("../src/core/root.zig");
const agent = @import("../src/agent/root.zig");
const tools = @import("../src/tools/root.zig");

test "Phase 1 Integration: Config + Database + Model Metadata" {
    // 1. 配置系统集成测试
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    
    const config_content =
        \\{
        \\  "provider": "openai",
        \\  "model": "gpt-4",
        \\  "api_key": "sk-test123",
        \\  "providers": {
        \\    "openai": {
        \\      "api_key": "sk-test123",
        \\      "base_url": "https://api.openai.com/v1"
        \\    }
        \\  }
        \\}
    ;
    
    try tmp.dir.writeFile(.{ .sub_path = "config.json", .data = config_content });
    
    // 加载配置
    const tmp_path = try tmp.dir.realpathAlloc(std.testing.allocator, ".");
    defer std.testing.allocator.free(tmp_path);
    const config_path = try std.fs.path.join(std.testing.allocator, &.{ tmp_path, "config.json" });
    defer std.testing.allocator.free(config_path);
    
    var io_threaded: std.Io.Threaded = .init_single_threaded;
    const io = io_threaded.io();
    const cwd = std.Io.Dir.cwd();
    
    var loaded = try core.config.loadConfigFromPath(std.testing.allocator, io, cwd, config_path);
    defer loaded.deinit();
    
    try std.testing.expectEqualStrings("openai", loaded.config.provider);
    try std.testing.expectEqualStrings("gpt-4", loaded.config.model);
    
    // 2. 模型元数据查询
    const metadata = agent.model_metadata.getModelMetadata("gpt-4");
    try std.testing.expect(metadata != null);
    if (metadata) |m| {
        try std.testing.expect(m.context_window > 0);
        try std.testing.expect(m.input_price_per_1m > 0);
    }
    
    // 3. 成本计算
    const cost = agent.usage_pricing.calculateCost("gpt-4", 1000, 500);
    try std.testing.expect(cost > 0);
    
    // 4. 敏感数据脱敏
    const redacted = try agent.redact.redactSensitiveData(std.testing.allocator, "API key: sk-test123");
    defer std.testing.allocator.free(redacted);
    try std.testing.expect(std.mem.indexOf(u8, redacted, "sk-***") != null);
    try std.testing.expect(std.mem.indexOf(u8, redacted, "sk-test123") == null);
}

test "Phase 1 Integration: Database + Tool Messages" {
    // 数据库集成测试
    const db = try core.sqlite.Database.open(":memory:");
    defer db.close();
    
    try core.database.initSchema(db);
    
    // 创建会话
    try core.database.createSession(db, "integration-test", "cli", "gpt-4");
    
    // 添加用户消息
    try core.database.appendMessage(db, "integration-test", "user", "Hello");
    
    // 添加助手消息
    try core.database.appendMessage(db, "integration-test", "assistant", "Hi there!");
    
    // 添加工具消息
    try core.database.appendToolMessage(db, "integration-test", "Tool result", "call_123", "test_tool");
    
    // 验证消息数量
    const count = try core.database.getMessageCount(db, "integration-test");
    try std.testing.expectEqual(@as(i64, 3), count);
}

test "Phase 1 Integration: Tool Registry + Model Tools" {
    // 工具注册表集成测试
    var registry = tools.ToolRegistry.init(std.testing.allocator);
    defer registry.deinit();
    
    // 注册测试工具
    const test_tool = tools.Tool{
        .name = "test_calculator",
        .description = "A test calculator tool",
        .parameters_schema = "{}",
        .execute = struct {
            fn exec(_: std.json.ObjectMap, _: *const tools.ToolContext) anyerror!tools.ToolResult {
                return tools.ToolResult{
                    .output = "42",
                    .success = true,
                };
            }
        }.exec,
    };
    
    try registry.register(test_tool);
    
    // 收集工具 schema
    const schemas = try registry.collectSchemas(std.testing.allocator);
    defer std.testing.allocator.free(schemas);
    
    try std.testing.expectEqual(@as(usize, 1), schemas.len);
    try std.testing.expectEqualStrings("test_calculator", schemas[0].name);
}

test "Phase 1 Integration: Environment + Constants" {
    // 环境变量和常量集成测试
    const hermes_home = try core.constants.getHermesHome(std.testing.allocator);
    defer std.testing.allocator.free(hermes_home);
    
    try std.testing.expect(hermes_home.len > 0);
    
    // 加载 SOUL（应返回默认值，因为文件不存在）
    const soul = try core.soul.loadSoul(std.testing.allocator, "nonexistent-test-dir");
    defer std.testing.allocator.free(soul);
    
    try std.testing.expectEqualStrings(core.soul.DEFAULT_SOUL, soul);
}

test "Phase 1 Integration: Time Utils + Formatting" {
    // 时间工具集成测试
    const timestamp = core.time_utils.getCurrentTimestamp();
    try std.testing.expect(timestamp > 0);
    
    const formatted = try core.time_utils.formatTimestamp(std.testing.allocator, timestamp);
    defer std.testing.allocator.free(formatted);
    
    // 验证 ISO 8601 格式（至少包含日期部分）
    try std.testing.expect(formatted.len >= 10);
    try std.testing.expect(std.mem.indexOf(u8, formatted, "-") != null);
}

test "Phase 1 Integration: Utils + Atomic Write" {
    // 工具函数集成测试
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    
    const tmp_path = try tmp.dir.realpathAlloc(std.testing.allocator, ".");
    defer std.testing.allocator.free(tmp_path);
    const test_file = try std.fs.path.join(std.testing.allocator, &.{ tmp_path, "atomic_test.txt" });
    defer std.testing.allocator.free(test_file);
    
    // 原子写入
    try core.utils.atomicWrite(std.testing.allocator, test_file, "test content");
    
    // 验证文件内容
    const content = try tmp.dir.readFileAlloc(std.testing.allocator, "atomic_test.txt", 1024);
    defer std.testing.allocator.free(content);
    
    try std.testing.expectEqualStrings("test content", content);
}
