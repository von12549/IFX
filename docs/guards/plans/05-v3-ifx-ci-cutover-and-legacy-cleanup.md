# V3_ifx 全门禁接管、CI 切换与旧 Guardrails 清理计划

> 状态：已完成（2026-09-16）。P0–P8 全部完成；清理提交 `2bab176` 的 PR #26 run `34990329905` 在 Linux/Windows 上通过全部 13 个 V3 required checks。GitHub ruleset `IFX V3 Required Checks`（ID `23459908`）已启用；故意加入越界路径的 PR #27 在 run `34985968761` 中失败，GitHub 返回 `mergeStateStatus: BLOCKED`。
>
> 基线：`codex/guards-principles-plan` 已将 V3_ifx 与当前 Contracts/Adapter 架构对齐；V3 stage、独立 IFX LayerGuard、ArchUnitNET、Pre、Package 和 Tools 自测均已通过。旧 workflow 的同提交并行结果和已知差异保存在 `V3_ifx/stages/analysis/reports/specialized-parity.json`；自动执行链现只进入 `v3-ifx-guardrails.yml`。

## 目标与完成后的结构

V3_ifx 成为 IFX 唯一的门禁执行、编排、报告协议和检测器维护入口。GitHub Actions 只从 `.github/workflows/` 调用 V3_ifx；V3_ifx 内部按 Architecture、Specialized、Quality、HistoricalIntegrity、Pre 和 Diff 划分职责，并提供统一的 `All`/CI 聚合入口。

`mcp/LayerGuard` 项目及历史 baseline 永久保留，作为工具源码、迁移证据和回退参考，但退出生产 CI 执行链。生产架构扫描只运行一次，由 `docs/guards/V3_ifx/scripts/Invoke-IFX.ps1` 使用 V3_ifx policy 和零 entry strict baseline 完成。切换后不得同时运行 `scripts/Invoke-LayerGuard.ps1` 和 `Invoke-IFX.ps1` 扫描同一份 `src`。

G03、G04、G05、Plan 04 和数据库的专项能力全部迁入 V3_ifx。迁移的是检测器实现、fixture、测试、命令编排和报告契约；Contract catalog、deployment manifest、migration 源码、tenant/projection policy 等业务、发布和治理事实继续保留在各自领域目录，作为唯一权威来源。V3_ifx 可以生成并校验 package-local projection/snapshot，但这些文件必须由权威输入确定性生成并执行漂移检查，不能成为第二套可独立编辑的事实。

历史 Plan 00、03-A1/B1、B4 等验收由 V3 `HistoricalIntegrity` 接管。它只验证冻结证据的存在性、格式、摘要、引用关系和不可意外改写，不再把“下一步开始 Plan 01”、B1 必须有 116 个 finding、旧 blocker 数量等历史流程状态作为每次产品代码 PR 的当前结论。

目标目录与入口如下：

```text
docs/guards/
  V3/                              # 通用、可移植的 V3 源码包
  V3_backup/                       # 已验证的通用 V3 快照
  V3_ifx/
    profiles/ifx/                  # IFX 路径、风险、规则和命令映射
    policy/                        # 唯一生产架构 policy、生成的 Gate projection、strict baseline
    specialized/                   # G03/G04/G05/Plan04/Database 检测器与契约
    scripts/                       # Pre/Diff/Architecture/Specialized/Quality/HistoricalIntegrity/CI 入口
    tests/                         # 检测器正反例、隔离、漂移和跨平台测试
    history/                       # 冻结历史证据清单与 integrity manifest
    generated/                     # 可重现生成物和可读 views
  plans/                           # 永久保留：计划、实施记录和历史说明

mcp/LayerGuard/                    # 永久保留：工具源码及历史 baselines；不再是生产 CI 入口

.github/workflows/
  v3-ifx-guardrails.yml            # 唯一 IFX 门禁 workflow；只调用 V3_ifx 稳定入口
```

GitHub Actions workflow 必须位于 `.github/workflows/`。V3 workflow 负责自动触发、环境准备、调用 V3_ifx、上传证据和暴露稳定 job 名称；所有门禁逻辑都归 V3_ifx 所有。GitHub ruleset 将 13 个稳定 job 名称设置为严格 required checks，并要求 PR、对话解决、禁止删除和禁止 force push。

