# P2.8 — Trusted base 机制生效验证

本 pair 记录 [Plan 06](06-v3-stage-oriented-package-refactor.md) P2.8 与 D19 要求的验证：CP04d（PR #36，`a714716`）把全部 required check 切换为 base runner 并声明 `trustedBase` 生效后，下一个 PR 上的 TCB 候选验证与 CI 激活契约必须真实阻断。本 pair 只修改计划文档，不修改任何 TCB 组件，因此本 PR 自身也证明无 TCB 变更时候选验证通过。

## 1. 负向 draft PR

两个负向控制分开提交，因为 Validate 失败会使同一 job 中其后的候选验证 step 不再执行。两个 PR 均为 draft、标题注明 DO NOT MERGE，基于 CP04d 合入后的 `a714716`，验证后关闭未合入并删除分支。

| PR | Head 变更 | 结果 |
| --- | --- | --- |
| [#37](https://github.com/von12549/IFX/pull/37)（run [35171740874](https://github.com/von12549/IFX/actions/runs/35171740874)） | `history/Invoke-IFXHistoricalIntegrity.ps1` 增加一行注释，无 `change-trusted-base` 授权 | 仅 `v3-cross-platform-ubuntu-latest` 失败：`Validate from the trusted base` 通过，`Verify trusted component candidates` 输出 `FAIL Trusted component changes require a base change-trusted-base authorization for: tcb.engine.historical-integrity`；其余 12 个 check 通过 |
| [#38](https://github.com/von12549/IFX/pull/38)（run [35171742765](https://github.com/von12549/IFX/actions/runs/35171742765)） | `v3-historical-integrity` 改为从 checkout 原位运行 `Invoke-IFXGuardrails.ps1` | `v3-architecture`、`v3-cross-platform-ubuntu-latest`、`v3-cross-platform-windows-latest` 的 base Validate 失败：`FAIL trusted-base-no-head-dispatcher:v3-historical-integrity` 与 `FAIL trusted-base-runner:v3-historical-integrity`；依赖 `v3-architecture` 的 specialized job 被跳过；被绕过的 `v3-historical-integrity` 本身通过，说明该绕过必须由 CI 契约拦截 |

两个结果均与提交前从 base worktree 的本地预演一致。

## 2. 结论

- TCB 候选验证与 CI 激活契约由 base commit 的 `ci/jobs.json` 激活，在 CP04d 之后的 PR 上生效并阻断；
- §11.6 首次引入例外已按 D19 用尽，此后 TCB 组件变更（含 workflow、`ci/jobs.json`、manifest、engine、测试与构建基线）一律需要 base 中已存在、由变更 PR 删除的 `change-trusted-base` 授权；
- Plan 06 勾选 P2.8，P2 全部完成；plan pair 记录 CP04d 合入。

## 3. 验证

本 PR 的 13 个 required check 由切换后的 workflow 运行；本 PR 不修改 TCB 组件，`Verify trusted component candidates` 应通过（无 TCB 变更）。

## 4. 回退

还原本 pair 列出的计划文档。
