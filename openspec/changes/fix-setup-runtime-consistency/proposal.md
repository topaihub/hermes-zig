## Why

`hermes-zig` 的 CLI 命令面最近几轮已经明显产品化了，但 setup 和配置装载链路还存在不一致：

- 首次启动或运行 `/setup`` 后，当前进程不会立即刷新到新配置；
- setup 向导生成的 `config.json` 与默认配置的语义不一致，尤其是 `models` 和 `tools`；
- README 里的配置文件查找路径和实际代码行为不一致。

这类问题不会总是直接导致编译失败，但会让用户在“刚配完、马上就用”的场景下遇到误导和状态漂移。这个 change 目标是把 setup、配置写盘、运行时刷新和文档行为收成一致。

## What Changes

- 让首次 setup 和命令态 `/setup` 完成后，当前进程立即重载配置和 provider。
- 让 setup 触发的 runtime reload 具备事务性，失败时保留旧运行时状态。
- 让 setup 向导生成的配置在模型列表和工具默认面上与项目默认配置保持一致。
- 明确并统一配置文件查找行为与 README 文档。
- 消除启动阶段为判断配置存在而造成的重复加载与资源泄漏。
- 保持现有 `/model`、`/tools`、`/skills` 的命令体验不变，只修复它们依赖的配置基础。

## Capabilities

### New Capabilities
- `setup-runtime-refresh`: setup 完成后以事务性方式把新配置应用到当前 CLI 进程。

### Modified Capabilities
- `interactive-model-switching`: setup 生成的配置要为 `/model` 提供一致的模型列表基础。
- `interactive-tools-configuration`: setup 生成的配置要为 `/tools` 提供一致的默认工具面基础。
- `cli-command-parity`: 文档说明的配置路径与真实命令运行时行为保持一致。

## Impact

- `src/main.zig`: 重构 setup 完成后的运行时刷新路径。
- `src/default_config.json`: 作为 setup 产物语义对齐的参考基线。
- `src/core/config.zig` / `src/core/config_loader.zig`: 确认模型列表和工具配置缺省行为。
- `README.md`: 更新配置路径说明和 setup 行为说明。