## 最终职责模型

| V3 模式/Job | 最终职责 | 不得重复执行的内容 |
| --- | --- | --- |
| `Pre` | 计划路径、area、owner、风险、规则和验证命令映射 | 不声称代码已经验证 |
| `Diff` | 真实 base/head changed set、Plan/decision、越界和受保护删除 | 不重新执行完整 Architecture |
| `Architecture` | 完整 IFX LayerGuard、policy binding、零 entry baseline | 全仓只执行一次完整 LayerGuard |
| `Specialized.G03` | Catalog、source reconciliation、字段/敏感分类、compatibility、handoff | 不嵌套执行 Architecture |
| `Specialized.G04` | Manifest、runtime role、startup、lease、drain、health、backpressure、release/failure | 不嵌套执行 Architecture 或全 solution test |
| `Specialized.G05` | Context、敏感数据、runtime propagation、redaction、replay 等专项检查 | 不重复 G03、Database、Architecture 或全 solution test |
| `Specialized.Plan04` | Extraction、tenant query、projection 和治理事实 | 不重放 B4 当前状态 |
| `Specialized.Database` | Pending model、migration inventory/safety、发布产物、SQL Server matrix | 不重复通用 solution build |
| `Quality.Assembly` | 所有受保护 Domain assembly 的编译后引用/类型边界 | 不只覆盖 CRM pilot |
| `Quality.Frontend` | `npm ci`、lint、test、build | 不把 profile 中的命令声明视为已执行 |
| `Quality.Solution` | 需要的 restore/build/test 公共前置与一次性全量回归 | G04/G05 不再各自全量执行 |
| `HistoricalIntegrity` | 冻结 Plan00/B1/B4 等证据的 hash/schema/link 完整性 | 不验证已经失效的历史流程状态 |
| `All` / CI dispatcher | 选择并聚合上述 job，输出统一 summary | 不实现第二套规则 |

## 保留、迁移与删除边界

### 永久保留

- `mcp/LayerGuard/**`，包括工具源码、测试、fixture、`LIMITS.md`、README 和 `baselines/**`。旧 baseline 明确标记为历史，不再作为生产 scan 输入。
- `docs/guards/V3/**`、`docs/guards/V3_backup/**`、`docs/guards/V3_ifx/**`。
- `docs/guards/plans/**`。现有 Plan 01–05 和后续计划继续保留在原目录。
- G03 catalog、G04 deployment artifacts、G05 protocol policy、Plan 04 governance policy、database migrations 和 migration/release manifest 等领域事实。它们由 V3 validator 读取，但不为迁移方便复制成第二套人工权威。
- 需要保留的历史 evidence。历史文件可以继续位于原 evidence 目录，由 V3 history manifest 绑定；只有运行入口和当前状态断言迁入 V3。

### 迁入 V3_ifx 后删除旧运行入口或副本

