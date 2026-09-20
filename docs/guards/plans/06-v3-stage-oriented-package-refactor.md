# V3 Stage 化、自包含配置与门禁工程重构计划

> 状态：**APPROVED / 已整合 Review 第一至十四章 / 最终修正完成 / 已授权实施（2026-09-16）**。
>
> 本文综合 V3、V3_backup、V3_ifx 对比 Review，以及 [06-v3-stage-oriented-package-refactor.review.md](06-v3-stage-oriented-package-refactor.review.md) 第一至十四章的共识形成。§19 全部前置条件已完成，用户已于 2026-09-16 明确授权实施；执行按正式 Plan pair [20260916-v3-stage-oriented-package-refactor](20260916-v3-stage-oriented-package-refactor.md) 的检查点 CP01（P0）起逐步进行。每个检查点仍须建立自己的 Plan pair；目录移动、生成物切换、CI 激活和删除只能在对应检查点按本计划与 §12 授权执行，CI 激活另需单独授权（P11.4）。

## 0. 修订记录

| 版本 | 来源 | 主要变化 |
| --- | --- | --- |
| r1 | commit `ad3e67d` | 初版：目标、原则、P0–P9、D1–D8 |
| r2 | Review §1–§9 | 按最终答复修正 D1/D2/D4；新增门禁信任模型（§11）与受保护路径迁移授权（§12）；通用 Diff 加固先合回 V3；Architecture Conformance engine 与 IFX binding 分离后进入 V3；Stage Gate 参数化命名并移出 Git；workflow 改为轻量模板；元数据与聚合文档精简；构建输出重定向不得丢失根 MSBuild 安全配置；执行顺序重排为 P0–P11；新增 D9–D12；登记暂缓项 O1（git 端审查设置，本计划不做决定） |
| r3 | Review §10–§13 | 见下表 |
| r4 | Review §14 | 补齐 trusted-base 组件自身的候选升级协议；新增 TCB manifest、base-owned validation、`change-trusted-base` 授权与 parity；可信 restore 改为 lock-file/locked-mode，并允许经 lock/content hash 验证的 NuGet build assets 与隔离生成文件参与 import |

r3/r4 逐项来源：

| 修订内容 | 来源章节 | 落点 |
| --- | --- | --- |
| decision 记录改为正式执行准备阶段首次创建，P1.1 改为校验与补充 | 10.1 | §14 P1.1、§19 |
| workflow 之后第一个可执行入口及完整调用链来自 base；wrapper/dispatcher/module manifest/`commands.json` 篡改负向控制 | 10.2 | §11.1、P2.1、P2.5 |
| 逐 Gate trust contract，替代判定型/执行型二元分类；Architecture Conformance 为混合型并写明交叉兜底 | 11.2、12.2、13.3 | §11.3、P0.4、P0.10、P2.4、P6.5 |
| policy/config 双轨验证；schema-specific monotonicity；未知变化失败关闭；零比较器起步；削弱复用授权协议 | 10.3、11.3、12.1、13.2 | §12.4、P0.9、P4.3–P4.4、D13 |
| V3 package-local 构建与安全基线；可信构建位于 head 与 base 之外；禁止自动向上搜索；宿主配置仅显式叠加；有效 import 断言；V3 隔离运行验收 | 10.4、11.4、12.3、13.4 | §8.3、§11.2、P2.2–P2.3、P5、P7.2、D14 |
| 授权使用 tree-entry tuple、已验证 merge-base、NUL 分隔 raw diff；大小写重命名独立 operation；gitlink 拒绝；端点可靠性依赖 `strict` | 10.5、11.5、12.4、13.5 | §12.2–§12.3、P4.1–P4.2、P1.3 |
| 保证范围限定语统一应用到全部绝对性表述 | 10.6 | §2.6、§12.5、P4 门槛、§15、§16、D10 |
| evidence 唯一 owner；analysis evidence/reports 生命周期分类 | 10.7 | §2.2、§5、§6、§13、P0.2、P8.6 |
| 原 §8.3 方案 A（嵌套 `Directory.Build.props` import 根配置）不再采用 | 10.4、12.3 | §8.3 |
| 新增 D13、D14 | 12.1、12.3 | §17 |

## 1. 背景与问题陈述

V3 已形成 Analysis、Pre、Post、Diff 和 CI 等阶段能力，V3_ifx 进一步接管了 IFX 的独立 LayerGuard、专项门禁、质量门禁、历史完整性和 CI 编排。现有能力总体有效，但目录、维护模型和门禁信任边界出现以下问题：

1. 通用 V3 源码、IFX 配置、运行脚本、模板、生成物、历史材料和证据按不同维度平铺在根目录，职责需要跨目录理解。
2. `.github/workflows/` 等激活文件位于 V3 外部，V3 内缺少完整的权威声明、确定性生成、预览、安装和反向验证链。
3. `scripts/` 同时包含人工入口、CI 入口、内部运行脚本、生成器和维护命令；仅看文件名无法判断调用边界、副作用和稳定性。
4. `templates/ifx-layerguard/` 与 `generated/dotnet/LayerGuard/` 存在 174 文件的逐字节重复；后者实际是正式架构门禁，不只是普通 Unit Test。
5. `generated/stages`、`generated/dotnet` 等名称主要表达实现技术，未准确表达 Stage、门禁职责和生命周期；`generated/stages` 还被 Git 跟踪并包含 profile JSON 副本。
6. JSON 仍是机器权威，但现有 Markdown 视图覆盖有限，且已经出现 profile JSON、Markdown views 和 architecture review 不同步的实例。
7. V3_ifx 逐字节复制了 V3 的通用脚本、hooks 和测试；同时 `templates/dotnet/GuardTests.cs.in`、`tests/Test-V3.ps1` 已经分叉，V3_ifx 中的 Diff 加固（merge-base 校验、受保护路径删除/重命名检测、空 changed set 失败）尚未合回 V3。
8. 现有 Diff 门禁在 `GuardTests.cs.in:IsProtectedGuardPath` 中硬编码受保护路径，任何删除或重命名 `docs/guards/V3*`、`docs/guards/plans/`、`mcp/LayerGuard/`、workflow 和 CODEOWNERS 的 PR 都会失败，因此本计划的去重、删除和目录迁移无法直接通过。
9. CI 从 PR head 的 checkout 调用入口脚本（例如 `docs/guards/V3_ifx/scripts/Invoke-IFXGuardrails.ps1`）并生成、执行门禁；PR 可以同时修改入口、检测器、保护路径和被检查内容，门禁可被 PR 自身削弱。`.github/CODEOWNERS` 虽然指派了 owner，但 ruleset `23459908` 当前 `require_code_owner_review = false`、`required_approving_review_count = 0`，CODEOWNERS 审查并不被强制（r2 只读核实）。
10. 门禁 .NET 工程的构建依赖宿主仓库的隐含配置：根 `Directory.Packages.props` 启用 `ManagePackageVersionsCentrally=true`，Stage Gate 模板使用带 `Version` 的 `PackageReference`，当前只能依靠 `docs/Directory.Packages.props` 关闭中央包管理才能构建；NuGet 安全审计也来自根 `Directory.Build.props`。V3 自身不具备可移植的构建与安全基线。
11. LayerGuard（`CsprojReader.cs`）通过 XDocument 读取 csproj 元素，不解析 `<Import>`、Condition 或 `Directory.Build.*` 注入的 `ProjectReference`；Assembly 检查读取由 head 代码构建的程序集。两类检测各有盲区，目前没有显式的信任契约说明其保证范围。
12. trusted base 自身也需要受控升级：若 head 同时修改入口、engine、contracts、base tests 或构建基线及其测试，当前 base 虽不会被同一 PR 篡改，但这些候选实现合并后会成为下一次 trusted base；仅运行 head 自带测试不能防止“两步削弱”。

现状规模（r2 核对）：V3 41 个 tracked 文件；V3_ifx 537 个 tracked 文件，其中 348 个为 LayerGuard template/generated 双份；PowerShell 实现合计约 1.8k 行；workflow 285 行，13 个 required checks。本计划新增的治理元数据必须与该规模相称。

## 2. 目标

### 2.1 配置与激活

- V3 所需的全部机器配置、模板、生成声明、部署映射，以及最低完整的 build、package、SDK/NuGet 和安全基线，都位于 V3 包自身目录。
- IFX 专用配置全部位于 V3_ifx 自身目录，不以 `.github/`、根脚本、宿主父目录 MSBuild 配置或其他历史目录作为隐藏配置权威。
- GitHub workflow、CODEOWNERS managed block 及其他必须复制到目标位置的文件，先在 V3 内由轻量模板确定性生成和验证，再由人工显式确认安装或复制。
- 候选文件是可再生产物；目标位置文件只是激活副本。二者必须能够反向验证。

### 2.2 Stage 信息架构

- 从目录、文件名、manifest 和文档中能够直接识别 Bootstrap、Analysis、Pre、Post、Diff、CI 以及 Shared/Governance 的职责。
- 配置以主要消费 Stage 归类；跨 Stage 输入只保留一个 `shared/` 权威，不在多个 Stage 复制。
- 每个 Stage 声明所属命令、依赖、enforcement、文档和 Gate trust contract；证据路径由 command manifest 唯一声明，Stage 通过所引用的 command 解析证据。每个字段只有一个 manifest owner。

### 2.3 脚本与命令模型

- 区分公共命令、内部引擎、生成器、宿主适配器、维护工具和测试辅助程序。
- 人类、Agent 和 CI 尽量调用同一公共命令接口，不复制门禁逻辑。
- 每个公共命令都有机器可读的 Stage、audience、副作用、稳定性、输入和输出声明。
- 未来加入 Python、JavaScript、.NET tool 或其他运行时，不改变分类模型。

### 2.4 .NET 门禁工程

- 生成工程按门禁职责命名，不按 `UnitTest`、`ArchUnitNET` 或 `dotnet` 等实现细节命名。
- V3 profile 驱动的 Self/Post/Diff 工程命名为 Stage Gate，项目名由 profile project ID 参数化，在工程内部按测试类别拆分。
- LayerGuard 派生实现先完成去重，再把 IFX-specific binding 剥离到 V3_ifx，通用检测引擎作为 Architecture Conformance Gate 进入 V3。
- 本次迁移只调整所有权、命名、位置、调用契约和重复模型，不代表检测引擎已被 V3 原生实现取代；内部实现替换属于 §20 的独立后续计划。
- 门禁 .NET 工程只加载 V3 package-local 的构建与安全基线，不依赖宿主父目录配置；`bin/`、`obj/`、报告和运行日志全部移出 `docs/guards` 源码树。

### 2.5 JSON 与 Markdown

- JSON 继续是唯一机器语义权威。
- 全部生成 Markdown 只读，不支持 Markdown → JSON Import。
- 生成文档列出来源路径和角色，并附一个 composite hash；不逐源列 hash。
- 生成 Markdown 与人工 Markdown 分离；生成器不得覆盖人工设计理由。
- 首批只生成 `OVERVIEW.md`、`COMMANDS.md`、`POST.md`、`CI.md`，出现真实阅读需求后再拆分。

### 2.6 门禁信任与迁移安全

以下目标均在 §11.4 保证范围内成立：

- PR 门禁从 workflow 之后的第一个可执行入口起，使用受信任 base 中的 orchestrator、engine、contracts、protection config、policy 和授权，对 head/merge checkout 做检查（§11）。
- 每个 Gate 都有 trust contract，声明 evaluator、policy 和 target input 的来源以及实际保证范围（§11.3）。
- 受保护路径的删除、移动，以及 policy/config 的潜在削弱，只能消费 base 中预先合入的精确授权，并在同一 diff 中删除该授权（§12）。
- 下一次将进入 trusted base 的入口、engine、contracts、base-owned tests、构建基线和 lock files 等组件具有 TCB manifest、base-owned candidate validation 与 parity；非等价语义变化需要 `change-trusted-base` 预授权（§11.5、§12）。
- 13 个 required check 名称是本计划全程不变量（§10.3）。
- 位于隔离目录中的 V3 源码包能独立构建运行，并能从空白 fixture 仓库 Bootstrap 出可运行的门禁。

## 3. 非目标

- 本计划不改变 IFX 当前业务架构规则的语义；新增检测规则（例如针对 MSBuild import 注入的规则）必须另行 decision。
- 本计划不借目录迁移弱化、豁免或删除任何 blocking gate。
- 本计划不自动安装 GitHub workflow、修改远端 ruleset 或变更 required checks。
- 本计划不改变任何 required check 名称；改名只能作为单独授权的变更。
- 本计划不在未完成正反例与并行验证前删除旧入口。
- 本计划不要求每个 Stage 建立独立进程或独立 .NET 项目。
- 本计划不以目录整洁为理由复制 shared 配置或拆分出重复实现。
- 本计划不重写或移除 LayerGuard 派生的检测算法；只剥离 IFX binding，并调整其所有权、命名、位置、调用契约和重复生成模型。
- 本计划不提供 V3_ifx self-contained 分发，不引入 `core.lock.json`，不保留 V3_backup snapshot。
- 本计划不引入可描述任意 GitHub Actions 的 JSON DSL。
- 本计划不使用 `pull_request_target` 执行 PR 代码，不在仓库内实现可自行调用的门禁 bypass。
- 本计划的门禁审查范围限于项目本身的代码与架构层面；不收紧 git 端审查标准，不修改 ruleset 审批设置（§18 O1 暂缓）。

## 4. 权威与生命周期模型

按照以下优先级定义事实：

1. **JSON authority**：Stage 配置、规则、policy、toolchain、activation、command、required checks、trust contract 和 document manifest。
2. **Implementation**：PowerShell/.NET/其他语言实现、模板与 package-local 构建基线；实现解释 JSON，不暗藏项目 policy。
3. **Generated candidate**：Markdown、Stage Gate 源码、GitHub workflow、CODEOWNERS managed block 等可再生产物。
4. **Activated copy**：目标 `.github/` 等宿主读取位置中的副本。
5. **Runtime evidence**：`artifacts/guards/` 下的报告、TRX、日志、hash 和 summary。

低层不得反向成为高层的隐含权威。激活副本不得直接编辑；运行证据不得被当成当前配置，也不得反向参与可信判定逻辑。

对 PR 做判定时：

- 第 1、2 层以及授权一律取自受信任 base，作为当前 PR 的唯一权威判定依据（§11）；
- head 中的第 1、2 层变更只作为候选数据接受 schema、引用完整性、coverage、parity 与单调性检查，不控制当前 PR 的判定，合并后才生效（§12.4）。

## 5. 建议目标结构

以下是方向性结构。最终路径在正式执行 Plan 中冻结。

```text
docs/guards/V3/
├─ guard-system.json
├─ build/                        # package-local 构建与安全基线（§8.3）
│  ├─ V3.Build.props             # NuGetAudit、warnings-as-errors 等安全基线
│  ├─ V3.Packages.props          # 门禁工程包版本
│  ├─ NuGet.config
│  ├─ global.json
│  └─ locks/                      # 各可信门禁工程的 packages.lock.json 权威/模板
├─ shared/
│  ├─ contracts/
│  ├─ toolchain.json
│  ├─ commands.json
│  ├─ trusted-components.json    # TCB 路径、base-owned validation 与 parity 契约
│  ├─ authorities/
│  └─ decisions/
├─ stages/
│  ├─ bootstrap/
│  ├─ analysis/
│  ├─ pre/
│  ├─ post/
│  │  └─ gates/
│  │     └─ architecture/
│  │        └─ dotnet/
│  │           ├─ Guards.ArchitectureConformance/
│  │           ├─ Guards.ArchitectureConformance.Tests/
│  │           └─ Guards.ArchitectureConformance.slnx
│  ├─ diff/
│  │  ├─ authorization.schema.json
│  │  └─ monotonicity/           # 各 schema 的单调性比较器声明
│  └─ ci/
│     └─ templates/
├─ commands/
├─ engine/
│  ├─ common/
│  ├─ modules/
│  ├─ trusted-base/
│  └─ stages/
├─ generators/
│  ├─ docs/
│  ├─ stage-gate/
│  └─ activation/
├─ integrations/
│  ├─ github/
│  └─ agents/
├─ maintenance/
├─ docs/
│  ├─ authored/
│  ├─ generated/
│  └─ docs-map.json
├─ tests/
│  ├─ analysis/
│  ├─ pre/
│  ├─ post/
│  ├─ diff/
│  ├─ ci/
│  ├─ bootstrap/
│  ├─ isolation/
│  └─ support/
└─ examples/

docs/guards/V3_ifx/
├─ guard-system.json
├─ shared/
├─ stages/
│  ├─ analysis/
│  │  ├─ evidence/               # 经评审、长期保留的输入与基线（authority/history 角色）
│  │  ├─ drafts/
│  │  └─ reports/                # 仅经评审冻结的报告快照；运行时输出进入 artifacts
│  ├─ pre/
│  ├─ post/
│  │  ├─ rules/
│  │  ├─ policy/
│  │  └─ gates/
│  │     ├─ architecture/        # IFX binding、policy、baseline、IFX fixtures；无 engine 源码
│  │     ├─ specialized/
│  │     ├─ quality/
│  │     └─ historical-integrity/
│  ├─ diff/
│  │  ├─ protection.json
│  │  └─ authorizations/
│  └─ ci/
│     ├─ workflow.template.yml
│     ├─ workflow.variables.json
│     ├─ required-checks.json
│     └─ activation.json
├─ commands/                     # 仅薄 wrapper，例如 Invoke-IFXGuardrails.ps1
├─ integrations/
├─ maintenance/
├─ docs/
└─ tests/

artifacts/                       # 仓库内，不进入 Git；只存放数据，不存放可构建的可信门禁源码
├─ build/<package>/              # 本地 package 构建的 bin/obj
├─ generated/<package>/          # workflow candidate 等非构建型候选
└─ guards/<package>/<stage>/     # TRX、JSON report、logs、summary、runtime analysis 输出

$RUNNER_TEMP/                    # CI；本地运行时为仓库外的等价临时目录
├─ guard-base/                   # 只读 base worktree
└─ guard-gen/<package>/          # 可信门禁的生成源码与构建输出（§11.2）
```

