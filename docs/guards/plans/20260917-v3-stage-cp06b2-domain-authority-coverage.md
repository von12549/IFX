# CP06b2 — Plan 06 P4（三）：D18 domain authority 的 `weaken-policy` 覆盖

本 pair 是 [正式 Plan pair](20260916-v3-stage-oriented-package-refactor.md) 检查点 CP06b2 的变更 PR，完成 [Plan 06](06-v3-stage-oriented-package-refactor.md) §12.4、§12.6 与 §14 P4.3 的 D18 部分，依据 D25。它消费 `20260917-v3-stage-cp06b2-authorization` 加入的两条正交授权：`change-trusted-base`（TCB 变化）与 `weaken-policy`（`stages/post/stage.json` 的 trust/meta 语义变化）。这是第一个由 CP06b1 规则判定的 PR，用来验证 trust/meta 变化同时需要两条授权。

## 1. 变更

**D18 比较的 Git 对象模式**：`Test-IFXDomainAuthorityCandidates.ps1` 新增 `-BaseRevision`/`-HeadRevision`，按 merge base 与明确 head commit 的 blob 比较，报告增加每个 authority 的 `blockingPointers`、`baseSha256`、`headSha256`；原有文件模式保持不变。

**保护义务**：`Test-IFXProtectedChanges.ps1` 以 Git 对象模式计算 D18 blocking findings，每个有 blocking findings 的 authority 产生 `policy-weakening` 义务（schema `domain-authority:<id>`，pointer 为 blocking pointers），由 `weaken-policy` 按 blob hash、head tuple、schema 与 pointer 集合精确覆盖。因此 `v3-pre-diff` 与 authority gate 对同一变化采用同一覆盖规则。生成器 `-Operation weaken-policy` 同时生成这些条目。

**Authority gate**（`Invoke-IFXTrustedBase.ps1` 的 Validate、Architecture、Specialized）：

- 提供 `-HeadRef` 时，authority 以明确 head commit 与其 merge base 的 Git 对象比较，不读取 checked-out（可能是 synthetic merge）树；
- 存在 blocking findings 时，runner 以 base verifier 针对该 commit 重新计算覆盖：报告必须绑定 base、merge base、明确 head、保护配置、registry 与授权 schema hash，每个 blocking authority 必须恰好被一条已消费的 `weaken-policy` 覆盖且 pointer 一致；授权记录、算法与 registry 全部来自 base；
- 由于 candidate projection 与 gate 读取 checkout，checkout 中每个变化的 authority 必须与明确 head commit 一致（`domain-authority-checkout`）；
- 未提供 `-HeadRef` 时 blocking findings 继续失败关闭。

**Workflow**：各 job 的 base worktree 准备步骤写入 `GUARD_HEAD_SHA`（PR head SHA，非 PR 事件为 `github.sha`），Validate、Architecture 与 Specialized 的 runner 调用传入 `-HeadRef $env:GUARD_HEAD_SHA`；`analysis/ifx` 清单更新 workflow hash。

**Trust contract**：`stages/post/stage.json` 中五个 D18 gate 的 `policy` 说明 blocking findings 只能由针对明确 head commit 重新计算的 base `weaken-policy` 授权通过。

**文档**：授权 README 与 `trusted-base.md`。

## 2. 测试

`Test-IFXTrustedBase.ps1 -DiffConsumptionOnly` 新增：

- verifier：未授权的 G03 catalog waiver 失败；授权的 waiver 通过；
- trusted runner Validate：未授权 waiver 在明确 head 下失败；授权 waiver 在明确 head 下通过，summary 报告针对该 head 重新计算的覆盖；同一授权 head 在没有 `-HeadRef` 时失败关闭；checkout 与明确 head 不一致时失败。

## 3. 与 Plan 06 文字的差异

| Plan 06 描述 | 实际实现 | 理由 |
| --- | --- | --- |
| §12.6 domain authority 削弱使用 `weaken-policy` | 覆盖只由 base verifier 针对明确 PR head SHA 重新计算，不信任 checkout 或隐式 merge commit；checkout 中变化的 authority 必须与该 commit 一致 | 用户于 2026-09-17 批准（D24 C、D25） |
| authority gate 的输入 | workflow 为 authority gate 显式传入 PR head SHA | gate 需要明确 head 才能重新计算覆盖（D25） |

## 4. 验证

见 PR 描述与 CP06b2 汇报。

## 5. 回退

还原本 pair 列出的文件会再次修改 TCB 组件与 trust/meta policy，需要新的 `change-trusted-base` 与 `weaken-policy` 授权。