| 现有内容 | V3_ifx 目标位置或替代能力 |
| --- | --- |
| `docs/guards/inputs/TECH_STACK.json` | `V3_ifx/profiles/ifx/tech-stack.json` |
| `docs/guards/inputs/PROJECT_MAP.json` | `V3_ifx/profiles/ifx/project-map.json` |
| `docs/guards/inputs/rules/*.json` | `V3_ifx/profiles/ifx/rules/`、`policy/layerguard.json` 和对应 views |
| `docs/guards/bindings/ifx.json` | V3_ifx profile、policy 与统一命令映射 |
| `docs/guards/contracts/*.schema.json` | `V3_ifx/contracts/` 或 `V3_ifx/specialized/*/contracts/` |
| `docs/guards/generated/*` | `V3_ifx/generated/` 和 `profiles/ifx/views/` |
| `docs/guards/templates/new-project/` | 通用部分进入 V3，IFX 部分进入 V3_ifx |
| `docs/guards/decisions/*.json` | `V3_ifx/decisions/history/` 或新的 Plan/decision 契约 |
| `docs/guards/principles/` | 长期背景迁入 `docs/guards/plans/history/`，其余删除 |
| `scripts/guards/*`、`tests/guards/*` | V3_ifx stage、assembly、CI、fixture 和 package tests |
| `scripts/Invoke-LayerGuard.ps1`、`src/layerguard.json` | V3_ifx `Invoke-IFX` 与 `policy/layerguard.json`；旧文件在切换后删除或作为明确的历史快照移入 history，不得继续充当可编辑 policy/入口 |
| 根 `Invoke/Test-G03*` | `V3_ifx/specialized/g03/` 及统一 Specialized 入口 |
| 根 `Invoke/Test-G04*` | `V3_ifx/specialized/g04/` 及统一 Specialized 入口 |
| 根 `Invoke/Test-G05*` | `V3_ifx/specialized/g05/` 及统一 Specialized 入口 |
| 根 `Test-Plan04*`、相关 fixture | `V3_ifx/specialized/plan04/` |
| 根 database migration guard/fixture | `V3_ifx/specialized/database/`；实际 migration 和发布 artifact 仍在领域目录 |
| `Test-Plan00PrerequisiteRelease.ps1`、`Test-03A1PolicyBinding.ps1`、`Test-Plan03B4StrictClosure.ps1` | `V3_ifx/history/manifest.json` 与 `HistoricalIntegrity` |
| 七个现行 guard workflow | `.github/workflows/v3-ifx-guardrails.yml` 中稳定命名的 V3 jobs |

最终删除 `docs/guards` 下非 V3、非 plans 的 README、bindings、contracts、decisions、generated、inputs、principles 和 templates。所有删除都必须使用精确文件清单，并在引用扫描、并行 CI、required-check 切换和回退验证完成后执行。

## P0 — 冻结现状、重复调用与能力矩阵

- [x] P0.1 记录当前分支 SHA、全部 workflow、根 guard 脚本、测试、权威输入、生成物、报告、CODEOWNERS 和外部引用。保存每个入口的触发范围、运行平台、命令、退出码、artifact 与 required-check 名称。证据：`V3_ifx/stages/analysis/reports/cutover-baseline.json`。
- [x] P0.2 建立实际调用图，明确记录当前重复：LayerGuard 被 `layerguard`、G03、G04、G05 多次执行；G03 catalog 被 LayerGuard/G03/G05 重复；migration safety 被 G05/Database 重复；solution build/test 被 G04/G05/Database 部分重复。证据：`V3_ifx/stages/analysis/reports/CUTOVER-BASELINE.md`。
- [x] P0.3 在干净 checkout 重跑现行 LayerGuard、Coding Guardrails、G03/G04/G05、Plan 04、Database、Domain assembly、frontend 和 solution 回归。保存命令、退出码、测试数和报告 hash；G03、G04、Plan04 的既有失败已登记为 `G03-CLIENT-EVIDENCE`、`G04-CANONICAL-HASH`、`P04-FROZEN-HASH`。
- [x] P0.4 为每项能力建立“旧入口—旧实现—权威输入—V3 目标检测器—正例—负例—报告—删除条件”矩阵。静态绑定与运行时/行为验证已在本计划职责模型和 cutover baseline 中分开记录。
- [x] P0.5 冻结永久保留清单并加入机械断言：`mcp/LayerGuard/**`、三个 V3 目录、`docs/guards/plans/**` 和领域权威事实不得被清理脚本匹配。清单记录于 `cutover-baseline.json`，机械断言在 P2/P7 测试中实现。
- **验收**：每个旧文件、检测器和 workflow job 都有唯一的保留、迁移、历史化或删除结论；所有已知重复都有明确去重目标。

## P1 — 定义 V3 统一入口、唯一权威和报告契约