- V3 是唯一 portable engine。V3_ifx 作为 IFX overlay 直接引用仓库内 V3 的公共 engine/contracts 与 `build/` 基线，不复制、不 fork 通用实现。
- 新仓库使用 V3 源码包 Bootstrap 生成自己的门禁，而不是复制 V3_ifx。
- 可构建的门禁生成源码不写入仓库目录；非构建型候选与运行证据写入仓库 `artifacts/`；激活副本只存在于目标位置（例如 `.github/`）。

## 6. Stage 职责

| Stage | 主要职责 | 典型输入 | 典型输出 |
| --- | --- | --- | --- |
| Bootstrap | 初始化包、建立未评审配置和安装前准备 | project ID、目标根、SDK | 初始 JSON、目录、可运行门禁骨架、状态报告 |
| Analysis | 只读发现目标事实并形成可评审提案 | repository、当前 profile | inventory、drafts、review report |
| Pre | 路径、area、owner、risk、rule 和 command 关联 | proposed paths 或 formal Plan | advisory/blocked summary |
| Post | 源码、项目引用、程序集、policy、专项和质量检测 | target tree、compiled outputs、policy | detector reports、summary |
| Diff | 最终 changed set 与正式 Plan、受保护路径、授权和 policy/config 单调性对账 | trusted base、head、Plan、protection、authorizations | scope pass/fail |
| CI | 编排 Stage、生成激活候选、验证 required checks | Stage manifests、workflow template、required checks | workflow candidate、activation report |
| Shared/Governance | 跨 Stage 工具链、authority、decision、schema | reviewed JSON | 被多个 Stage 引用，不独立执行 |

每个 Stage 新增 `stage.json`。字段 owner 划分如下，禁止两处同时拥有同一字段：

| 字段 | owner | 另一方 |
| --- | --- | --- |
| `entryPoint`、`inputs`、`outputs`、`evidence`、`mutability`、`requiresExplicitAcceptance`、`platforms`、`stability` | `shared/commands.json` | `stage.json` 只引用 command ID，并通过 command 解析证据 |
| `id`、`commands`（command ID 列表）、`dependencies`、`enforcement`、`executionClass`、`documentation`、`gates`（Gate ID 与 trust contract，§11.3） | `stage.json` | `commands.json` 只引用 stage ID |

## 7. 脚本和可执行文件分类

### 7.1 公共命令 `commands/`

供 human、Agent 或 CI 直接调用的稳定 API。只暴露少量入口：

- `Invoke-V3.ps1`：Validate、Pre、Post、Diff、All。
- `Invoke-V3Setup.ps1`：Bootstrap、Analysis。
- `Invoke-V3Docs.ps1`：Render、Check；按 D4 移除现有 `Import` 模式。
- `Invoke-V3Deployment.ps1`：Generate、Check、Preview、Install、Verify 激活文件。
- IFX overlay 保留一个薄的 `Invoke-IFXGuardrails.ps1`，只负责选择 IFX package 和 Stage，不重复实现通用逻辑。

在 CI 的 PR 判定中，上述公共命令从 base worktree 调用；head checkout 只作为显式 target 参数传入（§11.1）。

### 7.2 内部引擎 `engine/`

- 不承诺外部调用兼容性。
- 公共命令负责参数、帮助、退出码和结构化输出；内部模块负责实现。
- 共享 PowerShell 逻辑优先收敛为不导出内部细节的 `.psm1` 模块。
- `engine/trusted-base/` 负责 base worktree 建立、可信调用链加载、可信构建隔离和 head 隔离（§11.1、§11.2）。

### 7.3 生成器 `generators/`

- JSON → 只读 Markdown。
- Stage JSON/profile → .NET Stage Gate。
- workflow template + variables → workflow candidate。
- activation manifest → 目标文件候选或 managed block。
- Stage Gate 源码只写入仓库外的生成根（§11.2）；其他候选只写 `artifacts/generated/`；Install 必须是独立显式操作。

### 7.4 Integrations、Maintenance 与 Test Support

- `integrations/`：GitHub、Agent hook、Skill 等宿主胶水，只调用公共命令。
- `maintenance/`：policy projection、history manifest、analysis evidence 更新、迁移和 hash 更新；写 authority 时必须要求 `Preview`/`Apply` 或等价显式语义。
- `tests/support/`：只服务 fixture、负例和临时仓库，不作为用户入口。

### 7.5 Command manifest

新增机器权威 `shared/commands.json`，为每个公共入口记录 §6 表中由它拥有的字段，以及 `id`、`kind`、`stages`、`audiences`。

CI 模板检查器和 `docs/generated/COMMANDS.md` 都从该 manifest 读取，不再手工维护命令清单；workflow 只允许调用 `kind = public` 的命令。

## 8. .NET 门禁工程分类和命名

### 8.1 Stage Gate

当前 profile 驱动的 Self/Post/Diff xUnit 工程改为职责名称，项目名由 profile project ID 参数化：

```text
<生成根>/<package>/gates/stage/          # CI：$RUNNER_TEMP/guard-gen；本地：仓库外临时目录
└─ {ProjectId}.Guards.StageGate.Tests/
   ├─ Self/
   ├─ Post/
   ├─ Diff/
   ├─ GeneratedInputs/
   └─ {ProjectId}.Guards.StageGate.Tests.csproj
```

- `Self` 证明检测器能接受正例并拒绝故意违规 fixture。
- `Post` 扫描项目引用和编译程序集。
- `Diff` 验证实际 changed set、Plan、受保护路径、授权和 policy/config 单调性。
- 保留一个 csproj 以降低 restore/build 成本，通过目录、类名和 test trait 区分类别。
- `ArchUnitNET` 仅作为 package 依赖和实现说明，不进入稳定工程名称。
- 通用生成器定义 project ID 到合法 .NET identifier/namespace 的确定性转换（大小写、分隔符、数字开头、保留字），并在转换结果碰撞时失败关闭。
- 生成工程显式 import V3 `build/` 基线，并按 §11.2 隔离构建；生成源码不进入 Git（D3）。

### 8.2 Architecture Conformance Gate

LayerGuard 派生实现分三步收敛：

1. **去重**：删除 `V3_ifx/generated/dotnet/LayerGuard`，直接构建运行 `templates/ifx-layerguard` 唯一源码。当前 `Invoke-IFX.ps1` 的 Generate/Check 只是复制并逐字节比较相同源码，验证聚焦 build/test、policy binding、strict scan、正反 fixture、CI 调用路径和恢复，不建立长期 parity 框架。
2. **剥离 IFX binding**：当前源码并非纯通用能力——`src/LayerGuard/GatePolicyBindings.cs` 硬编码 `ifx-api`、`ifx-worker`、`ifx-all` runtime role，`tests/LayerGuard.Tests/GatePolicyBindingTests.cs` 包含 IFX 项目和类型名称。runtime role、IFX project/type names 和绑定 fixture 必须参数化或移入 IFX policy/fixtures；通用测试改用 synthetic fixture。
3. **进入 V3**：通用 engine 迁入 V3 `stages/post/gates/architecture/dotnet/Guards.ArchitectureConformance*`；V3_ifx 只保留 policy、baseline、binding 和 IFX fixtures。

约束：

- policy 仍由 JSON 参数传入；G03/G04/G05 policy binding 与 composite hash 语义不变。
- `Check` 验证源码 manifest、policy binding 和 fixture，而不是比较两份相同目录。
- 通用 engine 中 IFX 标识扫描必须大小写不敏感（`ifx`、`IFX`、`Ifx` 均计入）。
- `v3-architecture` required check 名称和 summary schema 不变。
- Gate 按 §11.3 声明为混合型 trust contract，写明 MSBuild import/Condition 盲区与 Assembly 检查的交叉兜底关系。

### 8.3 构建基线与输出

**package-local 基线**：

- V3 `build/` 携带最低完整的构建与安全基线：`NuGetAudit`、`NuGetAuditMode`、`NuGetAuditLevel`、`NU1903;NU1904` warnings-as-errors、门禁工程包版本、`NuGet.config` 与 `global.json`。初始值来自 P0.8 对当前继承配置的盘点，不得弱于当前 IFX 根配置。
- 每个可信门禁工程都有受版本控制的 `packages.lock.json` 权威或生成模板；restore 使用 locked mode，锁定直接与传递依赖的版本和 content hash。lock 漂移必须由 base-owned checker 检出，不允许普通 restore 静默重写。
- V3 与 V3_ifx 的门禁工程、生成工程显式 import V3 `build/` 基线，不依赖 `Directory.Build.props`、`Directory.Packages.props` 的目录发现。
- V3 公共命令构建门禁工程时统一关闭目录向上搜索，并通过命令行指定输出位置（开关见 §11.2）。
- 原 r2 方案 A（新增 `docs/Directory.Build.props` 并 import 根 props）不再采用：它依赖宿主配置，且 import 可以覆盖属性或增加 target，无法保证不削弱 V3 基线。
- 宿主配置叠加默认关闭。确需叠加时，只能显式指定 base 中经验证的文件，并通过允许字段白名单、导入顺序和最终有效属性检查证明不降低 V3 基线；不得导入 head 配置。

**输出位置**：

- 本地 package 构建的 `bin/obj` 定向到 `artifacts/build/<package>/`。
- TRX、JSON report、logs 和 runtime analysis 输出定向到 `artifacts/guards/<package>/<stage>/`。
- 可信门禁的生成源码与构建输出位于仓库外的生成根（§11.2）。
- workflow candidate 等非构建型候选定向到 `artifacts/generated/<package>/`。
- head solution 自身的 build/test 继续使用 head 项目配置，按 §11.3 标记为执行型保证，不与可信 evaluator 自身构建混为一谈。

**验证清单**：

- `Test-V3.ps1` synthetic fixture 不再依赖复制 `docs/Directory.Packages.props`；
- 在 IFX 仓库内构建时不受根 Central Package Management 影响（无 NU1008）；
- 有效属性检查确认 V3 安全基线在全部门禁工程中生效；
- clean restore 使用 lock file 与 locked mode；直接或传递依赖漂移、lock 缺失或 content hash 不匹配均失败关闭；
- import allowlist 接受与 lock file/package content hash 一致的 NuGet build assets 及隔离生成根中的 `.nuget.g.props/.targets`，拒绝未锁定 package、head、宿主父目录或用户自定义 import；
- Stage Gate Generate/Check/Test/Diff；
- Architecture Conformance Gate build/test/scan；
- Linux/Windows 路径一致性；
- 并发 project/TFM 不共享同一 intermediate output；
- clean 后 `docs/guards/**` 下不再生成 `bin/obj`；
- 隔离验收：将 V3 复制到不继承任何 IFX 父目录配置的临时目录后，仍可完成 build、Generate、Check 和 Test；
- IFX 自身业务项目的根安全配置不受本次改动影响。

## 9. Markdown 文档模型

### 9.1 文档分类

- `docs/authored/`：人工维护的架构理由、迁移说明、操作指导和决策背景。
- `docs/generated/`：从一个或多个 JSON 聚合生成，只读，禁止直接编辑。

首批生成：

- `OVERVIEW.md`：Stage 全景、入口、输入输出和 authority/candidate/activation/evidence 关系。
- `COMMANDS.md`：公共命令、执行者、副作用、输入输出和示例。
- `POST.md`：rules、detectors、coverage、Architecture Conformance、trust contract 和专项/质量 gate。
- `CI.md`：job DAG、触发条件、required checks、候选与激活状态。

`ANALYSIS.md`、`PRE.md`、`DIFF.md`、`AUTHORITY.md`、`GENERATED-ASSETS.md` 等只在出现真实阅读需求时另行增加。现有 `profiles/ifx/views/` 一对一视图在 P8 决定保留为只读生成视图或并入首批文档，均不再支持 Import。

### 9.2 `docs-map.json`

每个生成文档声明：

- output path；
- sources/globs；
- source role；
- renderer。

生成文档头部列出全部来源路径、角色和一个 composite hash。`Docs Check` 重新渲染并逐字节比较，验证完整文件集，纳入 Validate/CI。

## 10. CI 激活模型

### 10.1 轻量模板

不建立描述任意 GitHub Actions 的 JSON DSL。结构如下：

```text
V3/stages/ci/templates/          # 通用 renderer 约定与示例模板
V3/generators/activation/        # 渲染器：只替换少量稳定变量

V3_ifx/stages/ci/
├─ workflow.template.yml         # IFX canonical GitHub workflow YAML 模板
├─ workflow.variables.json       # 少量稳定变量，例如 SDK 版本、package 路径
├─ required-checks.json          # 独立机器权威：check 名称、ruleset、strict
└─ activation.json               # candidate → target 映射

artifacts/generated/v3-ifx/activation/
└─ .github/workflows/v3-ifx-guardrails.yml   # candidate，不进入 Git

.github/workflows/v3-ifx-guardrails.yml      # 激活副本，带 source path/hash 头
```

现有 `ci/jobs.json` 由 `required-checks.json` 取代。

### 10.2 生命周期

```text
Declare → Generate → Check → Preview → Approve → Install/Copy → Verify
```

- `Generate` 只写 `artifacts/generated/` 候选路径。
- `Check` 验证：
  - YAML 可解析、job DAG 与 Stage 依赖正确；
  - 只调用公共命令 ID；
  - PR 判定步骤建立 base worktree，且第一个可执行入口位于 base worktree 路径；
  - matrix 展开后的 check 名称与 `required-checks.json` 一致；
  - 生成漂移。
- `Preview` 比较候选与 `.github/` 激活副本。
- `Install` 需要 `-AcceptDeployment` 并记录 source/target/hash；人工复制后必须运行同一个 `Verify`。
- `Verify` 检查目标文件头部 source path/hash 与内容。
- GitHub ruleset 继续作为远端状态；只读 verifier 比较远端实际状态与 `required-checks.json`，包括 `strict` 设置。任何远端写入仍需独立授权。
- CODEOWNERS managed block 使用相同生命周期。

### 10.3 Required check 不变量

以下 13 个 check 名称在本计划全程保持不变（ruleset `23459908`，`strict: true`）：

| 类别 | check 名称 |
| --- | --- |
| Diff | `v3-pre-diff` |
| Architecture | `v3-architecture` |
| Specialized | `v3-specialized-g03`、`v3-specialized-g04`、`v3-specialized-g05`、`v3-specialized-plan04`、`v3-specialized-database` |
| Quality | `v3-quality-solution`、`v3-quality-assembly`、`v3-quality-frontend` |
| Historical integrity | `v3-historical-integrity` |
| Cross-platform（matrix 展开） | `v3-cross-platform-ubuntu-latest`、`v3-cross-platform-windows-latest` |

调整触发策略（例如 D8 的 path/schedule 触发）不得使 required check 在 PR 上处于永久 pending 状态。

## 11. 门禁信任模型

### 11.1 Trusted Base Guard Execution

```text
Base worktree（$RUNNER_TEMP/guard-base，位于 head checkout 之外，只读、clean）
├─ trusted 公共命令、orchestrator、dispatcher、module loader
├─ trusted commands.json、V3 engine 与 contracts
├─ trusted V3 build/ 基线
├─ trusted Diff/protection config 与 policy
├─ trusted authorizations
└─ trusted activation contract

可信生成根（$RUNNER_TEMP/guard-gen，位于 head 与 base 之外）
└─ Stage Gate 生成源码、可信 evaluator 构建输出

Head/merge checkout
└─ 被检查的 target files、changed set，以及候选 policy/config 数据
```

实现必须满足：

- base SHA 来自可信 PR event，并验证 commit 可解析；
- workflow 之后的第一个可执行文件来自 base worktree；整条公共命令、orchestrator、dispatcher、module 和 `commands.json` 调用链均来自 base；
- head checkout 只能作为显式 target repository/path 参数传入；
- engine、contracts、protection config、policy 和授权从 base worktree 加载；
- base 调用链不从 head dot-source PowerShell、加载 module、执行脚本或读取可执行配置；
- base worktree 保持只读和 clean，不作为生成目录或构建输出目录；
- base worktree 必须创建在 head checkout 之外，避免 MSBuild/NuGet/SDK 向上搜索加载 head 控制的文件；
- 不使用 `pull_request_target` 执行不可信 PR 代码。

负向控制至少包括：PR 修改公共 wrapper、dispatcher、module manifest、`commands.json`、受保护路径清单、engine 脚本、policy，以及在 head 根 `Directory.Build.props`、`Directory.Packages.props` 注入失败或篡改逻辑，均不得改变判定型结论。

### 11.2 可信构建隔离

