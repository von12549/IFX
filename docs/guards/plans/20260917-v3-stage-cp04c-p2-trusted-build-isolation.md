# CP04c — Plan 06 P2：可信构建隔离与 workflow 切换前置

本 pair 是 [正式 Plan pair](20260916-v3-stage-oriented-package-refactor.md) 检查点 CP04c 的 formal Plan，实施 [Plan 06](06-v3-stage-oriented-package-refactor.md) §11.2、§11.4、§11.6、§11.7 中 workflow 切换之前的部分（P2.2、P2.3、P2.5、P2.9），并记录 D19。输入为 CP04b 的 trusted-base runner、D18 候选比较与 TCB 候选验证。

## 1. 目标与拆分

原 CP04c 计划同时完成 workflow 切换。实施时用 CP04b runner 对仓库逐一运行全部 mode（Validate、Architecture、Diff、G03、G04、G05、Plan04、HistoricalIntegrity、Quality Solution/Assembly/Frontend、Database），发现 LayerGuard `GatePolicyBindingTests` 从包位置推导仓库根，而 runner 从仓库外的 base 包副本运行，测试会分析一个不存在的 `src/`。切换 workflow 的 PR 由 base runner 判定，如果 base 仍有这个缺陷，`v3-architecture` 必然失败。

按 D19 拆分：

- **CP04c（本 pair）**：合入全部前置，不改变任何 Gate 的判定入口；
- **CP04d**：把全部 required check 切换为 base runner，并在 `ci/jobs.json` 声明 `trustedBase` 生效。CP04d 的 PR 已由包含本检查点修正的 base runner 判定；激活标志从 base commit 读取，在 CP04d 之后的下一个 PR 首次生效（P2.8）。

## 2. 实现

**可信构建隔离（§11.2）**：

- `Invoke-V3.ps1`（V3 与 V3_ifx，保持相同）与 `Invoke-IFX.ps1`：设置 `GUARD_BUILD_ROOT` 时，门禁工程的 artifacts（restore、build、test 输出）与 Windows NuGet appdata 位于该目录；未设置时保持原位置；
- `Invoke-IFXTrustedBase.ps1`：以 `GUARD_BUILD_ROOT=<生成根>/build` 运行 dispatcher（生成根位于 head 与 base 之外）；新增 `trusted-build-isolation` 检查，head 原本没有 `artifacts/build/v3-ifx` 而运行后出现即失败；summary 文件名加入 SpecializedGate/QualityTarget，避免同一 mode 的不同 Gate 相互覆盖；
- `TrustedBase.psm1`：独立进程清除 `GUARD_BUILD_ROOT` 继承。

**Target root 修正**：LayerGuard `GatePolicyBindingTests`（模板与生成副本保持一致）优先读取 `GUARD_TARGET_ROOT`；`Invoke-IFX.ps1 -Mode Test` 在测试期间设置并恢复该变量。

**CI 激活契约（§11.1）**：`Invoke-IFXCiContract.ps1` 在 `ci/jobs.json` 声明 `trustedBase.execution: active` 时逐 job 检查：不得原位运行 head dispatcher；每个 required check 必须以自身名称作为 `-GateId` 调用 `$env:GUARD_BASE/.../Invoke-IFXTrustedBase.ps1`（支持 matrix 展开）；必须在 `$RUNNER_TEMP/guard-base` 建立 base worktree。本检查点不声明该标志，检查保持不生效；`Invoke-IFXManifestCheck.ps1` 与 `Get-GuardHeadExecutableReferences` 同时识别 `$env:GUARD_BASE/docs/guards/...` 形式的 workflow 入口。

**Workflow 退出码修正**：`v3-pre-diff`、`v3-architecture`、`v3-cross-platform` 原先在同一 step 中依次调用多个脚本，以 `exit 1` 失败的脚本（例如 `Test-IFXTargetRootSeparation.ps1`、`Test-IFXTrustedBase.ps1`）会被后续脚本覆盖退出码。现改为每个脚本 `pwsh -File` 独立进程运行并检查退出码；`v3-architecture` 增加 `Test-IFXTrustedBase.ps1 -ArchitectureOnly`。Gate 判定入口与 required check 名称不变。