- [x] P1.1 为 V3_ifx 定义稳定的 `Pre`、`Diff`、`Architecture`、`Specialized`、`Quality`、`HistoricalIntegrity` 和 `All` 入口。各入口必须非交互、参数明确、支持 Linux/Windows 所需路径，并把 JSON/TRX/log 写入 `artifacts/guards/`。
- [x] P1.2 定义统一 summary schema：记录 mode、detector、输入摘要、开始/结束、结论、失败类别、证据路径和跳过原因。子检测器保持细节报告，同时由 dispatcher 汇总；任何未执行或缺少证据的 blocking 项不得显示为 pass。
- [x] P1.3 建立 authority registry，逐项指定唯一权威来源。V3 architecture policy 只以 `V3_ifx/policy/layerguard.json` 为准；G03/G04/G05/Plan04/Database 的领域事实继续以各自领域文件为准。
- [x] P1.4 将 V3_ifx 当前 G03/G04/G05 package-local 文件改为确定性 projection/snapshot：生成器从 authority registry 读取权威输入、规范化必要的本地路径并更新 hash；Check 模式拒绝内容或 hash 漂移。禁止同时人工编辑两边。
- [x] P1.5 为 workflow job 和检测器 ID 定义稳定命名，避免 required checks 因显示名变化失效。明确每个 job 是否 always-run、path-focused、manual 或 scheduled。
- **验收**：V3_ifx 对规则和领域事实都只有一个人工权威；本地副本均可重现；所有模式与报告可由机器区分 pass、fail、blocked 和 skipped。

## P2 — 接管 Coding Guardrails、Pre/Diff、Assembly 与 Frontend

- [x] P2.1 将根 Coding Guardrails 的 area、owner、risk trigger、command、decision 与 Diff 失败语义迁入 V3 profile/contracts。保留增删改名、未跟踪文件、越界路径、受保护删除、未知 module、浅克隆和缺 decision 的 fail-closed 行为。
- [x] P2.2 完成 CI-safe Diff：显式消费 PR base/head SHA，计算真实 merge-base 和完整 changed set，再与 V3 Plan/decision 对账。不得只检查 Plan 声明路径，也不得因空 diff 或 fetch 深度不足误报通过。
- [x] P2.3 将旧 Domain assembly guard 的全模块覆盖迁入 V3 compiled architecture。显式列出全部受保护 Domain assembly、允许引用和类型边界，保留违规、缺程序集、陈旧程序集和零匹配负例；CRM pilot 只能作为其中一个 fixture。
- [x] P2.4 将 frontend `npm ci`、lint、`test:run`、build 四步接入 V3 Quality。profile 负责影响映射，CI job 负责 Node/cache/实际执行；命令声明不能替代运行证据。
- [x] P2.5 把 portable template、自身配置、生成漂移、Pre/Diff、package isolation、换行和命令选择纳入 V3_ifx tests。每个 blocking 能力都必须有导致非零退出码的负例。
- **验收**：旧 Coding Guardrails 四个 job 的真实能力均有 V3 可运行替代；compiled architecture 覆盖不低于旧全模块 guard；frontend 四步均实际执行。

## P3 — 接管 G03/G04/G05/Plan04/Database 专项门禁

- [x] P3.1 建立 `V3_ifx/specialized/` 目录、共享 runner、detector contract、fixture contract 和报告聚合器。迁移初期允许 V3 wrapper 调用根旧脚本，但报告必须标记 `legacy-wrapper`，且不得形成永久依赖。
- [x] P3.2 迁移 G03：catalog schema/reference、ownership/approval、field classification、sensitive-use、source reconciliation、compatibility snapshot、cycle、documentation/closeout 和负例。与 Architecture 重合的 provider graph/hash 只由 Architecture 产出，G03 消费或交叉核对其报告，不重新扫描 LayerGuard。
- [x] P3.3 迁移 G04：manifest/hash、runtime role、startup ordering、dispatcher lease、drain、health、backpressure、release orchestration、failure matrix、documentation/closeout 和行为测试。移除内部 LayerGuard 与全 solution test 调用，改为声明对 Architecture/Quality.Solution job 的依赖。
- [x] P3.4 迁移 G05：context contract、sensitive data、runtime propagation、redaction、delivery/replay、catalog-security 交集、migration-safety 交集、documentation/closeout 和行为测试。G05 使用 G03、Database、Architecture 的已验证结果，不再次执行其实现。
- [x] P3.5 迁移 Plan 04：baseline/inventory/audit、extraction、tenant query、projection、Abstractions retirement、documentation 和 fixture。`L1.2` 的项目命名结果来自 Architecture；Plan04 保留 solution membership、tenant/projection 等独有治理断言。
- [x] P3.6 迁移 Database：pending model、inventory、migration safety、release artifact、publish、database boundary tests 和 SQL Server matrix。实际 migrations、manifest 和 safety policy 继续保留在数据库/部署目录。
- [x] P3.7 把 G04/G05 重复的 solution restore/build/test 收敛为 `Quality.Solution`；专项 job 只运行焦点测试并引用公共 build artifact 或明确的上游结论。
- [x] P3.8 对每个专项 detector 运行旧版与 V3 版的正常、违规、缺输入、hash 漂移和报告 schema 对照。只有结论、覆盖和失败关闭行为相同或更强，才允许退出 wrapper 阶段。对照记录：`V3_ifx/stages/analysis/reports/specialized-parity.json`；projection drift、缺 authority 和 schema 负例由 V3_ifx tests 执行。
- **验收**：五类专项门禁全部由 V3_ifx 自有实现运行，不调用根旧 validator；与 Architecture/其他专项的重复执行已经去除；每类独有行为验证和负例均保留。