可信 evaluator 与 Stage Gate 的生成、restore 和 build 必须满足：

| 机制 | 做法 |
| --- | --- |
| 位置 | 生成源码与构建输出位于 `$RUNNER_TEMP/guard-gen/<package>/`（本地为仓库外等价临时目录），不在 head checkout 或 base worktree 内 |
| `Directory.Build.props/targets` | 命令行全局属性 `-p:ImportDirectoryBuildProps=false -p:ImportDirectoryBuildTargets=false`；写在 csproj 正文中晚于 SDK import，无效 |
| `Directory.Packages.props` | `-p:ImportDirectoryPackagesProps=false`；包版本由 V3 `build/V3.Packages.props` 显式提供 |
| `Directory.Solution.props/targets` | 构建 `.slnx` 时同样关闭对应 import |
| 构建基线 | 工程显式 import V3 `build/` 基线（§8.3） |
| NuGet restore | `restore --configfile <V3 build/NuGet.config> --locked-mode`（或等价 `RestoreLockedMode=true`）；使用受版本控制的 `packages.lock.json`，并验证用户级与机器级配置不参与源解析 |
| SDK 选择 | 生成根内放置 V3 `build/global.json`，工作目录固定为生成根 |
| restore 完整性 | lock file 必须覆盖直接与传递依赖；package ID、版本和 content hash 与 lock 一致，restore 不得修改 lock |
| 有效 import 预检 | restore 后、执行实际 build/test target 前，通过 `-pp` 或等价预处理取得 import 列表；只允许固定版本 .NET SDK、V3 package、隔离生成根中的 NuGet 生成文件，以及 package ID/version/content hash 与 lock 一致的 NuGet build assets |
| 构建后复核 | 通过 binlog 再次核对有效 imports；出现未锁定 package、head、base 工作区其他位置、宿主父目录或用户自定义文件即失败关闭 |

lock-file restore、构建前 import 预检和构建后 binlog 复核共同构成本节的核心负向控制，并与 §11.1 的 head MSBuild 注入负向控制合并执行。本地运行时不建立 base worktree，但使用相同的隔离开关和 locked mode，保证本地与 CI 的构建行为一致。

### 11.3 Gate trust contract

每个 Gate 在 `stage.json` 的 `gates` 中声明 trust contract，至少包含：

- evaluator/orchestrator 来源；
- policy/config 来源；
- target input 及派生输入来源；
- 是否构建或执行 head 内容；
- 是否消费 head 生成的程序集或报告；
- 已知盲区与交叉兜底关系；
- 对结论能够提供的实际保证范围。

按 D18，trust contract 还须以 `inputs` 逐项列出读取的输入（`authority:<id>`、`package:<路径>` 或 `target:<路径>`；authority 的角色只登记在 §12.6 registry 中，不在 trust contract 重复）以及来源——`base`（来自 base 的门禁包配置与代码）、`head-candidate`（来自 head、须经 §12.6 比较的 domain authority）、`derived-candidate`（base generator 由 head authority 在临时目录生成的 projection）或 `head-target`（被检查的源码与文档）。

初始分类（P0.10 核实后冻结）：

| Gate | 类型 | evaluator 与 policy | target input | 是否执行 head | 保证范围 |
| --- | --- | --- | --- | --- | --- |
| `v3-pre-diff` | 判定型 | base | merge-base 与 head 的 Git 对象 | 否 | base 完整负责结论 |
| `v3-architecture`（LayerGuard） | 混合型 | base | head csproj XML 与源码文本 | 否，不做 MSBuild 求值 | evaluator 可信；输入盲区见下表 |
| `v3-quality-assembly` | 混合型 | base | head 构建产生的 Domain 程序集（上游 artifact） | 构建由上游 job 执行 head | evaluator 可信；程序集来源不可信 |
| `v3-quality-solution`、`v3-quality-frontend` | 执行型 | base orchestrator | head solution/frontend | 是 | base 只保证执行的命令、参数、退出码判定与必需证据 |
| `v3-specialized-database` | 执行型（待核实） | base orchestrator | head EF startup project | 是 | 同上 |
| `v3-specialized-g03/g04/g05/plan04` | 待 P0.10 分类 | — | — | — | — |
| `v3-historical-integrity` | 判定型（待核实） | base | tracked evidence 与 manifest hash | 否 | base 完整负责结论 |
| `v3-cross-platform-*` | 待 P0.10 分类 | — | — | — | — |

Architecture Conformance 的交叉兜底：

| 检测 | 可信部分 | 盲区 | 兜底 |
| --- | --- | --- | --- |
| LayerGuard 源码/项目文件检测 | evaluator、policy、判定逻辑；不执行 head | `<Import>`、Condition、`Directory.Build.*` 注入的 `ProjectReference` | Assembly 检查读取实际编译结果 |
| Assembly 检查 | evaluator、policy、判定逻辑 | 程序集由 head 控制的构建产生 | 源码/项目文件检测；针对 `Directory.Build.*` 与 `<Import>` 注入的检测规则作为独立规则提案，经 decision 后加入，加入前登记为已知缺口 |

执行型门禁中，head 可以修改自身测试或构建脚本使其通过，这是此类门禁的固有边界，不属于 trusted base 可解决的问题。

### 11.4 保证范围

workflow 定义本身以及 git 端审批设置不在 §11 的信任边界内，按 §18 O1 暂缓。§11 的保证范围仅限：

- 在 workflow 定义未被修改的前提下，PR head 无法通过修改入口调用链、engine、配置、policy、授权或 MSBuild/NuGet/SDK 继承文件改变**判定型**结论；
- 混合型与执行型门禁的保证范围以各自 trust contract（§11.3）为准。
- trusted base 自身的候选升级按 §11.5 验证；该协议保证候选必须经过 base-owned validation、parity 和必要授权，但在 O1 暂缓下不宣称能够阻止无需审批的两步操作。

对外描述门禁能力时不得超出该范围。

### 11.5 Trusted Base Component 候选升级

`shared/trusted-components.json`（TCB manifest）是自保护的信任根之一，必须把自身、schema 和 verifier 纳入清单；它还列出下一次执行中会进入 trusted base 的全部组件，至少包括：公共入口与 wrapper、orchestrator、dispatcher、module loader/manifest、`commands.json`、engine、contracts、protection/policy evaluator、授权 verifier、base-owned tests/fixtures、生成器，以及 V3 `build/` 基线、lock files 和可信 CI activation contract。每个组件声明路径、组件 ID、类型、base-owned validation suite、parity contract 和允许的变更方式。

PR 修改任何 TCB 组件时必须满足：

1. 当前 PR 的权威门禁仍只运行 base TCB；head 候选不得替换当前判定链。
2. base validator 在独立候选进程/输出目录中运行 head 候选，且不向候选暴露高权限 secret；候选执行结果只能作为 pass/fail 输入返回 base 汇总器。
3. head 候选必须通过 base 中的 tests、fixtures、contracts 与负向控制；head 新增测试只能补充，修改或删除 head 中的测试不能替代 base-owned validation。
4. 新旧实现针对 base 固定 corpus 执行 parity；默认要求命令契约、失败关闭类别、summary/report schema 和 blocking 结论一致。
5. 纯 tuple 等价移动可按 `move` 授权处理；其他 TCB 代码、测试、contract、构建基线或 lock file 的语义变化无法由机械 parity 完整证明时，必须消费 §12 的 `change-trusted-base` 预授权。授权记录组件 ID、base/head 预期 tuple/tree ID、允许的行为差异、base validation suite 与对应 decision。
6. 候选合并后才成为下一次 trusted base；下一 PR 必须验证新 base 的 manifest、lock、测试与负向控制均生效。
7. head manifest 新增、删除、重分类 TCB component，或 head command/activation 引用 base manifest 未登记的可执行组件，均视为 TCB 语义变化并失败关闭或要求 `change-trusted-base` 授权；不得通过先修改 manifest 把组件移出保护范围。

`change-trusted-base` 与其他 §12 授权一样采用 base 预授权、消费即删除协议。该协议在 O1 暂缓范围内提供显式、可追溯的 TCB 演进，不宣称能够替代 git 端强制审批。

### 11.6 首次引入例外

引入 Trusted Base Guard Execution 的 PR 在 base 中尚无该机制，只能由现有 CI 和专门负向控制兜底；ruleset 当前不强制 code owner review，该残余风险按 §18 O1 暂缓处理。该一次性例外必须写入 decision 记录，并在该 PR 合入后的下一个 PR 上验证机制生效。

P5 建立 package-local build/lock 基线，P2 才启用 trusted execution 与 TCB candidate protocol，因此 P5–P2 构成同一个受控 bootstrap 窗口：P5 使用 P0 冻结的 TCB 清单、现有 CI、隔离构建验证和专门负向控制；P2 必须以 P5 合入后的 base 验证该基线并关闭窗口。在 P2 生效后，P3 及后续任何 TCB 变化必须遵循 §11.5，不得继续使用首次引入例外。

### 11.7 Break-glass

base engine 自身误报时，修复 PR 会被旧 engine 阻断。break-glass 只能是仓库外部治理的最后手段（例如管理员临时调整 ruleset），不能实现为仓库内可自行调用的 bypass。至少记录：

- 授权人和复核人；
- 原因和受影响 check；
- 开始与恢复时间；
- 临时 ruleset 变化；
- 恢复后的配置证明；
- 事后正常/负向复验结果。

## 12. 受保护变更授权

### 12.1 两 PR 协议

适用于受保护路径的删除、移动、大小写重命名，policy/config 的潜在削弱，以及 trusted-base component 的语义变化：

1. **授权 PR**：将精确 authorization 写入 base（`V3_ifx/stages/diff/authorizations/`），不执行被授权的变更。
2. **变更 PR**：只能消费 base 中已存在的授权，完成精确变更，并在同一 diff 中删除所消费的授权。

授权从 base 被合并删除后自然失效，不依赖 wall-clock 有效期或无状态的"已使用"标记。

### 12.2 授权内容

每条 authorization 的公共字段至少包含：

- 唯一 authorization ID；
- operation：`move`、`delete`、`case-rename`、`weaken-policy`、`change-trusted-base`；
- 授权对应的精确 changed-path 集合；
- 对应 formal Plan 和 decision。

各 operation 的专用字段：

- `move`、`delete`、`case-rename`：source 的 repository-relative path 与 base tree-entry tuple（`mode + type + objectId + path`；目录记录 tree ID）；destination path 与其 base 前置状态（不存在或 base tuple）；预期 destination tuple/tree ID，或删除后的不存在状态；
- 允许内容变化的 path operation：destination 路径 → 预期 tuple/blob ID 清单，不使用自由文本；
- `weaken-policy`：变更前后的 authority hash、受影响 schema/字段和预期 head tuple；
- `change-trusted-base`：一个或多个 TCB component ID、每个组件的 base/head 预期 tuple/tree ID、base-owned validation suite、parity contract 与允许的行为差异；TCB manifest 自身发生变化时同时记录 base/head manifest hash。

### 12.3 Git 对象表示与机械验证

**对象表示**：

- 普通文件与符号链接：比较 `mode + type + objectId + repository-relative path`，blob ID 不单独作为依据；
- 目录：比较 tree ID；需要展开 changed-path 时使用 `git ls-tree -r -z` 生成的规范化、NUL 分隔 tree entry manifest；
- verifier 读取 commit/tree 对象，不重新 hash checkout 文件；Git committed object identity 避免工作区换行差异；
- 受保护范围内出现 mode `160000`（gitlink/submodule）条目时直接失败，不作为普通 tree 或 blob 比较，也不允许通过授权移动；
- `.gitattributes` 本身的变化作为 changed set 和 policy/config 变更单独验证。

**比较端点**：

- 使用已验证的 merge-base 与 PR head SHA，changed set 通过 `git diff --raw -z --no-renames <verified-merge-base> <head-sha>` 或等价 plumbing 输出逐项对账；
- 不依赖 rename heuristic，也不依赖易受路径转义影响的展示格式；
- ruleset `strict` 保证合并时 head 已包含最新 base，因此以已验证 merge-base 为端点的结论在合并时成立；该结论依赖 `strict` 保持启用，由 P1.3 verifier 断言。

**门禁必须验证**：

- 授权存在于 base，而不是仅存在于 head；
- head 删除了所消费的授权；
- operation 与授权完全匹配；path operation 的 source、destination、前置状态和结果 tuple 与授权完全匹配；
- `weaken-policy` 的 authority hash、字段范围和预期 head tuple 与授权完全匹配；
- `change-trusted-base` 的实际 TCB changed set、head tuple/tree ID、base-owned validation suite、parity 结果和允许行为差异与授权完全匹配；
- 实际 changed-path 集合与授权声明逐项一致，未授权的额外删除、新增或重命名为零；
- 仅大小写不同的重命名必须声明为 `case-rename`，并纳入 Linux/Windows 正反控制；
- 并发 PR 更新分支后因 base 中授权已被删除而失败，避免重复消费。

### 12.4 Policy/config 双轨验证与单调性

**双轨**：

1. base policy/config 对当前 PR 给出唯一权威判定；
2. base engine 同时把 head policy/config 作为候选数据，执行 schema、引用完整性、coverage、parity 和单调性检查；
3. head 候选不得控制当前 PR 的判定，只能在合并后生效；
4. head 对 engine、门禁测试或其他 TCB component 的修改按 §11.5 验证：base-owned validation 与 parity 是必需条件，head package 自身测试只能补充；结论由 base 判定链汇总，不改变 §11 的权威来源。

**schema-specific monotonicity**：

- 每种 policy/config schema 明确定义可比较字段及其"收紧、等价、削弱"关系；
- 比较前先解析 JSON 并规范化，空白、换行、键顺序等纯格式差异视为等价；
- 只有能够机械证明为收紧或等价的变化，才无需授权；
- 已知削弱，以及无法证明为收紧或等价的未知语义变化，默认按潜在削弱处理，需要 §12 的 `weaken-policy` 授权；
- schema 新增字段必须同时声明 monotonicity，否则变更失败关闭；
- 已知削弱类型示例（非封闭）：删除规则或 detector、enforcement 从 blocking 降为 advisory、baseline 条目增加或内容改变、增加 exclude/ignore、放宽阈值/predicate/operator、缩小平台/触发/输入/证据要求、替换 authority/binding/hash、删除受保护路径、coverage 缩小、删除 required check。

**零比较器起步**：

- P4 初始不实现任何 schema 比较器，所有 policy/config 语义变化一律视为潜在削弱并要求授权；这是上述规则最保守的合法实例；
- 之后按 P0.9 的实际修改频率逐个补充比较器；每个比较器覆盖该 schema 全部字段，并有收紧、等价、削弱和未知字段正反例；
- r3 核对的频率参考：2026-06 以来修改最频繁的是 `profiles/ifx/rules`（13 次）与 `policy/g04/bindings`（8 次），G03、G05 和 baselines 各 1–2 次。

### 12.6 Domain authority 混合信任模型（D18）

部分 Gate 读取门禁包之外、由领域拥有的 authority（例如 G03 contract-event catalog、`deployment/g04/*`、Plan04 policies）。这些文件既不能只从 base 读取（会迫使每个 contract 或 deployment 变更拆成两个 PR），也不能把 head 版本当作普通输入无条件信任（PR 可以放宽自身策略或增加 waiver）。采用混合模型：

1. detector、路径映射、schema、transform 与判定逻辑来自 base；
2. domain authority 的 head 版本作为 candidate 输入；
3. base detector 同时读取 base 与 head 版本，按角色比较；
4. 角色登记在 `policy/authorities.json` 的 `domainAuthorities`（`defaultRole` 加按 JSON Pointer 覆盖的 `pointerRoles`，`*` 匹配任意成员或下标，最具体的 pointer 优先；同一文件可混合多种角色），schema 为 `contracts/authorities.schema.json`；有 `detectors` 的 Gate，其 detector 静态读取闭包必须与 trust contract 声明的 authority 输入一致，由 `Invoke-IFXManifestCheck.ps1` 校验：

| 角色 | 含义 | 变更处理 |
| --- | --- | --- |
| `target-declaration` | 被治理对象的声明（例如新增 contract 条目、deployment unit） | schema、引用完整性与一致性校验；不需要授权，允许单 PR |
| `governing-policy` | 约束规则（lifecycle、enforcement、owner、阈值、策略开关） | 按 §12.4 单调性判断；无法证明为收紧或等价时需要 `weaken-policy` 授权 |
| `exception-authorization` | waiver、bypass、baseline、allowlist | 任何扩大都需要 `weaken-policy` 授权 |
| `derived-projection` | 由 authority 生成的门禁包 projection | base generator 在临时目录由 head authority 重新生成，校验 hash、schema、parity 与单调性 |
| `evidence` | 冻结证据 | 由 historical integrity 保护 |

约束：

- candidate projection 只有在 anti-weakening 检查全部通过后才能参与判定；检查失败时 Gate 失败，不退回使用 base projection 继续判定；
- 在 P4 实现 `weaken-policy` 授权之前，`governing-policy` 与 `exception-authorization` 的语义变化没有授权通道，一律失败关闭，唯一例外路径是 §11.7 的仓库外 break-glass；
- Pre risk 与 CODEOWNERS routing 只提供可见性，不构成安全边界（§18 O1）。

### 12.5 保证范围

在 §11.4 保证范围内：

