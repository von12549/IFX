# CP05a-change — 授权记录消费修复（消费 CP05a-auth 授权，需一次性 break-glass）

本 pair 是 [正式 Plan pair](20260916-v3-stage-oriented-package-refactor.md) 检查点 CP05a 的第二个 PR（修复 PR），实施 D20，并消费 `20260917-v3-stage-cp05a-authorization` 加入的 `stages/diff/authorizations/cp05a-authorization-consumption.json`。

## 1. 变更

- `templates/dotnet/GuardTests.cs.in` 与 `generated/stages/GuardTests.cs`：Diff 读取 `GUARD_CONSUMED_AUTHORIZATIONS`，只在 committed range 中豁免对所列授权记录的普通删除（status `D`），路径必须是授权目录下的 `*.json`；列出但未删除的记录失败；其余受保护删除与重命名规则不变；
- `trusted-base/Test-IFXTrustedBaseCandidate.ps1`：新增 `-AuthorizationOnly`，只做 TCB 映射与授权核对，报告 `consumedAuthorization`（任何失败时为空）；
- `trusted-base/Invoke-IFXTrustedBase.ps1`：Diff mode 先以 authorization-only 运行 base verifier（`-HeadRevision` 为 PR head），仅在通过时把被消费的记录路径传给 Diff，并在 summary 记录 `consumed-authorization`；
- `trusted-base/TrustedBase.psm1`：独立进程清除 `GUARD_CONSUMED_AUTHORIZATIONS` 继承；
- `tests/Test-IFXTrustedBase.ps1 -DiffConsumptionOnly`：9 个端到端用例（精确消费通过、summary 记录、完整候选验证通过、注入变量无效、仅删除未消费授权失败、与授权不符的变更仍阻断删除且候选验证失败、消费不豁免其他受保护删除、重命名被消费记录失败）；接入 `v3-architecture`；
- `stages/diff/authorizations/README.md`：说明删除规则；`analysis/ifx` 随 workflow 变更刷新；
- 删除被消费的授权记录。

## 2. 合入方式

base（含 CP05a-auth 授权）的 Diff 模板尚无豁免，本 PR 的 `v3-pre-diff` 必然以 `Protected guard deletions: docs/guards/V3_ifx/stages/diff/authorizations/cp05a-authorization-consumption.json` 失败；其余 12 个 check 应通过（候选验证消费授权通过）。按 D20 与 `20260917-v3-stage-cp05a-authorization.md` §4 runbook 执行一次性 break-glass 合入。

## 3. 验证

本地模拟见 PR 描述与 CP05a 汇报；合入后按 runbook 第 13–15 步完成事后复验与证据记录。

## 4. 回退

还原本 pair 列出的文件会重新修改 TCB 组件，需要新的 `change-trusted-base` 授权。
