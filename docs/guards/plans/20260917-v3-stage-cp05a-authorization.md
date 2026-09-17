# CP05a-auth — 授权记录消费修复的 change-trusted-base 授权与 break-glass runbook

本 pair 是 [正式 Plan pair](20260916-v3-stage-oriented-package-refactor.md) 检查点 CP05a 的第一个 PR（授权 PR），记录 D20（`20260917-v3-stage-d20-authorization-consumption-and-break-glass.json`）。第二个 PR（修复 PR）见 `20260917-v3-stage-cp05a-authorization-consumption`。

## 1. 问题

CP04d 之后，候选验证要求消费授权的变更 PR 删除 base 中的授权记录（`docs/guards/V3_ifx/stages/diff/authorizations/<id>.json`）；base 的 Diff 模板把 `docs/guards/V3_ifx/` 下的任何删除视为受保护删除，授权删除要到 P4 才实现。因此任何 TCB 变更（包括修复这一冲突的变更）都会在 `v3-pre-diff` 失败。CP04b 的测试分别验证了 verifier 与 Diff，没有端到端覆盖二者的组合。

## 2. 本 PR 内容

- `stages/diff/authorizations/cp05a-authorization-consumption.json`：由 `New-IFXTrustedBaseAuthorization.ps1` 从准备好的修复 revision 生成，覆盖修复 PR 的全部 TCB 路径与 base/head tuple；
- D20 决定；
- plan pair 与 Plan 06 记录 CP05a 与 D20。

本 PR 不修改 TCB 组件、不删除任何文件，13 个 required check 应全部通过。

## 3. 修复设计（修复 PR）

- runner 在 Diff mode 先以 authorization-only 模式运行 base 候选 verifier（针对精确的 PR head）；只有全部授权核对通过（组件集合、changed paths、逐路径 tuple、validation suite、plan/decision 引用、head 删除记录）才得到被消费的记录路径；
- runner 仅把该路径通过 `GUARD_CONSUMED_AUTHORIZATIONS` 传给 Diff；该变量在 runner 启动的独立进程中先被清除，外部注入无效；
- 生成的 Diff 测试只豁免 committed range 中对该路径的普通删除（status `D`），且路径必须是授权目录下的 `*.json`；重命名、其他受保护删除、未验证或注入的消费、未被本变更消费的授权删除仍失败；列出但未删除的记录也失败；
- 不把任意授权删除定义为安全撤销（D20），撤销未使用授权仍须等待 P4；
- 端到端回归：`Test-IFXTrustedBase.ps1 -DiffConsumptionOnly`（9 个用例，接入 `v3-architecture`）。

## 4. Break-glass runbook（Plan 06 §11.7，D20）

仅在修复 PR 的 12 个非 Diff required check 全部通过、且只有 `v3-pre-diff` 因消费记录删除失败时执行。每一步远程写操作需要用户单独授权。

**角色**：授权人 `von12549`（仓库管理员）；复核人由授权人指定并在 PR 评论中确认。

**前置核对（只读）**

1. `gh pr checks <修复 PR>`：确认仅 `v3-pre-diff` 失败，且日志中的失败信息为 `Protected guard deletions: docs/guards/V3_ifx/stages/diff/authorizations/cp05a-authorization-consumption.json`；
2. `gh pr view <修复 PR> --json headRefOid,baseRefOid,mergeStateStatus`：记录 head/base SHA，head 必须等于复核过的 SHA；
3. before 快照：`gh api repos/von12549/IFX/rulesets/23459908 > artifacts/guards/break-glass/ruleset-before.json`，并运行 `pwsh docs/guards/V3_ifx/ci/Invoke-IFXCiContract.ps1 -Remote -ReportPath artifacts/guards/break-glass/ci-contract-before.json`（应通过）。

**临时变更（写，需单独授权）**

4. 由 before 快照生成请求体：只从 `rules[type=required_status_checks].parameters.required_status_checks` 删除 `context == "v3-pre-diff"` 的一项，其余字段（`enforcement`、`conditions`、`bypass_actors`、`strict_required_status_checks_policy: true`、`pull_request` 规则等）保持不变；保存为 `ruleset-during-request.json`；
5. `gh api -X PUT repos/von12549/IFX/rulesets/23459908 --input ruleset-during-request.json > ruleset-during.json`；核对 during 快照与 before 的差异只有该 context（12 个 required check，`strict` 仍为 true）；
6. 记录开始时间（UTC）。

**合入**

7. 修复 PR 使用 merge commit 合入（与既有 PR 一致），合入前再次确认 head SHA 未变化；
8. 记录 merge commit SHA 与合入时间。

**恢复（写，需单独授权，紧接合入执行）**

9. `gh api -X PUT repos/von12549/IFX/rulesets/23459908 --input ruleset-before-request.json`（由 before 快照去除只读字段 `id`、`source`、`source_type`、`created_at`、`updated_at`、`node_id`、`_links`、`current_user_can_bypass` 生成）；
10. after 快照：`gh api repos/von12549/IFX/rulesets/23459908 > ruleset-after.json`；除 `updated_at` 外必须与 before 一致；
11. `Invoke-IFXCiContract.ps1 -Remote -ReportPath artifacts/guards/break-glass/ci-contract-after.json`：13 个 required check 与 `strict` 通过；
12. 记录恢复时间（UTC）。

**事后复验与记录（常规 PR，不需要 break-glass）**

13. 正向：一个常规 TCB 变更按两 PR 流程完成（授权 PR → 变更 PR），变更 PR 的 `v3-pre-diff` 报告 `consumed-authorization` 通过，13 个 check 全部通过；
14. 负向：draft PR 删除一条未被消费的授权记录，`v3-pre-diff` 以 `Protected guard deletions` 失败，关闭不合入；
15. 在事后 PR 中新增 `docs/architecture/review/evidence/guards/break-glass-20260917-cp05a.md`，记录授权人与复核人、原因与失败 run 链接、受影响 check、开始与恢复时间、before/during/after 快照摘要、CI 契约前后报告、事后复验 run 链接。

**中止条件**：任一步核对不符（修复 PR 有其他失败、head SHA 变化、during 快照有额外差异、恢复后快照不一致）即停止并先恢复 before 配置。

## 5. 回退

还原本 pair 列出的文件；授权记录未被消费前删除它本身会被 Diff 视为受保护删除，需等到修复合入后通过 P4 或新的授权流程处理。