**负向控制**：`Test-IFXTrustedBase.ps1 -ArchitectureOnly` 在 head 根写入会报错的 `Directory.Build.props`、`Directory.Build.targets` 与关闭 NuGet 审计的 `Directory.Packages.props`，trusted Architecture（LayerGuard 构建、192 个测试、严格扫描）仍通过，且 `trusted-build-isolation` 为 pass、head 中没有门禁构建输出；`Test-IFXCiContract.ps1` 新增 3 个用例证明声明 trusted execution 后，当前 workflow 因缺少 runner、原位 dispatcher 与 base worktree 失败。

**决定与文档**：D19（`20260917-v3-stage-d19-trusted-base-first-introduction.json`）；`docs/guards/V3_ifx/docs/authored/trusted-base.md` 记录 §11.4 保证范围、D19 与 §11.7 break-glass 步骤和记录字段；DEPLOYMENT 补充构建输出位置；Plan 06 勾选 P2.2、P2.3、P2.5、P2.9 并新增 D19；plan pair 拆出 CP04d。

## 3. 与 Plan 06 文字的差异

| Plan 06 描述 | 实际实现 | 理由 |
| --- | --- | --- |
| CP04c 同时切换 workflow | 切换移入 CP04d | 切换 PR 由 base runner 判定，base 必须先包含 target root 修正（D19） |
| §11.2 生成源码与构建输出位于 `$RUNNER_TEMP/guard-gen/<package>/` | 生成根为 `$RUNNER_TEMP/guard-gen-<随机>/`，包副本在 `v3-ifx/`，构建输出在 `build/` | 每次运行独立目录，避免残留 |
| §11.2 构建后 binlog 复核 | 沿用 CP03 的 MSBuild 导入日志 | 见 CP03 pair |
| P2.5 受保护路径清单篡改 | 由 P3 保护路径参数化补充 | 受保护路径清单尚未独立成文件 |

## 4. 验证

本地（Windows，SDK 10.0.303，Docker 可用）：

| 项 | 结果 |
| --- | --- |
| 以 runner 从包含本检查点代码的 base worktree 对仓库运行 12 个 mode（含 Architecture 192 个测试、Diff、Quality 三项、Database SQL Server 矩阵） | 全部通过 |
| `Test-IFXTrustedBase.ps1 -ArchitectureOnly`；`Test-IFXTrustedBase.ps1`（28 个用例） | 通过 |
| `Test-IFXCiContract.ps1`（新增 3 个 trusted execution 声明用例）、`Test-IFXManifests.ps1` | 通过 |
| `Invoke-IFXGuardrails` Validate、Architecture、HistoricalIntegrity、Specialized G03/G04/G05/Plan04（原位） | 通过 |
| Test-IFXDomainAuthorityCandidates、Test-IFXTargetRootSeparation、Test-IFXPackage、Test-IFXAssemblyGuard、Test-IFXPre、Test-IFXAuthorityProjection、Test-IFXHistoricalIntegrity、Test-IFXSpecializedContracts、Test-CutoverPreservation | 通过 |
| V3_ifx 与 V3 的 Test-V3、Test-V3ArchUnit、Test-V3Tools；V3 Test-V3BuildBaseline | 通过 |
| Test-IFXTools（workflow 变更后已刷新 `analysis/ifx/INVENTORY.md` 与 `inventory.json`） | 通过 |
| `New-RefactorBaseline.ps1 -Check` | 通过 |
| 本 pair 的 Pre | advisory |

Linux 由 CI `v3-cross-platform-ubuntu-latest` 与 `v3-architecture` 验证；13 个 required check 名称不变。

## 5. 回退

还原本 pair 列出的文件。`GUARD_BUILD_ROOT` 未设置时构建位置不变；CI 激活检查只在 `ci/jobs.json` 声明 `trustedBase` 时生效；workflow 只改变脚本调用方式。