- 受保护路径的删除、移动和大小写重命名只能通过 base 预授权完成，授权只能消费一次；
- policy/config 的潜在削弱必须显式授权、可追溯，未知语义变化失败关闭。
- TCB component 的候选升级必须通过 base-owned validation 与 parity；无法机械证明为 tuple/行为等价的语义变化必须消费 `change-trusted-base` 授权。

在 O1 暂缓的前提下，本节不能阻止"先合入授权、再合入变更"的两步操作；其作用是使受保护变更与削弱必须显式记录、可以追溯。

## 13. 现有目录到目标职责的初步映射

| 当前目录 | 初步目标 |
| --- | --- |
| `architecture/` | `docs/authored/architecture/`，目标提案移入 Analysis drafts |
| `analysis/ifx/` | 按 P0.2 生命周期分类：经评审的长期输入与基线 → `stages/analysis/evidence/`（authority/history 角色，经 `maintenance/` Preview/Apply 更新）；经评审冻结的报告快照 → `stages/analysis/reports/`；运行时输出（例如 `Invoke-V3Architecture.ps1` 写出的 `architecture-review.json`、`ARCHITECTURE-REVIEW.md`）→ `artifacts/guards/<package>/analysis/` |
| `ci/jobs.json` | 由 `stages/ci/required-checks.json` 取代 |
| `contracts/` | `shared/contracts/` 或特定 Stage contracts |
| `decisions/` | `shared/decisions/` |
| `examples/` | `examples/` 或 `tests/fixtures/`，按是否面向用户区分 |
| `generated/stages/` | 取消跟踪；生成到仓库外生成根 `<生成根>/<package>/gates/stage/` |
| `generated/dotnet/LayerGuard/` | 删除（与 template 逐字节重复） |
| `history/` | `stages/post/gates/historical-integrity/` |
| `hooks/`、`skills/` | `integrations/agents/`；V3_ifx 中与 V3 相同的副本删除 |
| `policy/` | `stages/post/policy/`，authority registry 在 `shared/authorities/` |
| `profiles/ifx/` | 拆分到 `shared/`、`stages/pre/`、`stages/post/`、`stages/diff/` |
| `profiles/ifx/views/` | 只读生成视图或并入 `docs/generated/`（P8 决定） |
| `quality/` | `stages/post/gates/quality/` |
| `rules/` | 机器规则进入 `stages/post/rules/`，authoring guide 进入 `docs/authored/` |
| `scripts/` | 按 command/engine/generator/integration/maintenance 分类；V3_ifx 中与 V3 相同的副本删除 |
| `specialized/` | `stages/post/gates/specialized/` |
| `templates/dotnet/` | `generators/stage-gate/`（V3） |
| `templates/ifx-layerguard/` | 通用 engine → V3 `stages/post/gates/architecture/dotnet/`；IFX binding/fixtures → V3_ifx `stages/post/gates/architecture/` |
| `tests/` | 按 Stage 分类，公共 fixture/support 单列 |
| `docs/Directory.Packages.props` | 门禁工程改为使用 V3 `build/` 基线后，按 P0.8 结论确认是否仍有消费者 |
| `docs/guards/V3_backup/` | 删除（D2） |

## 14. 实施阶段

以下阶段全部处于未开始状态。PR 以"可独立验证和回退的迁移检查点"为单位拆分，不机械拆成大量微型 PR；每个 PR 都需要 formal Plan pair，涉及受保护变更时还需要 §12 的授权 PR，拆分策略必须计入该治理成本。

阶段依赖：P5 可与 P1 并行执行，但必须在 P2.2 之前完成；其余阶段按编号顺序执行。

### P0 — 基线冻结与完整分类（只读）— 已完成（2026-09-16，CP01）

- [x] P0.1 记录 V3、V3_backup、V3_ifx、`mcp/LayerGuard/` 和 `.github/` 激活文件的 tracked 文件、hash、引用、生成关系和当前 Validate/Check/Test 结果。 证据：`refactor-baseline/inventory.json`、`duplicates.json`、`local-results.json`、`ci-evidence/`。
- [x] P0.2 为每个文件标注 authority/implementation/generated/activation/evidence、Stage、owner 和保留/迁移/删除结论；`analysis/ifx/` 中每个文件明确归为"经评审长期输入/基线"、"经评审报告快照"或"运行时输出"。 证据：`inventory.json`（820/820 已分类）。
- [x] P0.3 建立全部 PowerShell 及其他 executable 的调用图，区分公共入口和内部调用，标出每个 CI job 的第一个可执行入口，并冻结初始 TCB component 清单、base-owned validation suite 与 parity contract。 证据：`call-graph.json`、`tcb.json`（17 个 component）。
- [x] P0.4 冻结两个 .NET gate 的源码、fixture、项目、package、测试类别和执行路径；列出 LayerGuard 中全部 IFX-specific binding（大小写不敏感扫描）；登记"LayerGuard 不解析 `<Import>`/Condition/`Directory.Build.*`"为已知覆盖缺口。 证据：`dotnet-gates.json`。
- [x] P0.5 登记已知漂移为迁移前缺陷：Markdown views、architecture review、DEPLOYMENT、文件计数、无效 `SourceConfig`、未受校验的 `ci/jobs.json`，以及 `ci/jobs.json` 中 `v3-historical-integrity` 声明的 `history-change-schedule-manual` 触发与 workflow 实际每次运行不一致（待核实）。 证据：`drift.json`（DRIFT-01–10，DRIFT-07 已核实）。
- [x] P0.6 列出 V3 与 V3_ifx 的逐字节相同文件和已分叉文件，并把每处分叉归类为"通用加固"或"IFX-specific"。 证据：`v3-divergence.json`。
- [x] P0.7 只读记录 13 个 required checks 与 ruleset `23459908` 的当前远端状态。 证据：`ruleset.json`。
- [x] P0.8 盘点门禁工程当前继承的全部 MSBuild/NuGet/SDK 配置及其有效属性：根 `Directory.Build.props`、根 `Directory.Packages.props`、`docs/Directory.Packages.props`、NuGet config 和 `global.json`，作为 V3 `build/` 基线的输入。 证据：`build-inheritance.json`。
- [x] P0.9 按 schema 统计 policy/config 文件的历史修改频率，作为比较器实现顺序的依据。 证据：`change-frequency.json`；按 commit 计首批比较器为 `profiles/ifx/rules`、`profiles/ifx/project-map`，修正 §12.4 的 r3 参考数据。
- [x] P0.10 核实并冻结 §11.3 每个 required check 的 trust contract 分类。 证据：`trust-contracts.json`。
- **门槛**：每个现有文件、命令和 Gate 都有唯一分类；全部 trusted-base component 均进入待 P1.5 materialize 的冻结清单；未分类项不得进入后续阶段。
- **结果**：门槛通过。基线记录位于 `docs/guards/V3_ifx/analysis/ifx/refactor-baseline/`，汇总见其 `README.md`。

### P1 — 决策校验与已知漂移修复— 已完成（2026-09-16，CP02）

- [x] P1.1 校验正式执行准备阶段已创建的 D1–D15 decision 记录与 P0 基线一致，补充 P0 中发现的新决定。 证据：D1–D15 记录 ID、schema 与 `affectedPaths` 全部校验通过；新增 D16（比较器按 commit 频率排序，细化 D13）与 D17（Plan04 阶段校验脚本退役）。
- [x] P1.2 修复 P0.5 登记的漂移。 证据：DRIFT-01–09 已处理（DRIFT-09 由 D17 决定退役，删除等待 P4）；DRIFT-10 按设计留给 P3/P7；详见 CP02 pair。
- [x] P1.3 建立只读 verifier：workflow job 名称 ↔ `ci/jobs.json` ↔ 远端 ruleset（含 `strict`），并有正反 fixture；`strict` 断言同时作为 §12.3 比较端点可靠性的前提。 证据：`ci/Invoke-IFXCiContract.ps1`（纳入 Validate）、`tests/Test-IFXCiContract.ps1`（15 个正反例，纳入 `v3-architecture`）；远端只读核对 42 项通过（`stages/analysis/reports/refactor-progress/cp02-ci-contract-remote.json`）。
- [x] P1.4 为旧目录和旧命令定义兼容期、deprecation 输出和删除条件。 证据：`guard-system.json` `compatibility`（兼容期、deprecation 输出、内部路径规则、删除条件与 12 个条目）。
- [x] P1.5 在不移动现有目录的前提下，先建立 P2 所需的最小 `guard-system.json`、`stage.json`、`commands.json` 与 `trusted-components.json` schema/skeleton；字段 owner 遵循 §6。P8 负责最终补全、迁移与文档化，不得重新定义已冻结字段。 证据：V3 与 V3_ifx `contracts/` 下 4 个 schema；V3_ifx `guard-system.json`、`shared/commands.json`、`shared/trusted-components.json`、6 个 `stages/*/stage.json`；`scripts/Invoke-IFXManifestCheck.ps1`（纳入 Validate）与 `tests/Test-IFXManifests.ps1`（16 个正反例）。
- **门槛**：已知漂移清零并由 CI 阻止复发；required check 名称未变；P2 所需最小 manifest/TCB schema 已冻结且字段 owner 无冲突。
- **结果**：门槛通过。已登记漂移中 DRIFT-01、04–08 由 CI 阻止复发（`profile-views`、`ci-contract`、`manifest-check`、`Test-IFXCiContract`、`Test-IFXManifests`、`Test-V3ArchUnit`）；DRIFT-02 的运行时分析产物已刷新，防复发依赖 P8.6 迁出仓库；DRIFT-03 的文档流程已重新执行通过；DRIFT-09 由 D17 决定退役；DRIFT-10 属于 P3/P7。13 个 required check 名称未变，远端 ruleset 只读核对通过。

### P2 — Trusted Base Guard Execution

前置：P5 已完成。

- **结果**：P2.1–P2.9 全部完成。13 个 required check 由 base worktree 中的 runner 判定，可信构建位于 head 与 base 之外，D18 domain authority 比较与 TCB 候选验证在 CI 生效并已在真实 PR 上验证阻断；§11.6 首次引入例外已按 D19 用尽，此后 TCB 变更一律需要 `change-trusted-base` 授权。受保护路径清单篡改控制随 P3 补充。
- **CP05a（2026-09-17，D20）**：P2 验证后发现候选验证要求删除被消费的授权记录、而 base Diff 禁止该删除，任何 TCB 变更都被阻断。修复改为只接受 base verifier 确认被本变更消费的记录删除，按 §11.7 一次性 break-glass 合入（`v3-pre-diff` 移出 ruleset 24 秒，前后快照一致，远程 CI 契约通过），并以常规两 PR 正例与 draft 负例完成事后复验；记录见 `docs/architecture/review/evidence/guards/break-glass-20260917-cp05a.md`。
- **进度**：CP04d（2026-09-17）把全部 required check 切换为 base runner 并声明 `trustedBase` 生效，勾选 P2.1；本 PR 按 D19 由 CP04c base runner 判定，TCB 候选验证与激活契约从 base commit 读取，在下一个 PR 首次生效，P2.8 在该 PR 验证阻断后勾选。CP04c（2026-09-17）完成 workflow 切换前的全部前置并勾选 P2.2、P2.3、P2.5、P2.9：以 runner 对仓库逐一运行全部 mode 时发现 LayerGuard policy binding 测试从包位置推导仓库根，已改为读取 `GUARD_TARGET_ROOT`；按 D19，workflow 切换与激活标志放入 CP04d，使切换 PR 已由修正后的 base runner 判定；P2.1 在 CP04d 勾选，P2.8 在 CP04d 之后的下一个 PR 验证后勾选。CP04b（2026-09-17）完成 trusted-base runner、D18 候选比较与 candidate projection、TCB 候选验证与 `change-trusted-base` 授权，勾选 P2.4、P2.6、P2.7；P2.1、P2.5 的机制与负向控制已实现（`tests/Test-IFXTrustedBase.ps1`），但 workflow 入口切换与 Architecture 构建注入控制在 CP04c 完成后勾选；P2.2、P2.3、P2.8、P2.9 属于 CP04c。CP04a（2026-09-17）完成前置工作，该检查点不勾选条目。判定链脚本已分离 package root 与 target root（`-TargetRoot`/`GUARD_TARGET_ROOT` 读取 target，包配置与生成工程从包自身读取，`Invoke-V3.ps1 -GenerationRoot`），包外副本对移除了包代码的 target worktree 运行时与原位判定一致（`tests/Test-IFXTargetRootSeparation.ps1`，含两个负向控制）；按 D18 建立 domain authority registry 与 trust contract `inputs`/`detectors`，属于 P2.4 的输入部分，Gate 保证范围写入 summary 留给 CP04b。

- [x] P2.1 实现 §11.1：base worktree 位于 head 之外、只读且 clean，base SHA 验证；workflow 之后的第一个可执行入口及完整调用链来自 base；head 仅作为显式 target 参数。 证据：`.github/workflows/v3-ifx-guardrails.yml` 的 13 个 required check 均先在 `$RUNNER_TEMP/guard-base` 建立 PR base SHA（非 PR 事件为当前 commit）的 worktree，再以 `pwsh -File $env:GUARD_BASE/.../Invoke-IFXTrustedBase.ps1 -HeadRoot $env:GITHUB_WORKSPACE -GateId <check>` 判定；runner 验证 base SHA、clean 与目录关系；`ci/jobs.json` 声明 `trustedBase.execution: active` 后，`Invoke-IFXCiContract.ps1` 强制每个 check 使用 base runner、禁止原位 head dispatcher（CP04d）。
- [x] P2.2 实现 §11.2 可信构建隔离：仓库外生成根、关闭目录向上搜索的全部开关、显式 V3 `build/` 基线、显式 `NuGet.config` 与 `global.json`；宿主配置叠加默认关闭。 证据：`Invoke-IFXTrustedBase.ps1` 把 base 包复制到 head 与 base 之外的生成根，并以 `GUARD_BUILD_ROOT` 让 `Invoke-V3.ps1`/`Invoke-IFX.ps1` 的 restore、build、test 输出与 NuGet appdata 都位于该生成根；目录搜索开关、显式 V3 `build/` 基线、`NuGet.config` 与 `global.json` 沿用 CP03 `GuardBuild.psm1`；runner 的 `trusted-build-isolation` 检查确认 head 未出现门禁构建输出（CP04c）。
- [x] P2.3 实现 locked restore、构建前 import allowlist 预检与构建后 binlog 复核：允许固定 SDK、V3 package、隔离生成根中的 NuGet 生成文件和与 lock 中 package ID/version/content hash 一致的 NuGet build assets；其他 import 失败关闭。 证据：CP03 `GuardBuild.psm1` 的 locked restore、lock/assets/content hash 核对、构建前 `msbuild -pp` 与构建后 MSBuild 导入日志 allowlist，在 trusted run 中作用于生成根内的门禁工程（CP04b 本地矩阵与 CP04c `Test-IFXTrustedBase -ArchitectureOnly`）；以 MSBuild 导入日志替代 binlog 的理由见 CP03 pair。
- [x] P2.4 在 `stage.json` 中落实 §11.3 trust contract，summary 报告每个 Gate 的保证范围。 证据：13 个 Gate 的 trust contract 含 `inputs`/`detectors`（CP04a）；`trusted-base/Invoke-IFXTrustedBase.ps1 -GateId` 写出的 `trusted-base/summary-<mode>.json`（schema `contracts/trusted-base-summary.schema.json`）报告 Gate 类型、保证范围、已知缺口与 base/head 来源。
- [x] P2.5 完成负向控制：head 修改公共 wrapper、dispatcher、module manifest、`commands.json`、受保护路径清单、engine 脚本、policy，以及 head 根 `Directory.Build.props`/`Directory.Packages.props` 注入。 证据：`tests/Test-IFXTrustedBase.ps1`（CP04b：篡改 dispatcher、module、`commands.json`、engine、policy 与 Validate 下的根 `Directory.Build.props`/`Directory.Packages.props` 注入；CP04c `-ArchitectureOnly`：根 `Directory.Build.props`/`.targets`/`Directory.Packages.props` 注入不影响 trusted LayerGuard 构建、测试与扫描，且构建输出不进入 head）；受保护路径清单的 head 篡改控制随 P3 保护路径参数化补充。
- [x] P2.6 实现 §11.5 TCB manifest 与候选升级验证：base-owned tests/fixtures/contracts/负向控制、固定 corpus parity、独立候选进程和 `change-trusted-base` 预授权；head 测试只允许补充。 证据：`trusted-base/Test-IFXTrustedBaseCandidate.ps1`（从 base worktree 运行：按 base manifest 与 head manifest 映射 TCB 变更；gitlink 与未登记可执行组件失败关闭；要求恰好一条 base `change-trusted-base` 授权并由 head 删除，逐路径核对 tuple 与 validation suite；在独立 worktree 中以 base-owned tests 覆盖后运行候选验证；对固定 corpus 比较 base 与候选 verdict 和 summary schema）；授权 schema `contracts/authorization.schema.json`，生成工具 `trusted-base/New-IFXTrustedBaseAuthorization.ps1`，授权目录 `stages/diff/authorizations/`。
- [x] P2.7 负向控制：head 同时修改 engine 与自身测试、删除候选测试、改变 command/report contract、修改 package-local build baseline 或 lock file、从 head manifest 移除自身或其他组件、引用未登记可执行组件，均不能绕过 base-owned validation 或未经授权成为下一次 trusted base。 证据：`tests/Test-IFXTrustedBase.ps1`：engine 与自身测试同时削弱、删除候选测试、改变 summary contract、改变 verdict（parity 失败）、未授权修改 lock file、head manifest 移除组件、workflow 引用未登记脚本、授权未消费、head 内容与授权不符，均失败；等价变更经授权通过。
- [x] P2.8 记录 §11.6 首次引入例外，并在下一个 PR 上验证机制生效。 证据：D19（`20260917-v3-stage-d19-trusted-base-first-introduction.json`）；CP04d（PR #36）合入后的两个负向 draft PR 在真实 CI 上被阻断：PR #37 仅修改 TCB 组件且无授权，`v3-cross-platform-ubuntu-latest` 的 `Verify trusted component candidates` 失败（`tcb.engine.historical-integrity` 需要 `change-trusted-base` 授权）；PR #38 让 `v3-historical-integrity` 原位运行 head dispatcher，base CI 契约使 `v3-architecture` 与两个 `v3-cross-platform` 失败（`trusted-base-no-head-dispatcher`、`trusted-base-runner`）；两者均关闭未合入，详见 `20260917-v3-stage-p28-trusted-base-verification`。
- [x] P2.9 在 `docs/authored/` 记录 §11.7 break-glass 外部治理流程和 §11.4 保证范围。 证据：`docs/guards/V3_ifx/docs/authored/trusted-base.md`（§11.4 保证范围、D19 首次引入、§11.7 break-glass 步骤与记录字段）。
- **门槛**：在 §11.4 保证范围内，head 修改入口调用链、engine、保护配置、policy 或 MSBuild/NuGet/SDK 继承文件均无法改变判定型结论；有效 import 断言通过；每个 required check 都有 trust contract；所有 TCB 候选变更都通过 base-owned validation/parity，非等价语义变化具备 base 预授权。

