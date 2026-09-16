# Plan 06 P0 基线：V3 Stage 化重构前的冻结记录

> 检查点：CP01（Plan 06 P0，只读）
>
> 基线 commit：`d2663392db1bacd34dd866917c45b7cdf3ede7cc`（root tree `c744f9c128337122bce92574bbacfa2505163c96`）
>
> 记录日期：2026-09-16
>
> 权威关系：本目录属于 Plan 06 §13 的"经评审长期输入/基线"（lifecycle `reviewed-input`）。后续检查点以本目录为迁移前事实来源；不得把它当作当前配置。

## 1. 文件与再生成方式

| 文件 | 内容 | 来源 | 对应 |
| --- | --- | --- | --- |
| `inventory.json` | 820 个文件的对象 ID、kind、Stage、owner、处置、目标位置、阶段、决策 | 生成 | P0.1、P0.2 |
| `duplicates.json` | 树级与 blob 级重复 | 生成 | P0.1 |
| `call-graph.json` | 70 个可执行文件的调用图、CI job 首个可执行入口、公开/内部分类 | 生成 | P0.3 |
| `tcb.json` | 初始 TCB component 冻结清单、base-owned validation suite、parity contract | 生成（组件划分为人工判断，写在生成器内） | P0.3 |
| `v3-divergence.json` | V3 与 V3_ifx 相同/分叉/独有文件及分叉分类 | 生成 | P0.6 |
| `change-frequency.json` | policy/config 各 schema 的历史修改频率 | 生成 | P0.9 |
| `dotnet-gates.json` | 两个 .NET gate 的源码、package、测试类别、执行路径、IFX binding、已知覆盖缺口 | 人工 | P0.4 |
| `drift.json` | 迁移前缺陷登记 DRIFT-01–10 与范围外发现 | 人工 | P0.5 |
| `ruleset.json` | ruleset `23459908` 与仓库合并设置（只读） | 人工，GitHub API | P0.7 |
| `build-inheritance.json` | 门禁工程继承的 MSBuild/NuGet/SDK 配置与有效属性 | 人工，`dotnet msbuild -getProperty` | P0.8 |
| `trust-contracts.json` | 13 个 required check 的 trust contract 当前与目标分类 | 人工 | P0.10 |
| `local-results.json` | 本地 Validate/Generate/Check/Test 结果 | 人工，本地运行 | P0.1 |
| `ci-evidence/` | 基线 CI run `35055279816` 的 69 份 JSON 报告、TRX 汇总与 SHA-256 manifest | 下载归档 | P0.1、Plan pair §7.3 |

生成文件只读取基线 commit 的 Git 对象，不读工作区：

```powershell
pwsh -NoProfile -File docs/guards/V3_ifx/analysis/ifx/refactor-baseline/tools/New-RefactorBaseline.ps1          # 重新生成
pwsh -NoProfile -File docs/guards/V3_ifx/analysis/ifx/refactor-baseline/tools/New-RefactorBaseline.ps1 -Check   # 逐字节校验
```

生成器在以下情况失败关闭：存在未分类文件、存在未分类的 V3/V3_ifx 分叉、TCB 路径缺失或重叠、存在不属于任何 TCB component 的判定链可执行文件。排序使用 ordinal 比较，Windows 与 Linux 输出一致。

`tools/archive-ci-evidence.py` 记录 `ci-evidence/` 的归档规则（输入为 `gh run download` 的目录）。artifact 于 2026-12-15T04:21:29Z 过期，之后以本目录归档为准。

## 2. P0.1 基线记录

**范围**：`docs/guards/V3`（41）、`docs/guards/V3_backup`（41）、`docs/guards/V3_ifx`（537）、`docs/guards/plans`（11）、`mcp/LayerGuard`（185）、`.github`（5），共 820 个文件。

**CI 证据**（run `35055279816`，被测 merge ref 与基线 commit 同一 root tree）：

- 13/13 required check `success`，14 份 summary 全部 `pass`；
- solution 测试 21 个 TRX，1277 个测试，0 失败；
- 归档 69 份 JSON，`manifest.json` 同时记录 artifact 字节与 LF 规范化后的 SHA-256（`v3-cross-platform-windows-latest/summary-validate.json` 原为 CRLF，二者不同）。

