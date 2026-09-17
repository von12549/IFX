# CP06c — Plan 06 P4（四）：两 PR 演练、ruleset `strict` 证据与 `Test-V3.ps1` parity

本 pair 是 [正式 Plan pair](20260916-v3-stage-oriented-package-refactor.md) 检查点 CP06c 的变更 PR，完成 [Plan 06](06-v3-stage-oriented-package-refactor.md) §14 的 P4.5、P4.6 与 P4.7，并补上 CP05 遗留的 `Test-V3.ps1` parity 检查。它消费 `20260917-v3-stage-cp06c-authorization` 加入的 `change-trusted-base` 授权；本 PR 不修改已登记 policy。

## 1. 变更

**两 PR 演练（P4.7）**：新增维护命令 `trusted-base/Invoke-IFXProtectedChangeRehearsal.ps1`，在仓库外的一次性 clone 中，由指定 base commit 自己的 trusted runner、候选 verifier、policy 候选验证与授权生成器判定一次完整的两 PR 流程。一个准备好的变更同时包含受保护目录 `move`、规则标题变化（`weaken-policy`，并重新生成 profile views）与行为等价的 engine 变化（`change-trusted-base`）。步骤如下：

- 授权 PR 通过；
- 授权合入前打开的变更失败；
- 变更 PR 在已授权 base 上消费三条记录，通过 trusted Diff、完整固定语料 parity 的候选验证、head policy 候选验证与明确 head 的 Validate；
- 变更合入后重放同一授权失败。

报告只记录 commit 与判定，临时路径替换为 `<temp>`。

**演练发现**：第一次演练只改规则标题、未重新生成 profile views。CP06b2 base 的 trusted Diff 接受了该变化，其 head policy 候选验证不检查 views，只有因 engine 变化而运行的候选 parity 以 Validate `profile-views` 失败拦截。仅修改 policy 的 PR 不会运行候选 parity，合入后会使下一个 base 的 Validate 失败。因此 `Test-IFXPolicyCandidates.ps1` 在验证 head profile 后，由 base renderer 在 head commit worktree 中检查 profile views（`v3-profile-views`）；演练与 fixture 的规则变化改为同时重新生成 views，并新增过期 views 的负例。

**证据（P4.6、P4.7）**：`docs/architecture/review/evidence/guards/p4-rehearsal-20260917.md`，附演练报告与 `Invoke-IFXCiContract.ps1 -Remote` 报告。两者针对合入后的 base `3edb78a` 运行，ruleset `strict` 等 4 个 ruleset 检查与 13 个 required checks 均通过。

**`Test-V3.ps1` parity**：`Invoke-IFXManifestCheck.ps1` 要求 V3 与 V3_ifx 的 `tests/Test-V3.ps1` 逐字节相同。两份自 CP05 起都是 base-owned tests，候选验证同时叠加两者，因此该检查可以在本 PR 引入。`Test-IFXManifests.ps1` 增加对应负例。

**文档**：授权 README 说明演练命令与 views 检查。

## 2. 测试

- `Test-IFXTrustedBase.ps1 -DiffConsumptionOnly`：规则变化重新生成 views 后候选验证通过；过期 views 的规则变化候选验证失败；
- `Test-IFXManifests.ps1`：V3_ifx `Test-V3.ps1` 与 V3 不一致时失败；
- 演练：针对 `3edb78a` 的 8 个步骤全部符合预期。

## 3. 与 Plan 06 文字的差异

| Plan 06 描述 | 实际实现 | 理由 |
| --- | --- | --- |
| P4.7 在临时仓库或 fixture 中演练 | 可重复运行的维护命令，在一次性 clone 中由合入后的 base 自身脚本判定，证据入库；不在 CI 中运行 | 演练验证实际生效的 base，而不是候选代码 |
| §12.4 head 候选验证 | head profile 同时检查 generated views | 演练发现 policy-only PR 可能以过期 views 合入 |

## 4. 验证

见 PR 描述与 CP06c 汇报。

## 5. 回退

还原本 pair 列出的文件会再次修改 TCB 组件，需要新的 `change-trusted-base` 授权。
