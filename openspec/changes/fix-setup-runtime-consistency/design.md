## Context

当前 `hermes-zig` 的大部分 CLI 命令已经有真实交互行为，但 setup 仍然保留着较早期的实现方式：

- 启动时只在进入主循环前解析一次 `cfg`、provider、tools runtime；
- `runSetupWizard` 负责写盘，但不负责把结果重新注入当前运行时；
- setup 使用手工拼接 JSON，内容和 `default_config.json` 逐渐出现漂移；
- README 对配置路径的说明没有跟上后来加入的 exe 相对路径行为。

这些问题都属于“功能已经存在，但基础语义不一致”的范畴，适合通过一次一致性修复集中收口。

## Goals / Non-Goals

**Goals:**
- setup 完成后当前进程立刻使用新配置。
- 首次启动 setup 和命令态 `/setup` 使用同一套刷新逻辑。
- runtime reload 失败时保留旧状态，不破坏当前会话。
- setup 生成的配置保留与默认配置一致的模型列表/工具默认语义。
- 启动阶段避免为判断配置存在而重复加载同一份配置。
- 文档和真实配置路径行为一致。

**Non-Goals:**
- 重做整个 setup UX。
- 增加远程模型发现或 provider 拉取。
- 引入新的配置存储位置策略，如果当前 exe-relative 行为被保留，则本 change 只要求文档与之对齐。

## Decisions

### Decision 1: Setup 完成后必须显式重载运行时

`runSetupWizard` 不应只负责写盘。命令完成后需要有一个显式的“reload current runtime from config path”步骤，用来更新：

1. `cfg`
2. resolved provider
3. tools runtime
4. 可能依赖配置的会话级状态

Alternatives considered:
- 让用户手动重启程序。
  Rejected，因为这会让 setup 看起来“保存了但没生效”。

### Decision 1a: Runtime reload 必须是事务性的

reload 不能采用“先清空旧状态，再尝试加载新状态”的顺序。正确顺序应为：

1. 先构造新的 `LoadedConfig`
2. 先构造新的 provider
3. 先验证或构造新的 tool runtime 状态
4. 全部成功后再替换旧状态

这保证新配置损坏、provider 解析失败或 runtime 构造失败时，当前会话仍然保留旧的可用状态。

Alternatives considered:
- 先释放旧状态，再尝试加载新状态。
  Rejected，因为失败时会把当前会话打坏。

### Decision 2: Setup 产物语义以默认配置为准

setup 向导不应再维护一份独立演化的“手工 JSON 模板”。它生成出来的配置至少要和默认配置在这些方面保持一致：

- `models`
- `tools.enabled_toolsets`
- 其他对 `/model` 和 `/tools` 可见面有直接影响的字段

Alternatives considered:
- 接受 setup 和默认配置并存两套语义。
  Rejected，因为这会持续制造“首次 setup 用户”和“手工配置用户”的行为差异。

### Decision 3: 配置路径策略要么统一实现，要么统一文档

当前实现优先读取 exe 同目录，再回退当前目录。设计上必须明确这一点，并要求 README 与之对齐；如果后续决定加入 `~/.hermes/config.json` 回退，也需要一起修改代码和文档，而不能只改一边。

Alternatives considered:
- 先只修 README 或先只修代码。
  Rejected，因为用户可见行为和文档必须同时收口。

### Decision 4: 启动阶段配置存在性判断不能依赖重复解析

启动流程不应为了判断配置是否存在而先成功加载一次、再在真正初始化时加载第二次。应使用路径存在性判断或单次加载结果复用。

Alternatives considered:
- 先加载一遍只用于“判断存在”，随后再加载真正结果。
  Rejected，因为它会引入重复 I/O 和资源生命周期风险。

## Risks / Trade-offs

- setup 完成后热重载 provider 可能触发资源替换顺序问题。
  Mitigation: 使用事务性 reload helper，先构造新状态，再一次性提交替换。

- setup 产物向默认配置靠拢，可能让最小配置文件变长。
  Mitigation: 优先保证语义一致，之后再考虑是否抽成更紧凑但等价的生成方式。

- 配置路径行为如果选择保留 exe-relative 优先，README 会和更早版本不同。
  Mitigation: 在文档里明确“打包 exe 场景”的优先级，这是当前更符合用户预期的行为。

- 如果重复加载逻辑没有完全消除，仍可能留下解析结果泄漏。
  Mitigation: 启动路径改成单次加载或显式复用首次加载结果。

## Migration Plan

1. 抽出“从 config_path 事务性重载运行时”的共享逻辑。
2. 移除启动阶段为判断配置存在而做的重复加载。
3. 把首次 setup 和命令态 `/setup` 都接到同一条 reload 逻辑上。
4. 对齐 setup 生成的配置字段与默认配置语义。
5. 更新 README 中的配置路径说明。
6. 增加测试覆盖事务性 reload、单次加载、模型列表、默认工具面和配置路径说明。

Rollback strategy:
- 若热重载链路不稳定，可临时保留写盘成功，但明确提示“请重启以生效”；不过这只是回滚策略，不是目标状态。
