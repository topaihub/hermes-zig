## ADDED Requirements

### Requirement: 配置文件查找行为必须被明确且文档一致

The documented config-path behavior SHALL match the actual runtime lookup order.

#### Scenario: README 与运行时路径顺序一致
- **WHEN** 用户查看 README 中的配置路径说明
- **THEN** 文档描述与程序实际查找顺序一致
- **AND** 不存在文档声称支持、但程序实际不会读取的默认路径

### Requirement: 打包运行场景的配置位置是可预期的

The CLI SHALL make it clear where `config.json` is loaded from in packaged executable scenarios.

#### Scenario: exe 相对目录配置优先级明确
- **WHEN** 用户从打包目录运行 `hermes-zig`
- **THEN** 程序和文档都能清楚说明是否优先读取 exe 同目录配置
- **AND** 用户不需要靠试错判断当前生效的是哪份配置
