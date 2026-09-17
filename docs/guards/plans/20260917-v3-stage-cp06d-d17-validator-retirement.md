# CP06d — Plan 06 P4（五）：第一次真实受保护删除（D17 Plan04 阶段校验脚本退役）

本 pair 是 [正式 Plan pair](20260916-v3-stage-oriented-package-refactor.md) 检查点 CP06d 的变更 PR，按 [Plan 06](06-v3-stage-oriented-package-refactor.md) §17 D17 删除四个 Plan04 阶段校验脚本。这是第一次通过 P4 授权机制完成的真实受保护删除。它消费 `20260917-v3-stage-cp06d-authorization` 加入的五条正交授权：

- 四条 `delete`：每个被删除的受保护路径各一条，记录 source 的 base tree entry；
- 一条 `change-trusted-base`：覆盖 `tcb.engine.specialized` 的变化，四个 head tuple 为 null。

## 1. 变更

删除 `docs/guards/V3_ifx/specialized/scripts/` 下的：

- `Test-Plan04Documentation.ps1`
- `Test-Plan04Phase0Baseline.ps1`
- `Test-Plan04Phase1Inventory.ps1`
- `Test-Plan04Phase2Audit.ps1`

依据 D17，这四个脚本从任何入口不可达（DRIFT-09），其中三个在基线上失败，四个默认改写 `docs/architecture/review/evidence/plan04` 下的冻结证据。它们的能力已由 `v3-specialized-plan04` gate 运行的 `Test-Plan04Governance.ps1` 覆盖。

仓库中没有运行时引用：

- 冻结证据（`docs/architecture/review/evidence/plan04`、`plan05`）、历史 plan 与 P0 基线（`analysis/ifx/refactor-baseline`、`legacy-deletion-manifest.json`）中的名称是历史记录，保持不变；
- `tcb.engine.specialized` 以目录登记 `specialized/scripts/`，manifest 不需要修改。

## 2. 验证方式

`v3-pre-diff` 的保护义务报告应列出 5 个义务（4 个 protected-removal 与 1 个 trusted-component-change）与 5 条被消费的授权。候选验证运行 `tcb.engine.specialized` 的 base-owned validation 与固定语料 parity。只消费 `delete` 或只消费 `change-trusted-base` 的变更都应失败（本地模拟）。

## 3. 与 Plan 06 文字的差异

无。D17 中“待 P4 授权机制可用后通过 base 预授权删除”由本 PR 执行。

## 4. 回退

恢复这四个文件是对受保护路径的新增，属于 `tcb.engine.specialized` 的变化，需要新的 `change-trusted-base` 授权。