## P4 — 接管历史验收并去除失效状态断言

- [x] P4.1 清点 Plan00、03-A1/B1、B2/B3/B4、Plan05/06/07 baseline 与报告，区分“必须冻结的历史事实”和“已经失效的下一步、blocker 数量、workflow 自引用、当前状态”断言。
- [x] P4.2 建立 `V3_ifx/history/manifest.json`，记录保留文件、用途、schema/version、内容 hash、允许变更方式和替代关系。历史 baseline 保持原内容，不重新生成来适配当前 policy。
- [x] P4.3 实现 `HistoricalIntegrity`：验证文件存在、JSON 可读、摘要匹配、内部引用可解析、baseline 元数据有效且历史标签明确。移除“Plan 01 尚未开始”“B1 仍是当前 policy”“workflow 必须调用自身”等断言。
- [x] P4.4 配置触发策略：历史/evidence/manifest 变更时 blocking；定时或手动可运行全量；普通产品代码 PR 仅运行 hash/schema/link integrity，不重放旧流程状态验收。
- [x] P4.5 用受控负例证明删除、篡改、错误 hash、悬空引用会失败，同时当前 Plan 07+ 代码状态不会因旧 blocker 数量变化失败。
- **验收**：历史证据仍受保护，但不再参与当前架构或业务 readiness 判断；三个旧历史脚本可以安全删除。

## P5 — 新建 V3 workflow 并与全部旧门禁并行验证

- [x] P5.1 新建 `.github/workflows/v3-ifx-guardrails.yml`，包含稳定命名的 Pre/Diff、Architecture、Specialized.G03/G04/G05/Plan04/Database、Quality.Solution/Assembly/Frontend 和按触发条件运行的 HistoricalIntegrity jobs。
- [x] P5.2 workflow 在 PR 和 main push 上运行；需要历史完整性全量审计时增加 schedule/manual。checkout 为 Diff 提供完整或足够 Git 历史，显式传入 base/head SHA；固定 .NET、PowerShell、Node、NuGet 和数据库服务前提。
- [x] P5.3 Architecture 只调用一次 `Invoke-IFX`。所有专项 job 禁止调用 `Invoke-LayerGuard`、`Invoke-IFX` 或另一个完整专项入口；通过 needs/artifact/summary 复用已完成结论。
- [x] P5.4 迁移期保留七个旧 workflow 并行运行。提交 `073ebe4` 的新旧结论、报告、已知差异和耗时已记录于 `specialized-parity.json`；旧 Coding Guardrails 的三个测试在输出 passed 后因遗留 `$LASTEXITCODE` 返回 1，旧 G03/LayerGuard 受 Client-backed consumer evidence 限制，旧 Plan04 仍绑定冻结 hash。
- [x] P5.5 Linux 和 Windows 已在 V3 run `34978867655` 分别通过跨平台 Validate/Generate Check/Diff/tests；数据库、frontend、solution、assembly 和全部专项 job 均通过并上传证据。
- **验收**：正常 PR 所需 V3 jobs 全绿；生成漂移、缺 decision、越界 diff、LayerGuard 违规、G03/G04/G05/Plan04/Database 违规、Domain assembly 违规和 frontend 失败均被对应 V3 job 阻断。

