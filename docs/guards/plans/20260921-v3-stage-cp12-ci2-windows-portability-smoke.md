# CP12-ci2 — Windows portability smoke 与 P11.4 全量认证（D35）

本 pair 是 Plan 06 在 P11.4 真实 PR 前插入的 CI 成本检查点。它保留 13 个 required checks 及其 ruleset 身份，把普通运行中重复的 Windows head candidate 全量套件缩为受契约约束的 portability smoke；Ubuntu 继续提供每次运行的完整候选验证，P11.4 再提供一次 Windows 全量认证。

本变更消费并删除 base 中的 `cp12-ci2-trusted-base.json` 与 `cp12-ci2-weaken-policy.json`；两条记录分别精确覆盖 TCB 与已登记 policy 变化。

## 1. 度量与范围

- 最近真实 CI 的 `v3-cross-platform-windows-latest` 为 15.70 分钟，其中 head candidate step 为 14.17 分钟；Ubuntu leg 仍运行完整套件。
- 本地尝试把完整 trusted-base diff-consumption 测试加入 smoke，超过 3 分钟仍未结束并中止；它保留在 Ubuntu full 与 P11.4 Windows full。
- 候选实现完成后的本机 Windows 精确 smoke 为 243.20 秒：前四项 Generate/Check 合计约 3 秒、锁定构建基线 20.11 秒、target-root 隔离 220.19 秒；相对最近真实 Windows head candidate 的 14.17 分钟，预期该步骤缩短约 71%，最终以本 PR 的 hosted runner 数据为准。
- 不删除、不改名 required check，不改 job DAG、事件集合、ruleset contexts 或 strict 策略；不增加 job 级条件。
- D28 的 concurrency、cache、monthly schedule 与 base-owned `records-and-plans` 判定继续有效。

## 2. 实现

- 普通 Windows head candidate smoke 精确运行：V3 Generate/Check、IFX Generate/Check、`Test-V3BuildBaseline.ps1`、`Test-IFXTargetRootSeparation.ps1`；base-owned `Validate` 始终先运行。
- Ubuntu leg 精确保留当前完整 head candidate suite。
- `workflow_dispatch` 增加 `windowsCoverage`（`smoke`/`full`，默认 `smoke`）；P11.4 使用 `full`，使 Windows 选择完整 suite。
- `ci/jobs.json` 声明 required check、runner、smoke/full 命令集合和 P11.4 full 入口；`Invoke-IFXCiContract.ps1` 只读验证；`Test-IFXCiContract.ps1` 增加负向控制。
- `tcb.activation.ci` parity contract 明确普通运行与最终认证的证据边界。

## 3. 验收

1. CI contract 正向用例通过，并能拒绝缺少 locked build baseline 的 Windows smoke、缺少 trusted-base candidates 的 full suite、非 Windows 选择 smoke、删除 full dispatch option。
2. package/manifest 测试通过，受保护变更由精确的 `change-trusted-base` 与 `weaken-policy` 授权覆盖。
3. 以 `codex/guards-principles-plan` 为 base 的真实 PR 上 13 个 required checks 全部通过；记录 Windows smoke 实际时长。
4. P11.4 最终候选以 `workflow_dispatch`、`windowsCoverage=full` 通过并保存 Windows 全量证据。

## 4. 回退

回退到每次 Windows 全量运行会再次修改已登记 CI policy 和 TCB，必须走新的授权。若 smoke/full 声明、选择逻辑或 full dispatch 入口漂移，CI contract 失败关闭。
