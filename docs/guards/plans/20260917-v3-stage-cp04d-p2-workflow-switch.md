# CP04d — Plan 06 P2：workflow 切换为 trusted base runner

本 pair 是 [正式 Plan pair](20260916-v3-stage-oriented-package-refactor.md) 检查点 CP04d 的 formal Plan，实施 [Plan 06](06-v3-stage-oriented-package-refactor.md) §11.1 的 workflow 切换（P2.1），并按 D19 声明 trusted base 生效。输入为 CP04b 的 runner 与 TCB 候选验证、CP04c 的构建隔离、LayerGuard target root 修正与 CI 激活契约检查。

## 1. 目标

1. 13 个 required check 的判定全部来自 base worktree 中的 `Invoke-IFXTrustedBase.ps1`，checkout 只作为 target；
2. PR 上的 TCB 候选验证在 `v3-cross-platform-ubuntu-latest` 中运行，是否生效由 base commit 的 `ci/jobs.json` 决定；
3. 在 `ci/jobs.json` 声明 `trustedBase.execution` 与 `tcbCandidateVerification` 为 `active`，使 CI 激活契约与 TCB 候选验证从下一个 PR 起生效；
4. 保持 13 个 required check 名称、job DAG 与触发条件不变。

## 2. 实现

**Workflow**（`.github/workflows/v3-ifx-guardrails.yml`）：

- 所有 job 使用 `fetch-depth: 0`，并先执行 `Prepare trusted base worktree`：`git worktree add --detach $RUNNER_TEMP/guard-base <base>`；PR 使用 `pull_request.base.sha`，push、schedule、workflow_dispatch 使用当前 commit；写入 `GUARD_BASE`、`GUARD_BASE_SHA`；
- 判定 step 一律为 `pwsh -NoProfile -File "$env:GUARD_BASE/docs/guards/V3_ifx/trusted-base/Invoke-IFXTrustedBase.ps1" -HeadRoot $env:GITHUB_WORKSPACE -BaseSha $env:GUARD_BASE_SHA -Mode … -GateId <check>` 并检查退出码：
  - `v3-pre-diff`：Diff（formal Plan 解析仍在 YAML 中）；
  - `v3-architecture`：Validate 与 Architecture；
  - `v3-quality-solution`、`v3-quality-assembly`、`v3-quality-frontend`：对应 Quality target；
  - `v3-specialized-g03`、`g04`、`g05`、`plan04`、`database`：对应 SpecializedGate；
  - `v3-historical-integrity`：HistoricalIntegrity；
  - `v3-cross-platform-*`：Validate（gate ID 使用 matrix 名称）；
- head candidate 测试（`v3-architecture` 的包测试与 `Test-IFXTrustedBase -ArchitectureOnly`，`v3-cross-platform` 的生成物复现与包测试）仍从 checkout 运行，每个脚本独立进程并检查退出码，只补充覆盖；head dispatcher 不再原位运行；
- `v3-cross-platform-ubuntu-latest` 在 PR 上新增 `Verify trusted component candidates`：以 `git show <base>:docs/guards/V3_ifx/ci/jobs.json` 读取 base 的 `trustedBase.tcbCandidateVerification`，为 `active` 时从 base worktree 运行 `Test-IFXTrustedBaseCandidate.ps1`，否则输出首次引入说明并跳过。

**激活声明**：`ci/jobs.json` 新增 `"trustedBase": { "execution": "active", "tcbCandidateVerification": "active" }`。

**测试**：`Test-IFXCiContract.ps1` 的激活用例改为针对切换后的 workflow：单 job gate ID 错误、matrix gate ID 错误、原位 head dispatcher、缺少 base worktree 均失败；删除 `trustedBase` 声明时不执行这些检查。

**Trust contract 与文档**：`stages/ci/stage.json` 的两个 cross-platform Gate 写明 base runner Validate 与 ubuntu 上的 TCB 候选验证；DEPLOYMENT 说明 CI 的运行方式与 TCB 验证生效条件；Plan 06 勾选 P2.1；plan pair 记录 CP04c 合入。

## 3. D19 首次引入

本 PR 由 CP04c base（`dab8243`）的 runner 判定：base 的 `ci/jobs.json` 没有 `trustedBase` 声明，因此 CI 激活契约检查与 TCB 候选验证在本 PR 不生效；本 PR 修改 TCB 组件（workflow、`ci/jobs.json`、`stages/ci/stage.json`、测试）而不需要授权，仅因 base 尚未强制。合入后的下一个 PR：

- 若修改任何 TCB 组件而没有消费 base 授权，`v3-cross-platform-ubuntu-latest` 必须失败；
- 若 workflow 某个 required check 不再调用 base runner，`Validate` 中的 CI 契约必须失败。

该 PR 须记录上述阻断证据后才勾选 P2.8。

## 4. 验证

本地（Windows，SDK 10.0.303）：

| 项 | 结果 |
| --- | --- |
| 模拟本 PR 的 CI：从 CP04c base（`dab8243`）worktree 运行 runner，target 为本分支：Diff（本 pair）、Validate（`v3-architecture` 与 `v3-cross-platform-windows-latest` gate ID）、Architecture、Specialized G03、HistoricalIntegrity | 全部通过 |
| 模拟 `Verify trusted component candidates` step：base `ci/jobs.json` 未声明 `trustedBase` | 跳过（exit 0） |
| 预演下一个 PR：从 CP04c base 对本分支运行 `Test-IFXTrustedBaseCandidate.ps1` | 失败：`tcb.activation.ci`、`tcb.manifest`、`tcb.validation.package-tests` 需要 `change-trusted-base` 授权，证明激活后未授权 TCB 变更会被阻断 |
| `Invoke-IFXCiContract.ps1`（激活声明下，针对切换后的 workflow） | 通过 |
| `Test-IFXCiContract.ps1`（切换后 workflow 的 4 个激活用例与 1 个未声明用例）、`Test-IFXManifests.ps1` | 通过 |
| `Invoke-IFXGuardrails -Mode Validate`（原位） | 通过 |
| Test-IFXTools（workflow 变更后已刷新 `analysis/ifx/INVENTORY.md` 与 `inventory.json`） | 通过 |
| 本 pair 的 Pre | advisory |

其余 Gate 的判定路径在 CP04c 已以 runner 矩阵（12 个 mode）验证；本 PR 的 13 个 required check 由 GitHub Actions 以切换后的 workflow 实际运行。

## 5. 回退

还原本 pair 列出的文件即回到 CP04c 的原位 workflow；回退本身修改 TCB 组件，合入后需要 `change-trusted-base` 授权，或按 `docs/authored/trusted-base.md` 的 break-glass 流程处理。
