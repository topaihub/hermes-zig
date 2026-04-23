## ADDED Requirements

### Requirement: Setup 完成后当前进程立即应用新配置

CLI SHALL reload the current process configuration and runtime dependencies after setup completes successfully.

#### Scenario: 首次启动 setup 后立即可用
- **WHEN** 用户在首次启动时完成 setup 向导
- **THEN** 当前进程内的配置被重载
- **AND** 当前 provider 使用新配置重新解析
- **AND** 用户无需重启即可继续聊天

#### Scenario: 命令态 `/setup` 后立即切换到新配置
- **WHEN** 用户在已有会话中运行 `/setup` 并完成配置
- **THEN** 当前进程内的配置被重载
- **AND** 后续对话立即使用新 provider / model / tool runtime

### Requirement: Runtime reload 对当前会话是事务性的

The CLI SHALL preserve the previous working runtime state if reloading the new setup result fails.

#### Scenario: 新配置解析失败时保留旧运行时
- **WHEN** 用户完成 `/setup`
- **AND** 新写入配置无法被成功解析或无法成功构造新 provider / tool runtime
- **THEN** 当前会话继续保留旧的可用配置和 provider
- **AND** 用户得到明确错误
- **AND** 当前会话不会被清空成半初始化状态

### Requirement: 启动路径不重复加载同一份配置

The CLI SHALL avoid loading the same config file multiple times solely to determine whether it exists.

#### Scenario: 已有配置时只走一次有效加载路径
- **WHEN** 启动时目标配置文件已存在
- **THEN** 程序通过路径存在性判断或结果复用进入初始化
- **AND** 不会出现一次“探测性加载”加一次“真实加载”的重复路径

### Requirement: Setup 生成的配置与默认配置语义一致

CLI SHALL generate setup output that preserves the same effective model-list and tool-default semantics as the project's default configuration.

#### Scenario: Setup 产物保留模型列表基础
- **WHEN** setup 成功写出 `config.json`
- **THEN** 配置中包含支持 `/model` 交互选择所需的模型列表基础
- **OR** 以等价方式提供相同的模型切换能力

#### Scenario: Setup 产物保留默认工具面基础
- **WHEN** setup 成功写出 `config.json`
- **THEN** 配置中包含支持 `/tools` 默认启用面所需的工具配置基础
- **AND** 不会因为 setup 产物缺少相关字段而把工具面扩展成意外的更大集合