## P6 — Required checks 切换与唯一生产入口

- [x] P6.1 在提交 `073ebe4` 上形成新旧全门禁对等报告。V3 Architecture 为零 entry baseline clean；五类专项、solution、assembly 和 frontend 满足覆盖矩阵。
- [x] P6.2 GitHub ruleset `23459908` 已启用，目标为默认分支和 `codex/guards-principles-plan`；无 bypass，13 个 required checks 均绑定 GitHub Actions，`strict_required_status_checks_policy=true`。
- [x] P6.3 PR #26 正常 runs 全绿。负向 PR #27 故意加入 formal Plan 未声明的 `ruleset-negative-proof.txt`，run `34985968761` 的 `v3-pre-diff` 失败，PR 状态为 `BLOCKED`；验证后已关闭 PR 并删除临时分支。
- [x] P6.4 V3 是唯一 PR/main 自动生产门禁，完整 Architecture scan 每次 CI 只执行一次。七个旧 workflow 在切换期先降为手动，负向验证完成后进入 P7 删除。
- [x] P6.5 Free Plan 的 403 阻塞与临时降级路径保留为历史决策；升级后已通过 API 和真实 PR 完成平台强制验证，永久清理门槛解除。
- **验收**：V3_ifx 是唯一生产门禁入口；LayerGuard、专项、历史、assembly、frontend 和 Diff 都由 13 个 required V3 jobs 执行，违规 PR 被平台阻止合并。

## P7 — 删除旧入口、实现和非 V3 文档

- [x] P7.1 删除 `.github/workflows/layerguard.yml`、`coding-guardrails.yml`、`contract-event-governance.yml`、`g04-deployment-runtime.yml`、`g05-context-boundary.yml`、`plan04-governance.yml` 和 `database-migrations.yml`。最终只保留调用 V3_ifx 的统一 workflow；如仓库还有非 guard workflow，不受本计划影响。
- [x] P7.2 删除已迁移的 `scripts/guards/`、`tests/guards/`、根 LayerGuard wrapper、G03/G04/G05/Plan04/Database validator 与对应仅供旧实现使用的 fixture。精确删除清单记录 103 个路径，未递归清理整个 `scripts` 或 `tests`。
- [x] P7.3 删除旧 `src/layerguard.json`；运行时引用扫描为零，`V3_ifx/policy/layerguard.json` 是唯一生产架构 policy。
- [x] P7.4 删除 `docs/guards` 下非 V3、非 plans 的 README、bindings、contracts、decisions、generated、inputs、principles 和 templates。`Test-CutoverPreservation.ps1` 验证所有删除目标及最终顶层目录。
- [x] P7.5 更新 README、workflow、脚本、测试、CODEOWNERS 和当前架构文档链接；旧入口、旧 check 名、待删除路径、`Invoke-LayerGuard` 和根专项 validator 的非历史运行时引用扫描为零。
- [x] P7.6 `Test-CutoverPreservation.ps1` 已断言 `mcp/LayerGuard`、8 个历史 baseline 与 `docs/guards/plans` 均保留，并断言 `docs/guards` 顶层只含 `V3`、`V3_backup`、`V3_ifx`、`plans`。
- **验收**：干净 checkout 不包含旧 Guardrails 运行时、重复 workflow、第二套可编辑 policy 或悬空链接；唯一生产调用链全部进入 V3_ifx。

## P8 — 最终回归、证据与回退验证