**本地运行**（Windows，SDK 10.0.303；运行后 `docs/guards` 工作区无变化）：

| 结果 | 项目 |
| --- | --- |
| 通过（14） | Validate、V3 Generate/Check、IFX Generate/Check、Test-IFXPre、Test-IFXAuthorityProjection、Test-IFXSpecializedContracts、Test-IFXHistoricalIntegrity、Test-CutoverPreservation、Test-IFXPackage、Test-IFXAssemblyGuard、Test-V3、Test-V3Tools |
| 失败（3，均不在 CI 中运行） | Docs Check（DRIFT-01）、Test-IFXTools（DRIFT-08）、Test-V3ArchUnit（DRIFT-08，NU1008） |

CI 实际运行的命令本地全部通过。

**重复**：V3 与 V3_backup 树完全相同；`templates/ifx-layerguard` 与 `generated/dotnet/LayerGuard` 树完全相同（174 文件）；`templates/ifx-layerguard/src` 与 `mcp/LayerGuard/src` 树完全相同，`tests` 仅 `GatePolicyBindingTests.cs` 不同；共 197 组重复 blob。

## 3. P0.2 文件分类

每个文件恰好一个 kind、一个主 Stage 和一个处置；未分类数为 0。

| kind | 数量 | | 处置 | 数量 |
| --- | --- | --- | --- | --- |
| implementation | 441 | | delete | 215 |
| generated | 219 | | out-of-scope | 188 |
| authority | 72 | | merge-into-v3 | 176 |
| documentation | 52 | | migrate-overlay | 107 |
| evidence | 34 | | migrate | 40 |
| activation | 2 | | replace | 39 |
| | | | delete-duplicate | 23 |
| | | | untrack | 17 |
| | | | retain | 13 |
| | | | split | 2 |

- `delete`：V3_backup 41（D2，P10.5）与 `generated/dotnet/LayerGuard` 174（D12，P6.1）。
- `delete-duplicate`：V3_ifx 中与 V3 逐字节相同的 23 个文件（D1，P7.5）。
- `untrack`：`generated/stages` 17 个文件（D3，P7.2）。
- `split`：`GatePolicyBindings.cs` 与 `GatePolicyBindingTests.cs`（D12，P6.2–P6.3）。
- `out-of-scope`：`mcp/LayerGuard`（Plan 05 保留）与 3 个非门禁 `.github` 协作文件。
- 除 `.github/CODEOWNERS`、`copilot-instructions.md` 与 2 个 PR 模板外，全部文件由 CODEOWNERS 路由到 `@von12549 @jimkeecn`；`CODEOWNERS` 文件本身没有 owner 规则（git 端审查设置属于 §18 O1，本计划不处理）。

**`analysis/ifx/` 生命周期**：

| lifecycle | 文件 | 后续 |
| --- | --- | --- |
| reviewed-input | `ARCHITECTURE.md`、`TECHNICAL.md`、`legacy-deletion-manifest.json`，以及本目录 | 保留为评审输入，经 `maintenance/` Preview/Apply 更新 |
| reviewed-snapshot | `cutover-baseline.json`、`CUTOVER-BASELINE.md`、`specialized-parity.json` | 冻结报告快照 |
| runtime-output | `inventory.json`、`INVENTORY.md`、`PROPOSAL.md`（Analyze 写出）；`architecture-review.json`、`ARCHITECTURE-REVIEW.md`、`review-profile/**`（Review 写出） | P8.6 改写到 `artifacts/guards/v3-ifx/analysis/` |

## 4. P0.3 调用图、入口与 TCB

- 70 个可执行文件：public 27、internal 38、unreferenced 5；CI 可达 51，判定链 50。
- **全部 CI job 的第一个可执行入口都来自 PR head**：`v3-pre-diff` 为 `V3_ifx/scripts/Invoke-V3.ps1`，其余 12 个 check 为 `V3_ifx/scripts/Invoke-IFXGuardrails.ps1`。
- **V3 包没有任何可执行文件被 CI 调用**（`v3PackageCiReachable = 0`），见 DRIFT-10。
- 未被任何入口、测试或文档引用：`New-IFXHistoryManifest.ps1`（维护工具）与 4 个 Plan04 脚本（DRIFT-09）。