### P3 — 通用 Diff 加固合回 V3 — 已完成（2026-09-17，CP05）

- [x] P3.0 本阶段对 Diff engine/template 的修改按 §11.5 作为 TCB 候选升级，使用 base-owned validation/parity；非等价语义变化消费 `change-trusted-base` 授权。 证据：本 PR 消费 base 中的 `stages/diff/authorizations/cp05-p3-diff-hardening.json`（CP05-auth），`v3-cross-platform-ubuntu-latest` 的候选验证运行 base-owned validation 与 parity，`v3-pre-diff` 以 `consumed-authorization` 接受记录删除（D20）。
- [x] P3.1 将 merge-base 校验和 empty-diff fail-closed 合回 V3 模板。 证据：`docs/guards/V3/templates/dotnet/GuardTests.cs.in` 验证 base/head commit、从 merge base 比较，changed set 为空时失败；`Test-V3.ps1` 的 committed 与空 diff 用例。
- [x] P3.2 将受保护路径从通用 C# 模板参数化到 Diff 配置（V3_ifx `stages/diff/protection.json` 或等价旧路径位置），并由 trusted base 加载。 证据：`stages/diff/protection.json` 与 `contracts/protection.schema.json`；`Invoke-V3.ps1 -ProtectionPath`（默认 package 配置，Diff 阶段校验后设置 `GUARD_PROTECTION_PATH`），trusted base runner 从 base 包副本加载；`v3-pre-diff` trust contract 增加 base 输入；V3 与 V3_ifx 模板不含 IFX 路径。
- [x] P3.3 以明确决策统一 `Test-V3.ps1` 的 NuGet 源配置分叉（V3 离线 `NuGet.Offline.Config` 与 V3_ifx nuget.org `NuGet.Test.Config`），与 V3 `build/NuGet.config` 保持一致。 证据：D21（`20260917-v3-stage-d21-test-v3-nuget-source.json`）；两份 `Test-V3.ps1` 逐字节相同，经 V3 `build/NuGet.config` restore。
- [x] P3.4 在 V3 补齐正反例和 Linux/Windows 测试。 证据：`Test-V3.ps1` 新增 11 个 Diff 正反例（committed、空 diff、非法配置、受保护删除与重命名、无配置、授权消费及其 4 个负例）；两份逐字节相同，V3_ifx 副本已在 `v3-cross-platform` 的 Linux/Windows 运行；V3 副本登记为 `tcb.validation.v3-package-tests`（`Test-V3.ps1` parity 检查随 CP06 加入，见 CP05 pair §3）。
- [x] P3.5 证明 V3 Diff 与 V3_ifx 当前 Diff 等价或更强；此阶段不删除 V3_ifx 副本（见 P7.5）。 证据：V3_ifx 与 V3 的 `templates/dotnet`、`scripts/Invoke-V3.ps1` 逐字节相同，由 `Invoke-IFXManifestCheck.ps1` 强制（`Test-IFXManifests.ps1` 负例）；`protection.json` 条目与原硬编码列表逐项相同；`Test-IFXTrustedBase.ps1 -DiffConsumptionOnly` 在配置化模板下通过；V3_ifx 副本保留至 P7.5。
- **门槛**：V3 具备 V3_ifx 全部通用加固，通用模板中不含 IFX 路径。
- **结果**：门槛通过（PR #46 → #47 CI 通过）。V3 模板具备 merge-base 校验、空 diff 失败关闭、受保护删除/重命名与 D20 授权消费；保护路径与授权目录由 Diff 配置提供，模板中不含 IFX 路径；V3_ifx 模板与 V3 逐字节相同；本阶段作为第一个常规两 PR TCB 变更（CP05-auth → CP05）完成。

### P4 — 受保护变更授权与 policy/config 双轨验证 — 已完成（2026-09-17，CP06a–CP06d；P4.4 延后）

- [x] P4.1 完整 schema 化 §12.2 授权格式，包括 `move`、`delete`、`case-rename`、`weaken-policy`、`change-trusted-base` 与 tree-entry tuple；与 P2.6 已启用的 TCB 授权格式保持兼容。 证据：`contracts/authorization.schema.json` 按 operation 约束五种授权，`change-trusted-base` format 1 记录保持有效；`weaken-policy` 在 CP06b 启用前消费即失败关闭（D23）。
- [x] P4.2 在 Diff 中实现 §12.3：Git plumbing 读取对象、已验证 merge-base 与 head SHA、`--raw -z --no-renames` changed set、gitlink 拒绝、`.gitattributes` 变更单独验证；授权从 trusted base 加载。 证据：`trusted-base/Test-IFXProtectedChanges.ps1` 以已验证 merge-base 与 head SHA、`--raw -z --no-renames` 派生保护义务并校验 base 授权（tree-entry tuple、gitlink 拒绝），报告绑定 base/merge-base/head/保护配置 hash，由 trusted runner 传给通用 Diff；`.gitattributes` 变更在 CP06a 失败关闭，CP06b 以 `weaken-policy` 开通（D23）。
- [x] P4.3 实现 §12.4 双轨验证与 JSON 规范化；以零比较器状态上线，所有 policy/config 语义变化要求 `weaken-policy` 授权；schema 新增字段未声明 monotonicity 时失败关闭。 进度（CP06b1）：`shared/policy-config.json` 登记 editable 与 trust/meta policy，trusted Diff 以零比较器产生 `policy-weakening` 义务、启用 `weaken-policy`，`Test-IFXPolicyCandidates.ps1` 从明确 head commit 验证 head 候选与 monotonicity 声明。 证据（CP06b2）：D18 blocking findings 作为 `policy-weakening` 义务由 `weaken-policy` 覆盖，authority gate 以 base verifier 针对明确 PR head SHA 重新计算覆盖（D25）；双轨验证在零比较器状态上线完成。
- [ ] P4.4 零比较器状态稳定后，按 P0.9 频率为首批 schema 增量实现比较器，每个比较器有收紧、等价、削弱和未知字段正反例；该项可在后续阶段持续进行。 延后（D23）。
- [x] P4.5 负向控制： 证据：全部负向控制由 `Test-IFXTrustedBase.ps1`（默认 TCB 与 domain authority 用例）与 `-DiffConsumptionOnly`（授权、路径操作、大小写重命名、gitlink、`.gitattributes`、policy 与 D18 覆盖）覆盖；大小写重命名在 CI Linux 与本地 Windows 运行；汇总见 CP06a、CP06b1、CP06b2 进度。
  - 仅 head 存在的授权；
  - tuple 不匹配（mode、type、objectId 任一不同）；
  - 额外删除、新增或重命名；
  - 未删除已消费授权；
  - 并发 PR 重复消费；
  - 未声明的大小写重命名（Linux/Windows）；
  - 受保护范围内的 gitlink；
  - 未验证的 `.gitattributes` 变更；
  - head 候选配置试图控制当前判定；
  - 未授权的候选削弱；
  - 未声明 monotonicity 的新 schema 字段；
  - head 同时削弱 TCB 实现与自身测试；
  - 未经 `change-trusted-base` 授权的非等价 TCB 语义变化；
  - TCB tuple、base-owned validation suite 或 parity contract 与授权不匹配。
  - 进度（CP06a）：仅 head 存在的授权、tuple 不匹配、额外删除/新增/重命名、未删除已消费授权、并发 PR 重复消费、未声明的大小写重命名、受保护范围 gitlink、`.gitattributes` 变更（失败关闭）由 `Test-IFXTrustedBase.ps1 -DiffConsumptionOnly` 覆盖；TCB 相关项沿用 CP04b 用例；policy/config 相关项随 CP06b。
  - 进度（CP06b1）：`.gitattributes` 变更改由 `weaken-policy` 授权；head 候选配置试图控制当前判定（候选只由 base engine 从 head Git 对象验证）、未授权的候选削弱、未声明 monotonicity 的新 schema 字段由 `Test-IFXTrustedBase.ps1 -DiffConsumptionOnly` 与 `Test-IFXManifests.ps1` 覆盖。
  - 进度（CP06b2）：D18 domain authority 的未授权削弱在 `v3-pre-diff` 与 authority gate 中一致失败，授权削弱在明确 head 下通过、无明确 head 时失败关闭，checkout 与明确 head 不一致时失败，由 `Test-IFXTrustedBase.ps1 -DiffConsumptionOnly` 覆盖。
- [x] P4.6 verifier 断言 ruleset `strict` 保持启用。 证据：`ci/Invoke-IFXCiContract.ps1` 的 `ruleset-strict` 检查；2026-09-17 针对 `3edb78a` 的 `-Remote` 报告 ruleset 检查全部通过（`docs/architecture/review/evidence/guards/p4-rehearsal-20260917/ci-contract-remote.json`）。
- [x] P4.7 在临时仓库或 fixture 中完成一次完整两 PR 演练，覆盖 `move`、`weaken-policy` 与 `change-trusted-base`。 证据：`trusted-base/Invoke-IFXProtectedChangeRehearsal.ps1` 针对 `3edb78a` 的两 PR 演练覆盖 `move`、`weaken-policy` 与 `change-trusted-base`，8 个步骤全部符合预期（`docs/architecture/review/evidence/guards/p4-rehearsal-20260917.md`）；演练发现过期 profile views 可随 policy-only PR 合入，已由 head policy 候选验证补上。
- **门槛**：在 §11.4 保证范围内，受保护路径的删除、移动、大小写重命名、policy/config 潜在削弱和非等价 TCB 语义变化只能通过 base 预授权完成，授权只能消费一次，未知语义变化失败关闭。
- **结果**：门槛通过（CP06a–CP06d）。受保护删除、移动、大小写重命名、policy/config 与 D18 domain authority 削弱、非等价 TCB 语义变化只能通过 base 预授权完成，授权按保护义务恰好消费一次，未知语义变化失败关闭；P4.4 比较器延后（D23），CP06d 以五条正交授权完成第一次真实受保护删除（D17）。

### P5 — V3 package-local 构建基线与输出迁出（可与 P1 并行，须在 P2.2 前完成）— 已完成（2026-09-17，CP03）

本阶段不涉及受保护路径删除或移动，不依赖 P2–P4。

- [x] P5.1 依据 P0.8 建立 V3 `build/` 基线（安全属性、包版本、`NuGet.config`、`global.json`、各可信门禁工程的 `packages.lock.json` 权威/模板），不弱于当前 IFX 根配置。 证据：`docs/guards/V3/build/`（`V3.Build.props`、`NuGet.config`、`global.json`、`GuardBuild.psm1`）；IFX 门禁工程 lock 位于 `docs/guards/V3_ifx/build/locks/`。包版本继续由 PackageReference 声明、由 lock 固定，未另建 `V3.Packages.props`。
- [x] P5.2 V3 与 V3_ifx 门禁工程显式 import V3 `build/` 基线；V3 公共命令构建时关闭目录向上搜索并通过命令行指定输出位置。 证据：显式 import 通过全局属性 `CustomBeforeMicrosoftCommonProps` 实现，不修改 csproj，保持模板与生成副本逐字节一致；目录发现开关全部关闭。
- [x] P5.3 restore 使用 locked mode；验证直接/传递依赖与 content hash；构建前 allowlist 预检和构建后 binlog 复核允许 SDK、V3 package、隔离生成文件和 lock 中的 NuGet build assets，拒绝其他 import。 证据：`GuardBuild.psm1` 自行强制 lock 存在、restore 前后不变、与 assets 及包 content hash 一致（实测 NuGet `--locked-mode` 对缺失或被改的 lock 不失败，并会重写 lock）；构建前 `msbuild -pp`、构建后 MSBuild 导入日志（`MSBUILDLOGIMPORTS`，替代 binlog 解析）核对 allowlist。
- [x] P5.4 `bin/obj` → `artifacts/build/<package>/`，报告与 runtime analysis 输出 → `artifacts/guards/<package>/<stage>/`。 证据：`artifacts/build/v3-ifx/{stage-gate,architecture-conformance}/`；报告与导入 allowlist 报告在 `artifacts/guards/v3-ifx/build/`。已跟踪的 runtime analysis 输出仍按 P8.6 迁出。
- [x] P5.5 完成 §8.3 验证清单。 证据：本地 Windows 全部验证项通过；Linux 由 CI `v3-cross-platform-ubuntu-latest` 验证。
- [x] P5.6 隔离验收：将 V3 复制到不继承任何 IFX 父目录配置的临时目录，完成 locked restore、build、Generate、Check 和 Test。 证据：`docs/guards/V3/tests/Test-V3BuildBaseline.ps1`（复制到系统临时目录，四周放置恶意 `Directory.Build.*`、`Directory.Packages.props`、`NuGet.config`、`global.json`）。
- [x] P5.7 增加测试断言 clean 运行后 `docs/guards/**` 下无 `bin/obj`。 证据：`Test-V3BuildBaseline.ps1` 与 `Test-IFXPackage.ps1` 断言包源码树无 `bin/obj`。
- **门槛**：源码树无构建输出；V3 安全基线在全部门禁工程中生效；locked restore 与 import allowlist 通过；V3 隔离运行通过；在 IFX 仓库内构建无 NU1008。
- **结果**：门槛通过（Windows 本地；Linux 待 CI）。本阶段使用 §11.6 的受控 bootstrap 窗口：可信构建基线由现有 CI、隔离测试与负向控制验证，P2 以本阶段合入后的 base 关闭窗口。LayerGuard 测试的 fixture 根改为可由 `LAYERGUARD_FIXTURES_ROOT` 指定（输出迁出源码树后原相对路径失效），属于 TCB 变更，在窗口内随本阶段验证。

### P6 — LayerGuard 去重与 generic engine / IFX binding 分离

