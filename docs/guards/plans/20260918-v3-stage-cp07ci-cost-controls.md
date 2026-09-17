# CP07-ci — CI 成本控制与 base 判定的变更范围（D28）

本 pair 是 [正式 Plan pair](20260916-v3-stage-oriented-package-refactor.md) 检查点 CP07-ci 的变更 PR，按 D28 在不改变任何 gate 证明内容的前提下降低 Actions 成本。它消费 `20260918-v3-stage-cp07ci-authorization` 加入的两条正交授权：

- `change-trusted-base`：`tcb.activation.ci`、`tcb.engine.trusted-base` 与 `tcb.validation.package-tests` 的变化；
- `weaken-policy`：`ci/jobs.json` 与新增 `contracts/change-scope.schema.json` 的语义变化。

## 1. 度量（2026-09-17，私有仓库计费）

单次 PR 运行 73–75 计费分钟：Windows leg 30（2×）、`v3-architecture` 13、Ubuntu leg 10、`v3-quality-solution` 6、`v3-specialized-database` 5，其余 8 个 job 合计 9。耗时几乎全在 .NET restore/build/test：head candidate 步骤（Windows 804s、Ubuntu 508s）与 `Test-IFXPackage`（664s）。此前无 package cache、无 concurrency 取消。Windows leg 的时间正好花在平台敏感脚本上，因此不做裁剪。

## 2. 变更

- `.github/workflows/v3-ifx-guardrails.yml`：
  - 顶层 `concurrency` 按 PR 取消被替代的运行；
  - `v3-architecture`、`v3-quality-solution`、`v3-specialized-database` 与两条 `v3-cross-platform` leg 增加 `actions/cache@v4`，缓存 `~/.nuget/packages`，key 由已评审 lock 文件派生（locked restore 仍校验 assets 与 content hash，被污染的缓存失败关闭）；
  - 再验证 schedule 由每周改为每月；
  - `v3-architecture` 与两条 `v3-cross-platform` leg 增加 base 判定步骤（`Invoke-IFXTrustedBase.ps1 -Mode Scope`，`continue-on-error`），并在 base 判定为 `records-and-plans` 时跳过 head candidate 步骤；
- `trusted-base/Get-IFXChangeScope.ps1`（新增，经 runner 的 `Scope` 模式调用；workflow 只引用 base 已有的 runner，因为 manifest check 要求 workflow 引用的脚本存在于 base package，判定步骤 `continue-on-error`，旧 base 或任何失败都导致完整运行）：base 判定 verified changed set。`records-and-plans` 表示 merge base 到明确 head 之间的每个路径都是 formal plan、authorization record 或 decision record；空变更集、无法识别的路径与任何失败都是 `full`；
- `trusted-base/Invoke-IFXTrustedBase.ps1`：新增 `-Mode Scope` 与 `-GitHubOutput`（只输出判定结果）；带 `-HeadRef` 时记录 `change-scope` 检查；`records-and-plans` 时 `v3-architecture`、三个 quality 与 `v3-specialized-database` 以 `guardrails: skipped` 继承 base 判定；`v3-pre-diff`、Validate、Pre、HistoricalIntegrity 与 G03/G04/G05/Plan04 始终运行；
- `ci/jobs.json`：声明 `costControls` 与 `changeScope`；
- `ci/Invoke-IFXCiContract.ps1`：只读校验 workflow 与声明一致（concurrency、schedule、cache key、判定入口必须是从 `$env:GUARD_BASE` 调用 runner 的 `Scope` 模式、`continue-on-error`、跳过条件、可继承 check 必须是已声明 job）；
- `tests/Test-IFXCiContract.ps1`：新增 13 个负向用例；
- `tests/Test-IFXTrustedBase.ps1`：新增 13 个用例，默认套件与 `-ChangeScopeOnly` 都运行（CI 的 cross-platform leg 运行默认套件）。

13 个 required check 名称、job DAG、trigger 语义、ruleset 与 strict 策略均不变；没有任何 job 变为条件执行。

## 3. 验证方式

- `Test-IFXCiContract.ps1` 通过（含新增负向）；`Invoke-IFXCiContract.ps1 -Remote` 只读核对远端 ruleset 仍与声明一致；
- `Test-IFXTrustedBase.ps1`（默认套件与 `-ChangeScopeOnly`）通过：plan/record 变更判定为 `records-and-plans`，engine 变更与混合变更判定为 `full`，错误 base 与空变更集失败关闭为 `full`，runner 的 `Scope` 模式输出判定并在缺少 `-HeadRef` 时失败，Quality 继承 base 判定并记录原因，Validate 始终运行；
- `Test-IFXManifests.ps1` 通过；
- `v3-pre-diff` 报告 1 个 trusted-component-change 与 2 个 policy-weakening 义务，由两条授权恰好覆盖；只消费其中一条的变更失败（本地模拟）；
- 合入后首个 PR 的实际计费分钟将与本文度量对比并记录。

## 4. 与 Plan 06 文字的差异

| Plan 06 描述 | 实际实现 | 理由 |
| --- | --- | --- |
| §10.3 workflow 只描述 13 个 required check 与 job DAG | 增加成本控制与 base 判定的变更范围，check 名称与 DAG 不变 | Actions 配额不足以完成剩余计划（D28，用户于 2026-09-18 批准） |
| P9 轻量 workflow candidate | 本次只改 active workflow 的成本控制，不引入 candidate/Preview/Verify | P9 仍按原计划执行 |

## 5. 回退

还原本 pair 会再次修改 `tcb.activation.ci`、`tcb.engine.trusted-base` 与已登记 policy，需要新的 `change-trusted-base` 与 `weaken-policy` 授权；`records-and-plans` 判定失败关闭，回退只会让运行更贵，不会降低门禁强度。