**初始 TCB**：17 个 component，其中 15 个对应现有文件（覆盖 435 个 inventory 文件，另含仓库根 3 个 props），2 个为计划组件（`trusted-components.json`，P1.5；V3 `build/`，P5）。判定链上的可执行文件全部归入 TCB。每个 component 记录 base-owned validation suite 与 parity contract；该清单在 P1.5 materialize 为 `shared/trusted-components.json`。

## 5. P0.4 .NET gate 冻结

| gate | 当前工程 | 测试方法 | 执行路径 |
| --- | --- | --- | --- |
| Stage Gate | `generated/stages/GuardV3.Tests.csproj`（xunit 2.9.2、ArchUnitNET 0.13.4，net10.0） | 9：Self 6、Post 2、Diff 1 | `Invoke-V3.ps1` Test/Diff；`Invoke-IFXAssemblyGuard.ps1` |
| Architecture Conformance | `templates/ifx-layerguard`（Roslyn 5.9.0、ModelContextProtocol 2.2.0；实际构建 `generated/dotnet/LayerGuard`） | 136（19 个测试类），fixture 125 个文件、19 组 | `Invoke-IFX.ps1` Test/Scan；`Invoke-IFXGuardrails.ps1 -Mode Architecture` |

**IFX-specific binding**（大小写不敏感扫描，fixture 中无 IFX 标识）：

- `src/LayerGuard/GatePolicyBindings.cs:380`：`ifx-api`、`ifx-worker`、`ifx-all`；
- `tests/LayerGuard.Tests/GatePolicyBindingTests.cs:150,169,172,176`：`IFX.Platform.Context.Contracts`、`IFX.Modules.Consumer.Application`、`IFX.Modules.Unknown.Contracts`。

**已知覆盖缺口**：`CsprojReader.cs` 只读取 csproj XML 元素，不解析 `<Import>`、Condition 或 `Directory.Build.*` 注入的 `ProjectReference`；由 `v3-quality-assembly` 交叉兜底。

## 6. P0.5 漂移登记

| ID | 问题 | 修复阶段 |
| --- | --- | --- |
| DRIFT-01 | profile views 过期（PROJECT_MAP、TECH_STACK；缺 7 个 area），Docs Check 不在 CI | P1.2 |
| DRIFT-02 | architecture review 证据过期（inventory 与 ApiHost.csproj 不一致，review-profile 与 profile 不同） | P1.2、P8.6 |
| DRIFT-03 | DEPLOYMENT 记录的证据刷新流程在基线上失败 | P1.2 |
| DRIFT-04 | `IFX-MIGRATION.md` 称 173 个文件，实际 174 | P1.2 |
| DRIFT-05 | `SourceConfig` area 的 `src/*` 不匹配任何文件 | P1.2 |
| DRIFT-06 | `ci/jobs.json` 没有任何校验 | P1.3 |
| DRIFT-07 | `ci/jobs.json` 声明 historical-integrity 仅在历史变更/定时/手动触发，workflow 实际每次运行（已核实） | P1.2、P1.3 |
| DRIFT-08 | 不在 CI 中的 Test-IFXTools、Test-V3ArchUnit 失败 | P1.2、P5 |
| DRIFT-09 | 4 个 Plan04 脚本不可达 | P1.2（退役需等待 P4 授权） |
| DRIFT-10 | canonical V3 包未被 CI 执行 | P3、P7 |

范围外发现 NOTE-01：`mcp/LayerGuard` 是 LayerGuard 的第三份源码副本，本计划不处理，需要后续独立决策。

## 7. P0.6 V3 与 V3_ifx

V3 的 41 个文件中：23 个与 V3_ifx 逐字节相同，12 个分叉，6 个仅在 V3（`examples/minimal/views/`）；V3_ifx 另有 502 个独有文件。

| 分叉分类 | 文件 |
| --- | --- |
| generic-hardening + ifx-specific | `templates/dotnet/GuardTests.cs.in`（merge-base、受保护删除/重命名检测、空 diff 失败为通用加固；硬编码保护路径为 IFX-specific）；`tests/Test-V3.ps1`（退出码归一化为通用；复制 `docs/Directory.Packages.props` 与 nuget.org 源为宿主/环境选择） |
| ifx-specific | README、DEPLOYMENT、`architecture/ARCHITECTURE.md`、`architecture/TECHNICAL.md`、`generated/README.md`、`rules/README.md`、两个 SKILL.md、`templates/plan/README.md`、`templates/plan/20260914-example.plan.json` |