- [x] P6.1 通过 §12 授权删除 `generated/dotnet/LayerGuard`，改为直接构建运行唯一源码；验证 build/test、policy binding、strict scan、正反 fixture、CI 调用路径和恢复。 证据：CP07a-prep（PR #58 → #59）先让 base-owned 绑定测试不依赖副本深度；CP07a 以 `delete`、`change-trusted-base` 与 `weaken-policy` 三条正交授权删除副本（174 个文件），`Invoke-IFX.ps1` 直接构建、测试、扫描 `templates/ifx-layerguard/`；`Test-IFXPackage.ps1` 覆盖隔离 build/test、policy binding、L2.2 strict scan 负向、只读 Generate 与源码清单、TCB 覆盖、fixture 对应的负向用例；CI 调用路径由 `v3-architecture` 与保留的 Generate/Check 调用验证；恢复需要新的授权，副本重新出现时 Check 失败（D26）。
- [x] P6.2 参数化 runtime role 和 IFX project/type names，移入 IFX policy/fixtures；通用测试改用 synthetic fixture。 证据：`ifx-api`/`ifx-worker`/`ifx-all` 与 `Runtime:Role`、必需 host role、授权 backup owner handle、不可豁免类别、豁免上限、`BCL-only` 与 G05 禁止依赖清单全部移入受 TCB 管控的 `src/LayerGuard.Ifx/IfxGatePolicyBinding.cs`（所有权迁移，policy 文件与 composite hash 不变，D27）；通用测试与 fixture 早已是 synthetic（`Acme`/`Shop`），`Invoke-IFX.ps1 -Mode Check` 对 `src/LayerGuard/`、`tests/LayerGuard.Tests/` 与 `tests/fixtures/` 执行大小写不敏感的 IFX 标识扫描，`Test-IFXPackage.ps1` 有对应负向用例。
- [x] P6.3 分离通用检测引擎与 IFX policy binding。 证据：engine 新增 `IPolicyBinding`、`PolicyBindings` 注册表与 `PolicyDocument` 助手，`gatePolicies` 原样交给已注册 binding；没有 binding 时失败关闭（`PolicyBindingTests` 两个用例）；IFX binding 与 host（`layerguard-ifx`）位于 `src/LayerGuard.Ifx`，Scan 运行该 host；composite hash `d25e881a…` 与 `policy/baselines/plan05.json` 一致，report 字段、12 条 policy binding、tool version `0.4.0-a1` 与 CLI/MCP 契约不变。
- [x] P6.4 通用 engine 迁入 V3 `Guards.ArchitectureConformance*`；V3_ifx 只保留 policy、baseline、binding 和 IFX fixtures。 证据：27 个 engine 源码文件迁入 `docs/guards/V3/stages/post/gates/architecture/dotnet/Guards.ArchitectureConformance/`（项目与 assembly 改名，namespace 作为内部兼容面保留，D29）；V3_ifx 只剩 policy、baseline、IFX binding/host、IFX fixture 与一个保留的空桥测试项目（base 仍拥有该路径，删除推迟到后续检查点）；184 个 engine 测试从 V3 测试项目运行通过，候选验证证明 base-owned 测试在迁移前后都能编译运行。
- [x] P6.5 按 §11.3 写入 Architecture Conformance 混合型 trust contract，包括 MSBuild import/Condition 盲区与 Assembly 检查的交叉兜底；针对 import 注入的检测规则仅作为独立规则提案登记。 证据：`stages/post/stage.json` 的 `v3-architecture` trust contract 增加 `policyBinding`、`crossCover` 与 `importInjectionRule`，写明 evaluator/policy/binding 全部来自 base、MSBuild import/Condition 与生成源码盲区分别由 `v3-quality-assembly` 与 `v3-quality-solution` 交叉兜底，import 注入检测仅登记为独立规则提案；`contracts/stage.schema.json` 与 `shared/policy-config.json` 相应登记。
- [x] P6.6 证明 policy composite hash、report 字段、失败类别和 `v3-architecture` check 名称不变。 证据：迁移后报告 composite hash `d25e881a…` 与 `policy/baselines/plan05.json` 一致；report 字段、12 条 policy binding、tool version `0.4.0-a1`、失败类别与 `v3-architecture` check 名称不变；policy 文件逐字节不变。
- **门槛**：174 文件重复消除；V3 engine 大小写不敏感扫描无 IFX 标识；Architecture Conformance Gate 无需复制即可运行，trust contract 完整。

### P7 — Stage Gate 命名、生成位置与 overlay 切换

- [x] P7.1 生成 `{ProjectId}.Guards.StageGate.Tests`，实现 identifier 转换与碰撞检查，内部划分 Self/Post/Diff。 证据：canonical runner 从 profile `projectId` 生成确定性 .NET identifier 与工程名，identity 文件阻止 `sample-a`/`samplea` 一类大小写不敏感碰撞；生成树包含 `Self/`、`Post/`、`Diff/`、`GeneratedInputs/`，canonical synthetic 与 ArchUnitNET 正/负向套件通过。
- [x] P7.2 通过授权从 Git 移除 `generated/stages`；Generate 输出改为仓库外生成根 `<生成根>/<package>/gates/stage/`，按 §11.2 隔离构建。 证据：Generate/Check/Test/Diff 对 `GenerationRoot` 执行与 `TargetRoot` 双向隔离校验，IFX 使用 package id `v3-ifx`；tracked snapshot 17 个文件删除，Stage Gate build 输出在外部 `build/v3-ifx/stage-gate/`，reviewed lock 移为 `Ifx.Guards.StageGate.Tests.packages.lock.json` 并通过 Locked restore。
- [x] P7.3 同步更新 workflow、`Invoke-IFXGuardrails -Mode Diff`、`.gitignore` 和 Check 逻辑；profile snapshot 不再以 tracked generated copy 存在。 证据：head candidate workflow 与 dispatcher 均直接调用 canonical V3 并传递 package/generation/stage root；`.gitignore`、project map、生成视图与 architecture draft 登记旧 generated 路径；Check 对项目专属外部树逐字节验证且拒绝多余文件。
- [x] P7.4 clean checkout 证明没有预生成源码也能完成 Generate/Check/Test/Diff。 证据：detached raw candidate `c645cecd` 从无预生成源码的 clean checkout 在仓库外 generation/build root 完成 IFX Generate、Check、8 项 Post/Self Test 与 1 项 Diff Test；`git ls-files docs/guards/V3_ifx/generated/stages` 为空，运行后 checkout 无 tracked 或未忽略改动。
- [x] P7.5 V3_ifx 切换为直接引用 V3 engine，通过授权删除与 V3 逐字节相同的 scripts、hooks 和 tests。 证据：IFX workflow、orchestrator、manifest 与 base-owned validation 只引用 canonical V3；内部 architecture script、hooks、dotnet templates 和三个 generic tests 删除，TCB transition component 移除，仅三个声明期 public legacy path 保留 thin wrapper。
- **门槛**：Stage Gate 可从 JSON 和模板确定性重建，且不在仓库目录内构建；V3_ifx 不含通用实现副本。

### P8 — 最小 manifests、analysis 生命周期与首批只读聚合文档

- [x] P8.1 在 P1.5 最小 skeleton 上补全并迁移 `guard-system.json`、`stage.json`、`commands.json`、`trusted-components.json`，新增并 schema 化 `docs-map.json`；按 §6 字段 owner 表校验无重复字段，`evidence` 仅由 `commands.json` 拥有，不得改变 P2 已使用的稳定字段语义。证据：manifest checker 验证 6 stages、18 commands、18 trusted components、13 gates，并校验 docs-map schema、字段 owner 与命令路径。
- [x] P8.2 建立 `commands/` 稳定入口；旧公共路径保留薄 wrapper。证据：V3 runner/setup/docs 与 IFX dispatcher 已迁入 `commands/`，workflow、hooks、tests、manifest 与 trusted-base 使用 canonical 路径；原公共路径仅输出弃用提示并转发参数和退出码。
- [x] P8.3 确认无消费者后移除 `Invoke-V3Docs` 的 `Import` 模式。证据：入口只接受 Render/Check；工具回归显式断言 Import 被拒绝且编辑生成 Markdown 不改变 JSON authority。
- [x] P8.4 实现 renderer/checker，生成 `OVERVIEW.md`、`COMMANDS.md`、`POST.md`、`CI.md`，含来源路径、角色和 composite hash。证据：Docs Check 对 20 份 authority-derived Markdown 逐字节通过，并以正反例覆盖 authority drift、手工编辑、缺失及额外输出。
- [x] P8.5 将人工背景迁入 `docs/authored/`，确保 Render 不覆盖。证据：五份 architecture 背景文档迁入 `docs/authored/architecture/`，不属于 docs-map 输出集合。
- [x] P8.6 按 P0.2 结论落实 analysis 生命周期：运行时输出改写到 `artifacts/guards/<package>/analysis/`；经评审的长期输入与报告快照只通过 `maintenance/` Preview/Apply 更新。证据：Analyze/Review 的默认输出位于 artifacts；工具测试证明连续运行可复现且不改长期证据；maintenance 测试证明 Preview 只读、未接受的 Apply 失败、显式接受后才更新。
- [x] P8.7 决定 `profiles/ifx/views/` 保留为只读生成视图或并入首批文档。证据：按 D4 保留 read-only profile views，移除内嵌 JSON 写回面，并纳入同一 Render/Check 完整输出集。
- **门槛**：任意 authority 变化都会导致相关 Markdown Check 失败；无陈旧生成视图；Analysis 运行不再写入 `docs/guards`。

### P9 — 轻量 workflow candidate 与激活验证

- [x] P9.1 建立 V3 通用 renderer 与 V3_ifx `workflow.template.yml`、`workflow.variables.json`、`required-checks.json`、`activation.json`。证据：`V3/commands/Invoke-V3Deployment.ps1`、`stages/ci/` 权威文件及 activation/variables/required-checks schema（CP10）。
- [x] P9.2 实现 §10.2 的 Generate/Check，candidate 写入 `artifacts/generated/`；Check 包含"PR 判定第一个可执行入口位于 base worktree"。证据：candidate 只写 artifacts；CI contract 覆盖 canonical YAML、DAG/名称/触发、仅 public command 与 `trusted-base-first-verdict` 正反例（CP10）。
- [x] P9.3 实现 Preview、`Install -AcceptDeployment` 和人工复制后的 Verify；激活副本带 source path/hash 头。证据：fixture 拒绝无接受开关，验证 provenance header、source SHA、managed block 保留 unmanaged 内容及 Verify 漂移失败（CP10）。
- [x] P9.4 以 `required-checks.json` 取代 `ci/jobs.json`，远端只读 verifier 比较 ruleset；远端写入保持独立授权。证据：schema-valid authority 与 read-only verifier；ruleset `23459908`、strict、13 个名称不变；旧文件受控删除（CP10）。
- [x] P9.5 CODEOWNERS managed block 纳入同一生命周期。证据：`codeowners.template` 与 activation mapping；真实 CODEOWNERS 本检查点不激活，fixture 覆盖 Install/Verify（CP10）。
- [x] P9.6 候选与现有激活 workflow 并行比较，不改变任何 check 名称，不立即切换。证据：Preview 将两个现有目标标记为 `legacy-equivalent`，active workflow 未经 Install 改写，13 个 check 精确相等（CP10）。
- **门槛**：候选与激活副本之间不存在未解释差异；workflow 只调用公共命令；模板检查器有正反例。

### P10 — 物理目录迁移、V3_backup 删除与兼容入口清理

- [ ] P10.1 将 project map、risks、rules、toolchain、assembly manifest、protected paths、workflow 和 required checks 分配给明确 Stage/Shared authority；旧 profile 格式通过只读兼容加载器或一次性迁移器并行比较，不允许 silent fallback。
- [ ] P10.2 按 §13 映射以检查点分组移动，每组使用授权 PR + 变更 PR。
- [ ] P10.3 将内部实现迁入 `engine/`，生成逻辑迁入 `generators/`，hooks/skills/GitHub glue 迁入 `integrations/`，policy sync、history regeneration、analysis evidence 更新和迁移工具迁入 `maintenance/` 并补齐 Preview/Apply；按 Stage 重组测试，不改变覆盖。
- [ ] P10.4 每组移动后更新 manifest、链接、脚本、tests 和 docs，并运行完整 Check。
- [x] P10.5 通过授权删除 V3_backup（D2）。证据：CP11b 先以 base-owned bridge 移除测试夹具对备份树的依赖，再消费目录级 `delete`、TCB 与 policy/config 授权删除 41 个重复文件；canonical V3 与 Git history 为唯一恢复边界。
- [ ] P10.6 旧公共路径保留明确 deprecation wrapper；内部路径不提供永久兼容。
- [ ] P10.7 验证仓库引用扫描无悬空路径，无隐含外部配置权威。
- **门槛**：新结构可在 Linux/Windows clean checkout 重现，旧兼容入口只剩批准范围。

### P11 — 并行验证、切换、清理与回退证明

- [ ] P11.1 对 Analysis、Pre、Post、Diff、CI、专项、质量、历史完整性运行新旧正常与负向 parity。
- [ ] P11.2 验证以下场景均失败关闭：目录移动、生成物缺失、hash drift、policy drift、protected deletion、未授权移动、授权重复消费、未声明大小写重命名、受保护范围 gitlink、未知 schema 字段、未授权削弱、head 篡改入口调用链/engine/配置、head 同时修改 TCB 与自身测试、未经授权的非等价 TCB 变化、lock/依赖/content-hash 漂移、有效 import 越界、浅克隆、空 diff 和未知 command。
- [ ] P11.3 将 V3 源码包置于不继承 IFX 配置的隔离目录，对空白 fixture 仓库执行 Bootstrap，得到可运行的 Pre/Post/Diff 与 Architecture Conformance 门禁。
- [ ] P11.4 通过以 `codex/guards-principles-plan` 为 base 的真实 PR 验证候选 workflow 与 13 个 required checks，并以 `workflow_dispatch`、`windowsCoverage=full` 保存一次 Windows 全量候选认证证据后，单独取得激活授权（D35）。
- [ ] P11.5 只有在激活与回退验证完成后，删除旧 wrappers、重复目录和失效文档。
- [ ] P11.6 保存精确删除清单、恢复 commit 和 selective restore 演练记录。
- **门槛**：新结构是唯一生产路径，旧路径零运行时引用，全部 blocking 能力有可审查正反证据。

## 15. 验收标准

全部满足后才可标记完成：

1. V3/V3_ifx 所需机器配置及 V3 最低构建与安全基线均在各自 package 内，外部仅有激活副本、构建输出和运行证据。
2. Analysis、Pre、Post、Diff、CI 的命令、依赖、trust contract 和证据可由目录和 manifest 直接识别；`stage.json` 与 `commands.json` 无重复字段 owner，`evidence` 只有一个 owner。
3. 通用 V3 engine/template 中不存在 IFX 路径、项目名、runtime role 或 policy 硬编码（大小写不敏感扫描）。
4. 每个公共命令都有 command manifest 分类；workflow 不直接调用 internal/maintenance/test-support。
5. Stage Gate 项目名由 project ID 参数化；Stage Gate 和 Architecture Conformance Gate 名称及职责清晰，不以 ArchUnitNET、LayerGuard 等实现细节作为稳定身份。
6. `templates/ifx-layerguard` 与 `generated/dotnet/LayerGuard` 的 174 文件重复被消除；Architecture Conformance 通用 engine 位于 V3。
7. `docs/guards` 下无 `bin/obj`、生成源码和运行报告；clean 后不会重新写入这些位置；Analysis 运行不写入 `docs/guards`。
8. 所有生成 Markdown、workflow candidate 和 Stage Gate 都能确定性重建并 Check；生成 Markdown 全部只读。
9. 激活 workflow 带来源/hash，可通过 Verify 证明与 candidate 一致。
10. stage/policy rule 不只校验 ID；coverage binding 能表达 full/subset/advisory 和 authority/hash。
11. 当前 views/review/deployment/jobs 声明漂移已清零，并由 CI 阻止复发。
12. 在 §11.4 保证范围内，PR 门禁从第一个可执行入口起使用 trusted base 的调用链、engine、配置和授权；head 篡改负向控制全部失败关闭。
13. 每个 required check 都有 trust contract，混合型与执行型门禁的保证范围与盲区已显式声明。
14. 可信 restore 使用受版本控制的 lock file 与 locked mode；直接/传递依赖和 content hash 固定，restore 不改写 lock。
15. 构建前 import 预检与构建后 binlog 复核通过：只加载固定 SDK、V3 package、隔离生成根中的 NuGet 生成文件，以及与 lock 中 package ID/version/content hash 一致的 NuGet build assets；不加载 head、宿主父目录或用户自定义 import。
16. 全部 TCB component 进入 manifest；head 候选通过 base-owned validation 与固定 corpus parity；head 修改自身测试不能降低验证覆盖；非等价语义变化需要 `change-trusted-base` 预授权。
17. 在 §11.4 保证范围内，受保护路径删除、移动和大小写重命名只能通过 base 预授权完成，授权只能消费一次，并以 tree-entry tuple 与 NUL 分隔 raw diff 验证。
18. 在 §11.4 保证范围内，policy/config 潜在削弱必须显式授权；未知语义变化与未声明 monotonicity 的 schema 字段失败关闭。
19. 13 个 required check 名称与迁移前完全一致。
20. 位于隔离目录的 V3 源码包可独立完成 locked restore/build/Generate/Check/Test，并能从空白 fixture 仓库 Bootstrap 出可运行门禁。
21. V3_ifx 不含 V3 通用实现副本；V3_backup 已删除。
22. 新旧生产能力通过 Linux/Windows、正常/负向、clean checkout 和真实 PR 验证。
23. 迁移有精确回退清单，不修改或丢失历史证据和领域权威。

## 16. 风险与控制

