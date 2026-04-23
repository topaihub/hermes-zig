## 1. Runtime Reload Foundation

- [x] 1.1 Extract a shared helper that reloads config, provider, and tool runtime from `config_path`.
- [x] 1.2 Make the reload helper transactional: build new state first, then swap.
- [x] 1.3 Route both first-run setup completion and `/setup` completion through the same runtime reload path.

## 2. Setup Output Consistency

- [x] 2.1 Align setup-generated config with the default model-list semantics used by `/model`.
- [x] 2.2 Align setup-generated config with the default tool-surface semantics used by `/tools`.
- [x] 2.3 Remove or reduce duplicated setup JSON shaping logic where it can drift from the default config baseline.

## 3. Config Path Consistency

- [x] 3.1 Replace duplicate startup config loading with path existence checks or single-load reuse.
- [x] 3.2 Decide and document the authoritative config lookup order.
- [x] 3.3 Make README match the real runtime behavior for packaged and source-run scenarios.

## 4. Verification

- [x] 4.1 Add tests for successful runtime refresh after setup completion.
- [x] 4.2 Add tests for transactional rollback when reload fails.
- [x] 4.3 Add tests for setup-generated model/tool defaults.
- [x] 4.4 Add tests or assertions covering config-path lookup behavior and single-load startup behavior.