## 8. P0.7 ruleset

ruleset `23459908` active，作用于默认分支与 `codex/guards-principles-plan`，无 bypass actor；13 个 required check 与 Plan 06 §10.3 完全一致，`strict = true`；`require_code_owner_review = false`、审批数 0（§18 O1，不变更）。仓库允许 merge/squash/rebase 三种合并；本计划的检查点约定使用 merge commit 合入，以保持后续分支的 merge-base 清晰。

## 9. P0.8 构建继承

- 门禁工程的 NuGet 审计只来自根 `Directory.Build.props`；
- 门禁工程能够构建只因 `docs/Directory.Packages.props` 关闭了中央包管理；同一工程放到 `docs/` 之外即继承根 CPM 并 NU1008（Test-V3ArchUnit 复现）；
- 无 `global.json`（SDK 浮动）、无 `NuGet.config`（源来自用户/机器配置）、无 lock file；
- `bin/obj` 写入 `docs/guards` 源码树；
- LayerGuard 引用 `ModelContextProtocol` 与 `Microsoft.Extensions.Hosting`，扩大了可信构建的依赖面。

这些是 P5（D14）V3 `build/` 基线的直接输入。

## 10. P0.9 修改频率

统计窗口 2026-06-01 至基线，按 commit 数计（同一 commit 多文件只计一次）：

| schema | commits | 文件变更 |
| --- | --- | --- |
| `profiles/ifx/rules` | 4 | 13 |
| `profiles/ifx/project-map` | 4 | 4 |
| `contracts` | 3 | 10 |
| `ci/jobs` | 3 | 3 |
| `profiles/ifx/tech-stack` | 3 | 3 |
| `policy/baselines`、`policy/layerguard` | 2 | 2 |
| `policy/g04/bindings` | 1 | 8 |
| 其余 | 1 | 1–2 |

**修正**：Plan 06 §12.4 的 r3 参考数据按文件变更计，把 `policy/g04/bindings`（8）列为第二位；按 commit 计它只修改过 1 次。依 §12.4"按 P0.9 实际频率"的规定，首批比较器顺序以本节为准：`profiles/ifx/rules`、`profiles/ifx/project-map`，其次 `contracts`、`ci/jobs`（P9 被 `required-checks.json` 取代）、`profiles/ifx/tech-stack`。统计只覆盖当前 V3_ifx 路径，不追溯 Plan 05 迁移前的历史。

## 11. P0.10 trust contract 分类

| 类型 | check |
| --- | --- |
| 判定型 | `v3-pre-diff`、`v3-specialized-g03`、`v3-specialized-g04`、`v3-specialized-g05`、`v3-specialized-plan04`、`v3-historical-integrity` |
| 混合型 | `v3-architecture`（MSBuild 注入盲区）、`v3-quality-assembly`（程序集由 head 构建） |
| 执行型 | `v3-quality-solution`、`v3-quality-frontend`、`v3-specialized-database`、`v3-cross-platform-ubuntu-latest`、`v3-cross-platform-windows-latest` |

相对 Plan 06 §11.3 初始表的确认：G03/G04/G05/Plan04 脚本不含 `dotnet build/test` 或 npm 调用，定为判定型；historical-integrity 确认判定型；cross-platform 执行 head 门禁包自身，定为执行型（按 §11.5 视为候选验证）。基线状态下 13 个 check 的入口、engine 与 policy 全部来自 PR head。

## 12. P0 门槛

| 门槛条件 | 结果 |
| --- | --- |
| 每个现有文件有唯一分类 | 通过：820/820，生成器对未分类失败关闭 |
| 每个命令有唯一分类 | 通过：70 个可执行文件均有 exposure/audience；11 个 tech-stack 命令中 `ifx-layerguard`、`ifx-package-test` 为门禁命令，其余 9 个为产品验证命令 |
| 每个 Gate 有唯一分类 | 通过：13 个 required check 均有 trust contract 类型 |
| 全部 trusted-base component 进入冻结清单 | 通过：17 个 component，判定链可执行文件无遗漏 |

结论：P0 完成，可以进入 P1。