| 风险 | 控制 |
| --- | --- |
| 大规模移动导致引用和 CI 同时失效 | 先 manifest、后分组移动；保留薄 wrapper；每组独立 Check |
| 现有受保护路径检查阻断迁移 | §12 base 预授权两 PR 协议；P4 完成前不执行任何受保护删除或移动 |
| head 入口 wrapper 直接返回成功或篡改传给 engine 的参数 | §11.1 第一个可执行入口及完整调用链来自 base；wrapper/dispatcher/module/`commands.json` 负向控制 |
| PR 通过修改 engine 或配置削弱自身门禁 | §11 Trusted Base Guard Execution；负向控制；保证范围按 §11.4 声明 |
| 合法配置合并后成为弱化的 trusted base（两步削弱） | §12.4 双轨验证、schema-specific monotonicity、`weaken-policy` 授权；在 O1 暂缓下保证显式与可追溯，范围见 §12.5 |
| head 同时修改 TCB 实现与自身测试，合并后削弱下一次 trusted base | §11.5 TCB manifest；base-owned validation 与固定 corpus parity；`change-trusted-base` 预授权；head tests 仅补充 |
| 削弱类型枚举不完整形成静默绕过 | 未知语义变化失败关闭；零比较器起步；新字段必须声明 monotonicity |
| head 通过 MSBuild/NuGet/SDK 向上搜索注入可信构建 | 仓库外生成根；关闭目录 import 开关；显式 `NuGet.config` 与 `global.json`；有效 import 断言 |
| 生成工程继承根 Central Package Management 导致 NU1008 | V3 `build/` 显式包版本；关闭 `Directory.Packages.props` import；P5 验证 |
| 传递依赖或 NuGet build assets 漂移改变可信 evaluator | `packages.lock.json`、locked mode、content hash 校验、构建前 import allowlist 与构建后 binlog 复核 |
| 宿主配置 import 覆盖 V3 安全基线 | 宿主叠加默认关闭；仅允许显式 base 文件、白名单与有效属性检查 |
| V3 依赖宿主父目录隐含配置，无法移植 | package-local `build/` 基线；P5.6 与 P11.3 隔离验收 |
| 混合型/执行型门禁被误当成完全可信 | §11.3 逐 Gate trust contract；summary 报告保证范围 |
| LayerGuard 看不到 MSBuild import 注入的引用 | Assembly 检查交叉兜底；盲区登记；注入检测规则作为独立提案 |
| 授权验证遗漏 mode/type 变化、rename heuristic 误判或 gitlink | tree-entry tuple；`--raw -z --no-renames`；gitlink 直接失败；`case-rename` 独立 operation |
| merge-base 端点在合并时失效 | ruleset `strict` 断言（P1.3、P4.6） |
| 迁移授权被自我授权或重复消费 | 授权只从 base 加载；消费即删除；ruleset strict up-to-date |
| workflow 定义或授权 PR 无需审批即可合入 | 已知残余风险；按 §18 O1 暂缓，本计划不做改变 |
| break-glass 被滥用为常态 bypass | 仅限仓库外部治理；完整记录与事后复验 |
| 直接切换 V3 canonical engine 造成安全回退 | P3 先合回 V3_ifx 通用加固并证明等价或更强，P7 才切换 |
| Stage 化导致 shared 配置复制 | `shared/` 唯一权威；stage manifest 只引用不复制 |
| 治理元数据过重并自身漂移 | 字段唯一 owner；首批四份文档；workflow 不做 DSL；比较器按频率增量实现 |
| 聚合 Markdown 隐藏来源 | 强制来源路径/角色与 composite hash；CI 逐字节 Check |
| workflow 模板产生有效 YAML 但无效门禁 | 校验 command/stage IDs、base 入口与 required checks，运行本地 dispatcher，真实 PR 负向控制 |
| 人工复制后目标文件漂移 | candidate header、activation manifest、Verify 和 required-check verifier |
| LayerGuard 去重或 binding 剥离降低覆盖 | 删除前执行 build/test、scan、fixture 和 policy binding 验证；composite hash 与报告字段不变 |
| 新命名影响 required checks | §10.3 名称不变量；显示名称与内部路径解耦 |
| 运行时 analysis 输出与评审证据混杂 | P0.2 生命周期分类；P8.6 运行时输出进入 `artifacts/` |
| 生成目录仍累积构建垃圾 | 输出强制定向 `artifacts/` 或仓库外生成根；测试断言 docs 树无 bin/obj |

## 17. 设计决策

D1–D15 已根据 Review 共识关闭；D16–D17 为 P1.1 依据 P0 基线补充的决定；D18、D19 为 P2 实施分析补充的决定；D20 为 P2 验证后发现授权消费冲突而补充的决定。后续若要改变这些决定，必须新增 decision JSON/ADR，并重新评估受影响阶段，不得在实施中静默改变。

### D1 — V3_ifx 的分发边界

- **决定**：仓库内使用 V3 canonical engine + V3_ifx overlay，V3_ifx 直接引用仓库内 V3，不维护通用实现的手工 fork。
- 不要求 V3_ifx 单独复制即可运行；不提供 self-contained distribution，不引入 `core.lock.json`。
- 新仓库使用 V3 源码包 Bootstrap 生成自己的门禁，由验收标准 20 证明。
- 来源：用户答复；Review §1、§6.1。

### D2 — V3_backup 的长期角色

- **决定**：删除 V3_backup，仅保留 V3 源码包；历史恢复依赖 Git history/tag，不保留 release snapshot。
- 删除在 P10.5 通过 §12 授权执行。
- 来源：用户答复；Review §1、§6.1。

### D3 — 是否跟踪生成的 Stage Gate 源码

- **决定**：不跟踪。CI 和本地验证每次从模板、JSON 和 manifest 执行 Generate + Check。
- 生成源码与构建输出位于仓库外的生成根（CI 为 `$RUNNER_TEMP/guard-gen`），不写入仓库 `artifacts/`，以避免继承宿主或 head 的 MSBuild 配置。
- Git 只跟踪权威配置、模板、生成器和生成资产 manifest；代码 Review 通过候选 diff、生成报告和确定性检查完成。
- 落实范围见 P7.2–P7.4。
- 来源：用户答复；Review R7、§6.6、§11.4、§12.3。

### D4 — 生成 Markdown 是否允许反向 Import

- **决定**：全部生成 Markdown 只读，移除 Markdown → JSON Import，包括一对一配置页。
- 生成文档列出来源路径、角色和一个 composite hash。
- 来源：用户答复；Review §1、§6.1、§6.7。

### D5 — 激活文件的安装方式

- **决定**：同时支持人工复制 + Verify，以及工具化 `Install -AcceptDeployment`。
- Generate/Check/Preview 不得写目标位置；Install 必须显式确认并记录 source/target/hash。人工复制后必须运行同一个 Verify。
- 来源：用户答复。

### D6 — 稳定命名语言

- **决定**：目录、JSON ID、command ID 和 project 名使用英文；生成/人工文档可以使用中文。
- 稳定能力名称采用 `StageGate` 和 `ArchitectureConformance`；不把 ArchUnitNET、LayerGuard 等工具品牌写入长期稳定身份。迁移文档和 provenance 仍必须记录实现来源。
- 通用 V3 项目名不含具体项目前缀；项目前缀只能由 profile project ID 派生。
- 来源：用户答复；Review R6。

### D7 — 迁移单位与顺序

- **决定**：先完成基线、决策、构建基线、信任模型和授权，再按"V3 通用能力 → V3_ifx overlay"迁移，顺序与依赖见 §14。
- 禁止分别为 V3 与 V3_ifx 设计两套结构；IFX 需求先判断能否作为通用能力进入 V3，不能通用化的部分才进入 overlay。
- PR 以可独立验证和回退的检查点为单位。
- 来源：用户答复；Review §6.8。

### D8 — 历史完整性的 Stage 归属

- **决定**：目录上属于 `stages/post/gates/historical-integrity`，因为它产生 blocking validation；manifest 的 `executionClass` 标记为 `governance-audit`，允许 schedule/manual 与受影响路径触发策略。
- 触发策略调整必须满足 §10.3：`v3-historical-integrity` 作为 required check 不得在 PR 上永久 pending。
- 来源：用户答复。

### D9 — Trusted Base Guard Execution

- **决定**：PR 门禁从 workflow 之后的第一个可执行入口起，公共命令、orchestrator、dispatcher、module、`commands.json`、engine、contracts、protection config、policy 和授权均取自只读 base worktree；head 仅作为显式 target。每个 Gate 以 trust contract 声明实际保证范围，Architecture Conformance 按混合型描述。实现约束、首次引入例外、break-glass 与保证范围见 §11。
- 来源：Review R2、§6.3、§7.4、§8.3、§9.2、§10.2、§11.2、§12.2、§13.3。

### D10 — 受保护变更授权

- **决定**：采用 base 预授权、消费即删除的两 PR 协议，operation 包括 `move`、`delete`、`case-rename`、`weaken-policy`、`change-trusted-base`；授权与验证使用 tree-entry tuple、已验证 merge-base 与 NUL 分隔 raw diff；受保护范围内 gitlink 直接失败。保证范围限定在 §11.4 内，见 §12。
- 来源：Review R1、§6.2、§7.3、§8.2、§10.5、§10.6、§11.5、§12.4、§13.5。

### D11 — 轻量 workflow 模板

- **决定**：workflow 在 V3 内生成、验证后再复制，但采用 canonical YAML 模板 + 少量稳定变量，不引入 JSON DSL；`required-checks.json` 保持独立机器权威。见 §10。
- 来源：Review §3、§6.7、§7.2。

### D12 — Architecture Conformance Gate 所有权

- **决定**：LayerGuard 派生的通用检测引擎在剥离 IFX binding 后进入 V3；V3_ifx 只保留 policy、baseline、binding 和 IFX fixtures。§20 的后续替换只替换 V3 中的内部实现，不再移动 Gate 位置或改变稳定身份。
- 来源：Review R4、§6.5、§7.1。

### D13 — Policy/config 双轨验证与单调性

- **决定**：base policy/config 对当前 PR 唯一权威判定；head 候选只接受验证、合并后生效。采用 schema-specific monotonicity，只有可机械证明为收紧或等价的变化无需授权；已知削弱与未知语义变化需要 `weaken-policy` 授权；schema 新增字段必须声明 monotonicity。以零比较器起步，按修改频率增量实现比较器。见 §12.4。
- 来源：Review §10.3、§11.3、§12.1、§13.2。

### D14 — V3 package-local 构建基线与可信构建隔离

- **决定**：V3 `build/` 携带最低完整的构建、包、SDK/NuGet 与安全基线，包括各可信门禁工程的 lock file；restore 使用 locked mode 并校验直接/传递依赖和 content hash。门禁工程显式 import，不依赖宿主父目录配置；可信构建位于仓库外生成根，关闭目录向上搜索，通过构建前 allowlist 与构建后 binlog 验证有效 imports；合法 imports 包括固定 SDK、V3 package、隔离 NuGet 生成文件和与 lock 一致的 NuGet build assets。宿主配置叠加默认关闭，只允许显式 base 文件并经白名单与有效属性检查；不采用嵌套 `Directory.Build.props` import 根配置的方案。见 §8.3、§11.2。
- 来源：Review §7.5、§8.4、§10.4、§11.4、§12.3、§13.4。

### D15 — Trusted Base Component 候选升级

- **决定**：所有下一次执行会进入 trusted base 的入口、orchestrator、engine、contracts、base-owned tests/fixtures、生成器、构建基线、lock files 与 activation contract 均进入 TCB manifest。head 候选不能控制当前 PR 判定，必须通过 base-owned validation 与固定 corpus parity；head tests 只允许补充。除 tuple/行为可机械证明等价的变化外，TCB 语义变化必须消费 `change-trusted-base` 预授权，合并后才成为下一次 trusted base。见 §11.5、§12。
- 来源：最终审查；Review §14。

### D16 — 比较器实现顺序（P1.1 补充，细化 D13）

- **决定**：单调性比较器按各 schema 的 commit 修改次数排序实现：`profiles/ifx/rules`、`profiles/ifx/project-map`，其次 `contracts`、`profiles/ifx/tech-stack`；`ci/jobs.json` 因 P9 被取代而排除。D13 的零比较器起步与未知变化失败关闭规则不变。
- 来源：P0.9 `change-frequency.json`；记录 `20260916-v3-stage-d16-comparator-order-by-commit-frequency.json`。

### D17 — Plan04 阶段校验脚本退役（P1.1 补充）

- **决定**：`Test-Plan04Documentation`、`Test-Plan04Phase0Baseline`、`Test-Plan04Phase1Inventory`、`Test-Plan04Phase2Audit` 不接入任何门禁，待 P4 授权机制可用后通过 base 预授权删除。 已由 CP06d 通过四条 `delete` 与一条 `change-trusted-base` 预授权删除。
- 来源：DRIFT-09；三者在基线上失败，四者默认改写冻结证据，能力已由 `Test-Plan04Governance.ps1` 覆盖；记录 `20260916-v3-stage-d17-plan04-phase-validator-retirement.json`。

### D18 — Domain authority 混合信任模型（P2 补充，细化 D9、D13）

- **决定**：Gate 读取的 domain authority 采用 base evaluator + head candidate authority + anti-weakening 授权的混合模型；角色按 JSON Pointer 登记为 `target-declaration`、`governing-policy`、`exception-authorization`、`derived-projection`、`evidence`；candidate projection 由 base generator 在临时目录生成并先通过 anti-weakening 检查；P4 之前削弱类变化失败关闭。见 §11.3、§12.6。
- 来源：P2 实施分析；Codex 混合模型意见与 Claude 三点补充（字段粒度角色、与零比较器起步的协调、与 P4 的时序），用户于 2026-09-17 批准；记录 `20260917-v3-stage-d18-domain-authority-hybrid-trust.json`。

### D19 — Trusted base 首次引入例外与分步启用（P2 补充，细化 D9、D15）

- **决定**：§11.6 首次引入例外分两步合入。CP04c 合入全部前置（可信构建输出迁出、LayerGuard 测试 target root 修正、CI 激活契约检查、负向控制与文档），不改变 workflow；CP04d 把全部 required check 切换为 base runner，并在 `ci/jobs.json` 声明 `trustedBase.execution` 与 `tcbCandidateVerification` 生效。激活标志从 base commit 读取，因此在 CP04d 之后的下一个 PR 首次生效并须验证其阻断；此后 TCB 变更一律需要 `change-trusted-base` 授权，例外不得复用。
- 来源：CP04c 以 CP04b runner 对仓库逐一运行全部 mode 时发现的 LayerGuard 测试根推导缺陷；记录 `20260917-v3-stage-d19-trusted-base-first-introduction.json`。

### D20 — 授权记录消费与一次性 break-glass（P3 前补充，细化 D10、D15、D19）

- **决定**：trusted Diff 只接受 base 候选 verifier（runner 以 authorization-only 模式针对精确 PR head 运行）确认被本变更消费的授权记录的普通删除；重命名、其他受保护删除、未验证或注入的消费、未被消费的授权删除仍失败；不把任意授权删除定义为安全撤销，撤销等待 P4。修复本身按 §11.7 以一次性 break-glass 合入：授权 PR 加入记录，修复 PR 消费记录，仅在修复 PR 合入期间从 ruleset 移除 `v3-pre-diff`，保留前后快照并立即恢复，事后以常规 PR 做正反复验。
- 来源：CP05 准备时发现 CP04b 的 verifier（要求删除被消费记录）与 base Diff（禁止 `docs/guards/V3_ifx/` 下删除）互相阻断；用户于 2026-09-17 选择方案 A，并只授权本地准备与模拟；记录 `20260917-v3-stage-d20-authorization-consumption-and-break-glass.json`。

### D22 — 未消费授权的 revocation-only 撤销（P4 补充，细化 D10、D20）

- **决定**：未被消费的授权只能在 revocation-only PR 中撤销：committed changed set 只包含 base 中 schema-valid 授权记录的普通删除，以及本次 formal plan pair 的新增或修改；混入任何其他变更时，被删除的记录都作为消费候选，未使用即失败。撤销适用于所有 schema-valid operation，包括尚未启用消费的 operation。
- 来源：D20 将未消费授权的删除留待 P4；用户于 2026-09-17 批准；记录 `20260917-v3-stage-d22-revocation-only-authorization-deletion.json`。

### D23 — 保护义务、CP06 拆分与绑定报告（P4 补充，细化 D10、D13、D15、D20）

- **决定**：P4 拆分为 CP06a（完整授权 schema、Git 对象验证、路径操作）、CP06b（policy/config 双轨与 `weaken-policy`）、CP06c（两 PR 演练与证据）、CP06d（第一次真实 D17 删除），P4.4 延后。trusted Diff 以 `--raw -z --no-renames` 从已验证 merge-base 派生保护义务（受保护路径删除、TCB 变化，CP06b 增加 policy 削弱），以 head 删除的 base schema-valid 记录为候选，每个义务恰好由一个候选覆盖、每个候选至少覆盖一个义务；未启用的 operation 即使 schema-valid 也失败关闭，`.gitattributes` 在 CP06a 一律拒绝、CP06b 以 `weaken-policy` 开通；受保护范围 gitlink 失败，授权记录不可修改。允许集合报告由 base 生成，绑定 base、merge-base、head 与 Diff 保护配置 hash，通用 Diff 仅在全部绑定一致时精确豁免报告列出的删除。旧消费变量在 CP06a 模板中保留兼容，CP06b 删除。
- 来源：CP06 设计评审，用户于 2026-09-17 有条件批准；记录 `20260917-v3-stage-d23-protected-change-obligations.json`。

### D24 — policy/config 双轨、`weaken-policy` 与 CP06b 拆分（P4 补充，细化 D13、D18、D20、D23）

- **决定**：CP06b 拆为 CP06b1 与 CP06b2。CP06b1 以 `shared/policy-config.json` 登记 editable policy（IFX profile、project map、tech stack、rules、`policy/layerguard.json`、`policy/baselines/plan05.json`、`history/manifest.json`）与 trust/meta-policy（`policy/authorities.json`、明确列出的 stage manifests 与 `stages/diff/protection.json`、`shared/*.json`、`guard-system.json`、`ci/jobs.json`、`contracts/*.schema.json`、根 `.gitattributes` normalized text 根指针），排除 `stages/diff/authorizations/`；derived projection 只能是 base `policy/authorities.json` 的精确 target。零比较器下每个已登记文件的语义变化都是 `policy-weakening` 义务，与 TCB 义务正交，trust/meta 变化同时需要 `change-trusted-base` 与 `weaken-policy`（可在同一授权 PR）；`weaken-policy` 按 blob hash、head tuple、schema 与 pointer 集合精确覆盖。trusted Diff 从明确 head commit 的 Git 对象验证 head 候选（schema、profile、history manifest 引用/hash/summary、projection、monotonicity 声明），报告绑定 base、merge-base、head 与保护配置、registry、授权 schema hash。CP06b1 由 CP06a base 判定（activation exception），下一个修改已登记 policy 的 PR 验证新规则；CP06b2 合入前 D18 blocking findings 继续失败关闭，b2 由 base verifier 针对明确 head SHA 重新计算覆盖，不信任 checked-out head 或隐式 merge commit。
- 来源：CP06b 设计评审，用户于 2026-09-17 有条件批准；记录 `20260917-v3-stage-d24-policy-config-dual-track.json`。

