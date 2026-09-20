# CP08-prep — Plan 06 P7 canonical V3 引用与 base-owned 验证扩展

本 pair 是正式 Plan 06 检查点 CP08 的 expand 前置步骤。它不删除 tracked Stage Gate 或 V3_ifx 重复副本；目标是先让 IFX overlay、manifest、trusted-base 调用链与 base-owned 测试直接使用 canonical `docs/guards/V3`，使后续 CP08 contract 删除在候选 overlay 下仍可验证。

## 1. 变更

- `Invoke-IFXGuardrails.ps1` 的 V3 runner 与 docs checker 改为直接引用 `docs/guards/V3/scripts/`；Diff 在仓库外 generation root 中依次执行 Generate、Check、Diff，使用 IFX reviewed lock root。
- `Invoke-IFXTrustedBase.ps1` 把已经验证位于 head/base 之外的 generation root 显式传给 IFX orchestrator；隔离子进程清除新增的 generation-root 环境变量。
- policy candidate 的 canonical profile Validate 使用独立 generation root；IFX project map、生成视图与 architecture review draft 提前登记 `.gitignore` 为 `RepositoryIgnore`，使下一检查点能由 base policy 映射该仓库级变更。
- `commands.json`、`trusted-components.json` 与 `guard-system.json` 将 canonical V3 声明为实际 engine，base-owned V3 测试所有权收敛到 `docs/guards/V3/tests/`；workflow 仍引用的 legacy `Invoke-V3.ps1` 先收敛为 canonical V3 的薄 wrapper，现有内部 IFX 重复文件临时归入独立 transition 组件，供下一检查点精确删除。
- IFX 专属 base-owned 测试、policy candidate 检查与 protected-change rehearsal 改为调用 canonical V3 路径；manifest verifier 阻止 command 重新指向 IFX fork。
- canonical `Test-V3*`/build-baseline 套件先切换到仓库外 generation root 和项目专属名称；Stage Gate generator 的 base validation suite 先指向 canonical 测试，manifest 负向用例先接受下一检查点删除 IFX synthetic copy。

## 2. 为什么先做 prep

候选验证会把 base manifest 中所有 `base-owned*` 组件覆盖到 candidate。若直接删除 `V3_ifx/tests/Test-V3*.ps1`，当前 base 会把它们恢复到 candidate，既破坏“副本已删除”的断言，也可能形成未声明组件路径。先让本 pair 合入 base，后续 CP08 的 base overlay 只恢复 canonical V3 测试。

## 3. 验收

- manifest checker 与 `Test-IFXManifests.ps1` 正/负向套件通过；
- IFX Validate/Pre 通过并实际调用 canonical V3；
- canonical runner 在仓库外临时 generation root 完成 Generate + Check，仓库内 tracked snapshot 保持不变；
- trusted-base 的 generation root 继续位于 head 与 base worktree 之外；
- 下一检查点对 `.gitignore` 的修改在本 pair 形成的 base profile 中可映射；
- 除消费两条 exact-candidate authorization 记录外，本 pair 无产品文件删除、移动、workflow 激活或 required-check 名称变化。

## 4. 后续 contract

CP08 将在本 pair 成为 base 后，通过 exact-candidate 授权完成项目名参数化、Self/Post/Diff 目录、lock rename、workflow/head-candidate 调用更新、tracked `generated/stages` 取消跟踪，以及 IFX 重复实现删除。授权记录必须在实际 merge commit 上重新生成。