- [x] P8.1 清理提交 `2bab176` 的 PR #26 run `34990329905` 已在干净 Linux/Windows runner 通过 Validate/Generate/Check、Pre/Diff、Architecture、全部 Specialized、HistoricalIntegrity、Quality.Solution/Assembly/Frontend 和 package/tools tests；本地 Windows 也完成同等回归。
- [x] P8.2 V3、ArchUnit、Tools、Pre、Authority Projection、Specialized Contracts、Historical Integrity 与 Package 测试已覆盖 policy/hash drift、project/source/compiled boundary、各专项违规、history tamper 和缺输入的非零退出；Frontend 正常链执行 `npm ci`、lint、63 tests 与 build。
- [x] P8.3 workflow 结构验证完整 LayerGuard 只由 `v3-architecture` 执行一次；专项 job 通过 `needs` 复用 Architecture/Quality 结论。迁移前后的 job 耗时记录在 `specialized-parity.json`。
- [x] P8.4 `legacy-deletion-manifest.json` 固定删除前提交 `15b44e5c8cae5968b8cd43a9b4c2a9574727577b`；已对全部 103 个删除路径执行 `git cat-file -e`，确认均可选择性恢复，且保留区不参与回退。
- [x] P8.5 V3_ifx DEPLOYMENT、IFX-MIGRATION、`ci/jobs.json`、cutover decision、本计划和 deletion manifest 已记录最终 job、13 项 required checks、权威来源、生成/报告流程、故障排查、回退步骤及删除清单。
- **验收**：新生产入口可从干净 checkout 重现；所有 blocking 正反例、跨平台和真实 PR 强制均有可审查证据；没有 tracked/untracked 旧目录回生。

## 删除门槛

以下条件必须全部满足，才能执行 P7：

1. V3_ifx 已覆盖旧 Coding Guardrails、LayerGuard、G03、G04、G05、Plan04、Database、Domain assembly 和 frontend 的实际职责，并有正反例证明。
2. 新 workflow 已在真实 PR 与 main 路径运行；所需 Linux/Windows、数据库和 frontend jobs 均通过。
3. V3 Diff 使用真实 base/head changed set，并保留高风险 decision、重命名、未跟踪文件和受保护删除语义。
4. V3 Architecture 使用唯一 policy 和零 entry baseline，且一次 CI 只运行一次完整 LayerGuard。
5. 专项 detector 已迁入 V3_ifx，不再通过 wrapper 调用根旧 validator；静态交集通过上游报告复用，独有行为测试仍在。
6. compiled architecture 覆盖不低于旧全模块 Domain assembly guard；零匹配、缺程序集和陈旧程序集失败关闭。
7. frontend `npm ci`、lint、test、build 与数据库发布/SQL matrix 均有实际运行证据。
8. HistoricalIntegrity 能阻止历史证据删除/篡改，同时不再断言失效的旧流程状态。
9. GitHub required checks 已实际切换，并由真实违规 PR 证明失败会阻止合并。
10. `mcp/LayerGuard/**`、`docs/guards/plans/**` 和领域权威事实已通过存在性、hash 和清理排除断言。
11. 所有待删除路径的运行时引用为零，V3 package-local policy projection 可由唯一权威输入重现。

## 完成定义

完成后，`docs/guards` 顶层只包含 `V3`、`V3_backup`、`V3_ifx` 和 `plans`。Plan 01–05 保留在 `docs/guards/plans`，`mcp/LayerGuard` 项目及历史 baselines 完整保留但不参与生产 CI。

`.github/workflows/v3-ifx-guardrails.yml` 是唯一 IFX 门禁 workflow。它从 V3_ifx 调用 Pre、Diff、Architecture、Specialized、Quality 和 HistoricalIntegrity；完整 LayerGuard 在每次 CI 中只执行一次。13 个稳定 job 名称由 GitHub ruleset 强制。G03/G04/G05、Plan 04 和 Database 的检测器实现、fixture、报告契约及编排属于 V3_ifx，领域事实仍保持各自唯一权威。历史门禁保护冻结证据完整性，不再把旧迁移阶段状态当作当前 readiness。

旧 workflow、根 guard 实现、重复配置和非 V3 文档在 required-check 切换后按 `V3_ifx/stages/analysis/evidence/legacy-deletion-manifest.json` 删除。恢复时从清单记录的删除前提交选择性取回，不修改永久保留的 `mcp/LayerGuard`、历史 baselines、plans 或领域权威事实。