### D25 — D18 domain authority 的 `weaken-policy` 覆盖（P4 补充，细化 D18、D23、D24）

- **决定**：D18 比较增加 Git 对象模式，按 merge base 与明确 head commit 的 blob 报告 blocking pointers 与 blob hash；base protected change verifier 把有 blocking findings 的 authority 作为 `policy-weakening` 义务（schema `domain-authority:<id>`，pointer 为 blocking pointers），由 `weaken-policy` 精确覆盖。Validate、Architecture 与 Specialized 在收到明确 `-HeadRef` 时以 Git 对象比较 authority，blocking findings 只有在 base verifier 针对该 commit 重新计算、报告绑定 base、merge base、head 与保护配置、registry、授权 schema hash，且每个 blocking authority 恰好由一条已消费的 `weaken-policy` 以相同 pointer 覆盖时才通过；授权记录、算法与 registry 全部来自 base，checkout 中变化的 authority 必须与明确 head 一致；没有明确 head 时继续失败关闭。workflow 为这些 gate 传入 PR head SHA（非 PR 事件为 `github.sha`）。CP06b2 是第一个由 CP06b1 规则判定的 PR，同时消费 `change-trusted-base` 与 `weaken-policy`。
- 来源：CP06b 设计评审（C、D），用户于 2026-09-17 批准；记录 `20260917-v3-stage-d25-domain-authority-coverage.json`。

### D26 — Architecture Conformance 拆分、Generate/Check 过渡与 `mcp/LayerGuard` 范围（P6 补充，细化 D12、D23）

- **决定**：P6 以 CP07a-prep、CP07a（P6.1）、CP07b（P6.2–P6.3）、CP07c（P6.4–P6.6）交付，每个都是精确候选授权 PR 加消费变更 PR。CP07a-prep 先让 base-owned `GatePolicyBindingTests` 从 runner 传入的 `LAYERGUARD_PACKAGE_ROOT` 或向上寻找 `policy/layerguard.json` 解析 package root，并把模板与 generated 副本的逐字节比较限定在 Check/Generate（候选验证只叠加 base-owned 模板测试，Test/Scan 若仍比较会把叠加本身报为漂移）（expand），CP07a 再从模板直接构建并删除 generated 副本。过渡期保留 `Invoke-IFX.ps1` 的 Generate/Check 与 active workflow 调用：Generate 只读且不得重建已删除的树，Check 做源码清单、policy 绑定与 fixture 的实质检查；P6.4 建立替代入口前不输出正式 DEPRECATED 信息；P9 只从候选 workflow 移除调用，active workflow 清理随 P11.4/P11.5。`mcp/LayerGuard` 作为历史完整性与切换保留约束下的遗留 MCP 项目不在 P6 范围，后续去重需要单独决定与 plan。
- 来源：CP07 设计评审，用户于 2026-09-17 批准；CP07a 实施发现 base-owned 测试的固定深度路径冲突后，用户批准插入 CP07a-prep；记录 `20260917-v3-stage-d26-architecture-conformance-split.json`。

### D27 — Architecture Conformance engine 与 IFX binding 分离、IFX facade 与 expand 步骤（P6.2–P6.3 补充，细化 D12、D23、D26）

- **决定**：P6.2–P6.3 以 CP07b-prep、CP07b 交付，每个都是精确候选授权 PR 加消费变更 PR，不使用 activation exception。engine 中硬编码的 IFX 值（`ifx-api`/`ifx-worker`/`ifx-all` 部署单元与 `Runtime:Role`、必需 host role、授权 backup owner、G03 不可豁免类别、豁免上限与 `BCL-only`、G05 禁止依赖清单、`gatePolicies` 输入与 G04 RuntimeHost→Composition 角色绑定）迁入受 TCB 管控的 IFX binding 代码；这是所有权迁移，不是 policy 外部化，所有 policy 文件与 composite hash 输入逐字节不变。通用 engine 成为带 binding 扩展点的库与命令行，原样把 `gatePolicies` 段交给已注册的 binding，存在该段而无 binding 时失败关闭；IFX binding 与轻量 host 注册 binding，并保持 CLI/MCP 契约。CP07b-prep 为 expand：新增显式引用的 IFX facade 项目 `src/LayerGuard.Ifx`（入口 `LayerGuard.Ifx.IfxArchitectureConformance.Analyze`，CP07b 前转发到 engine，之后保持同一路径与入口），把 `GatePolicyBindingTests` 迁入只引用 facade 的 base-owned `tests/LayerGuard.Ifx.Tests`。project reference 全部显式：`Invoke-IFX.ps1` 检查精确的 solution 项目集合与每个项目的引用集合，拒绝通配符引用，并对每个列出的项目执行锁文件与 import allowlist 校验。report 字段、tool version、CLI/MCP 契约、`v3-architecture`、13 个 required check 与 policy composite hash 不变；`mcp/LayerGuard` 仍不在范围内。
- 来源：CP07b 设计评审，用户于 2026-09-18 批准 A1、B1、C1 及其限定条件；记录 `20260918-v3-stage-d27-architecture-conformance-binding-separation.json`。

### D28 — CI 成本控制与 base 判定的变更范围（§10.3 补充，细化 D10、D19）

- **决定**：workflow 增加只降低成本、不改变 gate 证明内容的控制项，由 `ci/jobs.json` 声明、由只读 CI contract verifier 强制：按 PR 取消被替代的运行、在重型 job 中缓存已评审 NuGet 包（key 由已评审 lock 派生）、再验证 schedule 由每周改为每月。base 另外用 `trusted-base/Get-IFXChangeScope.ps1` 判定 verified changed set：带明确 head 时，`records-and-plans` 表示 merge base 到该 head 之间每个路径都是 formal plan、authorization record 或 decision record；空变更集、无法识别路径与任何失败都是 `full`。判定为 `records-and-plans` 时，workflow 跳过 `v3-architecture` 与两条 `v3-cross-platform` leg 的 head candidate 步骤，runner 让 `v3-architecture`、三个 quality 与 `v3-specialized-database` 以 `guardrails: skipped` 继承 base 判定；`v3-pre-diff`、Validate、Pre、HistoricalIntegrity 与 G03/G04/G05/Plan04 始终运行。13 个 required check 名称、job DAG、trigger 语义、ruleset 与 strict 策略不变，也没有任何 job 变为条件执行。
- 来源：2026-09-17 度量单次 PR 运行 73–75 计费分钟（Windows leg 30、`v3-architecture` 13、Ubuntu leg 10、`v3-quality-solution` 6、`v3-specialized-database` 5），配额 2700/3000 不足以完成剩余约 19–23 次运行；用户于 2026-09-18 要求先做 CI 优化再继续 Plan 06；记录 `20260918-v3-stage-d28-ci-cost-controls-and-change-scope.json`。

> 2026-09-21 补充：D28 关于“Windows leg 不裁剪”的结论由 D35 局部取代；D28 的 concurrency、cache、monthly schedule、base-owned change scope 与 fail-closed 约束继续有效。历史 decision JSON 保持不可变，由新的 D35 decision 记录取代范围。

### D35 — Windows portability smoke 与 P11.4 全量认证（§10.3、P11.4 补充，局部取代 D28）

- **决定**：保留 `v3-cross-platform-windows-latest` required check、13 个 required check 名称、job DAG、事件集合、ruleset contexts 与 strict 策略。普通 PR/push/schedule 在 Ubuntu leg 执行完整 head candidate suite，Windows leg 仍执行 base-owned `Validate`，其 head candidate 部分改为已声明的 portability smoke：V3/IFX Generate 与 Check、锁定构建基线、target-root/path 隔离。平台中立的 Pre、authority projection、specialized contracts、historical integrity、domain authority candidates 与 trusted-base 全量候选测试不再在每个 Windows 普通运行重复，但仍在 Ubuntu 完整执行。P11.4 最终候选必须额外以 `workflow_dispatch`、`windowsCoverage=full` 运行一次 Windows 完整 suite 并保存证据；CI contract 对 smoke/full 命令集合、OS 选择、dispatch 输入和 required check 身份失败关闭。`records-and-plans` 优化和任何 job 级条件均不改变。
- **边界**：这是经明确授权的重复证据削减，不宣称 Windows smoke 与全量 suite 等价；若 smoke 命令、Windows required check、Ubuntu full suite 或 P11.4 全量入口被移除，CI contract 必须失败。仓库公开期间标准 runner 不计 Actions minutes，但本约束仍保留，以便仓库回到 private 后控制成本。
- 来源：2026-09-21 对最近真实运行复核：Windows leg 15.70 分钟，其中 head candidate 14.17 分钟；本地把 trusted-base 差异消费测试加入 smoke 的试跑超过 3 分钟仍未结束，故该套件保留在 Ubuntu full/P11.4 Windows full。用户于 2026-09-21 授权 CP12-ci2，并要求更新 D28、Plan 06 与 CI 信任契约；记录 `20260921-v3-stage-d35-windows-portability-smoke.json`。

### D29 — Architecture Conformance engine 迁入 V3 的路径、命名与测试桥（P6.4 补充，细化 D12、D27）

- **决定**：P6.4–P6.6 以 CP07c-prep 与 CP07c 交付。通用 engine 的最终位置是 `docs/guards/V3/stages/post/gates/architecture/dotnet/`，项目与 assembly 名为 `Guards.ArchitectureConformance`；C# namespace 仍为 `LayerGuard`，作为内部兼容面而非稳定门禁身份，使 base-owned engine 测试跨迁移仍可编译。CP07c-prep 为 expand：在 engine 源码仍位于 V3_ifx 时建立 V3 项目与测试路径，V3 engine 项目本检查点内转发到 V3_ifx engine；通用测试与 fixture 迁入 V3 并只引用 V3 项目；V3_ifx 旧测试项目保留为已声明的空项目，因为本 prep 的候选验证会把上一 base 的 engine 测试恢复到该路径并必须仍能编译运行；base-owned 归属改为 V3 路径，使 CP07c 的候选验证恢复的测试可编译到迁移后的 engine。IFX policy binding 测试改用本包自有的最小 IFX fixture。CP07c 再迁移 engine 源码、删除 V3_ifx engine 与空测试项目、把 IFX binding 与 host 指向 V3 项目，并写入 §11.3 混合型 trust contract 与 P6.6 的不变性证明。
- 来源：CP07c 设计评审，用户于 2026-09-18 批准 A1（V3 stage 路径）、B1（项目/assembly 改名、namespace 作为内部兼容面）、C1（IFX 专属 fixture），并要求先证明 expand/contract 桥；记录 `20260918-v3-stage-d29-architecture-conformance-v3-relocation.json`。

### D30 — Stage Gate 仓库外生成与 V3 overlay expand/contract 切换（P7 补充，细化 D1、D3、D6、D9、D14）

- **决定**：P7 以 CP08-prep0、CP08-prep 与 CP08 交付。CP08-prep0 先修正 base-owned manifest/tools 测试：workflow 未登记脚本负向控制使用真正缺失的路径，public runner 不再要求与 canonical 实现 byte parity，analysis reproducibility 改为隔离目录连续两次生成比较且不覆盖 tracked snapshot。CP08-prep 再让 IFX orchestrator、command manifest、trusted-base 调用链与 base-owned ownership 使用 canonical V3，把 workflow-facing legacy runner 收敛为薄 wrapper，并将 generation root 显式传到底层。CP08 参数化 `{ProjectId}.Guards.StageGate.Tests`，在 `<generation-root>/<package>/gates/stage/` 下生成 Self/Post/Diff，拒绝 identifier 碰撞，取消跟踪 snapshot 并删除无兼容职责的内部副本；声明期内的 public legacy path 保留薄 wrapper。三个检查点各自使用 exact-candidate authorization → change pair；required check 名称、ruleset 与 O1 保持不变。
- 来源：P7 实施时的 base-owned overlay 失败报告与生成路径审计；旧测试会覆盖 candidate 的新版测试并拒绝预期 wrapper，tracked inventory byte 比较受 Windows checkout 换行影响，直接删除重复测试又会被 base overlay 恢复，因此必须 test-bridge → expand → contract；记录 `20260919-v3-stage-d30-stage-gate-cutover.json`。

## 18. 暂缓项

以下事项已识别，但**明确暂不做出任何改变决定**。本计划的门禁审查目标仅限项目本身的代码与架构层面，git 端审查标准保持现状。暂缓项不阻塞本计划的 Review、批准或实施；若未来要处理，必须另行立项并取得独立授权。

### O1 — Workflow 定义与 git 端审批设置（暂缓，不做决定）

**事实记录**（r2 只读核实 ruleset `23459908`，作用于默认分支与 `codex/guards-principles-plan`）：

- GitHub `pull_request` 事件使用 PR merge ref 中的 workflow 定义。PR 可以修改 `.github/workflows/v3-ifx-guardrails.yml`，在保持 job 名称不变的前提下跳过 §11.1 的 base 执行。
- `.github/CODEOWNERS` 将 `/.github/workflows/` 与 `/docs/guards/` 指派给 code owner，但 ruleset 为 `require_code_owner_review = false`、`required_approving_review_count = 0`，这些修改不需要审批即可合入。
- 因此 §11 不覆盖 workflow 定义本身；§12 的 base 预授权能防止同一 PR 自我授权，但不能防止"先合入授权、再合入变更"的两步操作。

**当前处理**：

- 不修改 ruleset，不收紧 git 端审查标准，不为此增加实施阶段或验收标准。
- §11.4 与 §12.5 明确声明信任边界的实际保证范围，避免对外宣称超出范围的保护。
- 该事实记录仅供未来参考；不要求在 Review 中选择任何候选方案。

## 19. 正式执行前置条件

在用户明确要求开始执行前，必须完成：

1. 本 r4 修订经针对性核对，状态从 `DRAFT` 改为 `APPROVED`。
2. 正式执行准备阶段首次创建 D1–D15 对应的 decision JSON/ADR，并纳入正式 Plan 的 `decisionPaths`；P1.1 只负责校验与补充。
3. 基于最终路径建立匹配的 `YYYYMMDD-*.md` 与 `YYYYMMDD-*.plan.json` 正式 Plan pair，并给出 PR 检查点划分。
4. 正式 sidecar 列出精确 planned paths、area IDs、rule IDs、commands 和 decisions。
5. 运行 Pre 并确认所有 risk、area、rule 和 command 关联完整。
6. 记录 clean baseline、恢复 commit 和测试证据位置。
7. 再次获得明确的实施授权。

在上述条件满足前，本计划只允许继续评审和补充，不得据此执行目录移动、生成物切换、CI 激活或删除。

## 20. 本计划完成后的下一步改进：V3 原生替换 LayerGuard 派生实现

本节只登记后续方向，不属于 P0–P11 的实施范围。本计划完成并稳定运行后，再单独讨论、评审并建立正式计划。

### 20.1 目标

在 P6 完成后，Architecture Conformance 通用 engine 已位于 V3。后续目标是替换其 LayerGuard 派生的内部实现，由 V3 原生且可移植的检测器覆盖当前完整架构能力，同时保持稳定的 `ArchitectureConformance` 名称、位置、命令接口、输入 policy、summary schema、trust contract 和 CI required-check 身份。

### 20.2 必须保留的能力边界

后续替换至少需要逐项覆盖并证明：

- layer 与 ownership boundary；
- direct/transitive project reference；
- package、import、source 和 declaration placement；
- interface implementation、payload 和 compiled dependency；
- G03/G04/G05 policy binding 与 composite hash；
- strict baseline、zero-match、missing-input 和 stale-input 失败关闭；
- 当前正例、负例、fixture 和报告字段。

### 20.3 后续实施前提

1. 先建立 LayerGuard 派生实现的完整 capability matrix 和 provenance 清单，包括 P0.4 登记的已知覆盖缺口。
2. 为每项能力定义 V3 原生 detector contract、正例、故意违规负例和 coverage 边界。
3. 新旧实现并行运行，结论、失败类别和证据逐项对照。
4. 只有新实现覆盖相同或更强、跨平台稳定并通过真实 PR 负向控制后，才允许切换生产入口。
5. policy/baseline/report 迁移必须有独立 decision、回退清单和恢复演练。
6. 删除 LayerGuard 派生源码必须是后续计划的最后阶段，并通过 §12 授权执行。

### 20.4 与本计划的关系

本计划通过稳定 `ArchitectureConformance` 能力名称、位置、JSON 输入、报告契约、trust contract 和 CI 接口，为未来替换内部实现建立隔离层。本次完成去重、IFX binding 剥离和所有权迁移，是为了清晰化当前事实和降低维护成本，不是宣告最终实现已经完成。
