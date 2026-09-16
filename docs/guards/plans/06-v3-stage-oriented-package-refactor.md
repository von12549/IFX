# V3 Stage 化、自包含配置与门禁工程重构计划

> 状态：**DRAFT / 已整合 Review 第一至九章 / 待重新 Review / 禁止执行**。
>
> 本文综合 V3、V3_backup、V3_ifx 对比 Review，以及 [06-v3-stage-oriented-package-refactor.review.md](06-v3-stage-oriented-package-refactor.review.md) 第一至九章的共识形成。当前不移动目录、不改名、不生成或安装 workflow、不改变 required checks、不删除任何现有文件。只有本文重新 Review 通过、状态被人工改为 `APPROVED`、正式 Markdown/JSON Plan pair 建立并再次获得明确执行授权后，才允许开始 P0。

## 0. 修订记录

| 版本 | 来源 | 主要变化 |
| --- | --- | --- |
| r1 | commit `ad3e67d` | 初版：目标、原则、P0–P9、D1–D8 |
| r2 | Review §1–§9 | 按最终答复修正 D1/D2/D4；新增门禁信任模型（§11）与受保护路径迁移授权（§12）；通用 Diff 加固先合回 V3；Architecture Conformance engine 与 IFX binding 分离后进入 V3；Stage Gate 参数化命名并移出 Git；workflow 改为轻量模板；元数据与聚合文档精简；构建输出重定向不得丢失根 MSBuild 安全配置；执行顺序重排为 P0–P11；新增 D9–D12；登记暂缓项 O1（git 端审查设置，本计划不做决定） |

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
9. CI 从 PR head 的 checkout 生成并执行门禁；PR 可以同时修改检测器、保护路径和被检查内容，门禁可被 PR 自身削弱。`.github/CODEOWNERS` 虽然指派了 owner，但 ruleset `23459908` 当前 `require_code_owner_review = false`、`required_approving_review_count = 0`，CODEOWNERS 审查并不被强制（r2 只读核实）。

现状规模（r2 核对）：V3 41 个 tracked 文件；V3_ifx 537 个 tracked 文件，其中 348 个为 LayerGuard template/generated 双份；PowerShell 实现合计约 1.8k 行；workflow 285 行，13 个 required checks。本计划新增的治理元数据必须与该规模相称。

## 2. 目标

### 2.1 配置与激活

- V3 所需的全部机器配置、模板、生成声明和部署映射都位于 V3 包自身目录。
- IFX 专用配置全部位于 V3_ifx 自身目录，不以 `.github/`、根脚本或其他历史目录作为隐藏配置权威。
- GitHub workflow、CODEOWNERS managed block 及其他必须复制到目标位置的文件，先在 V3 内由轻量模板确定性生成和验证，再由人工显式确认安装或复制。
- 候选文件是可再生产物；目标位置文件只是激活副本。二者必须能够反向验证。

### 2.2 Stage 信息架构

- 从目录、文件名、manifest 和文档中能够直接识别 Bootstrap、Analysis、Pre、Post、Diff、CI 以及 Shared/Governance 的职责。
- 配置以主要消费 Stage 归类；跨 Stage 输入只保留一个 `shared/` 权威，不在多个 Stage 复制。
- 每个 Stage 都声明命令、依赖、enforcement、证据路径和文档；每个字段只有一个 manifest owner。

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
- `bin/`、`obj/`、报告和运行日志全部移出 `docs/guards` 源码树，且不得丢失根 `Directory.Build.props` 的 NuGet 安全审计配置。

### 2.5 JSON 与 Markdown

- JSON 继续是唯一机器语义权威。
- 全部生成 Markdown 只读，不支持 Markdown → JSON Import。
- 生成文档列出来源路径和角色，并附一个 composite hash；不逐源列 hash。
- 生成 Markdown 与人工 Markdown 分离；生成器不得覆盖人工设计理由。
- 首批只生成 `OVERVIEW.md`、`COMMANDS.md`、`POST.md`、`CI.md`，出现真实阅读需求后再拆分。

### 2.6 门禁信任与迁移安全

- PR 门禁使用受信任 base 中的 engine、contracts、protection config、policy 和 migration authorization，对 head/merge checkout 做检查（§11）。
- 受保护路径的删除和移动只能消费 base 中预先合入的精确授权，并在同一 diff 中删除该授权（§12）。
- 13 个 required check 名称是本计划全程不变量（§10.3）。
- 通用 V3 能从空白 fixture 仓库 Bootstrap 出可运行的门禁。

## 3. 非目标

- 本计划不改变 IFX 当前业务架构规则的语义。
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

1. **JSON authority**：Stage 配置、规则、policy、toolchain、activation、command、required checks 和 document manifest。
2. **Implementation**：PowerShell/.NET/其他语言实现与模板；实现解释 JSON，不暗藏项目 policy。
3. **Generated candidate**：Markdown、Stage Gate 源码、GitHub workflow、CODEOWNERS managed block 等可再生产物。
4. **Activated copy**：目标 `.github/` 等宿主读取位置中的副本。
5. **Runtime evidence**：`artifacts/guards/` 下的报告、TRX、日志、hash 和 summary。

低层不得反向成为高层的隐含权威。激活副本不得直接编辑；运行证据不得被当成当前配置。

对 PR 做判定时，第 1、2 层以及 migration authorization 一律取自受信任 base，而不是 PR head（§11）。

## 5. 建议目标结构

以下是方向性结构。最终路径在正式执行 Plan 中冻结。

```text
docs/guards/V3/
├─ guard-system.json
├─ shared/
│  ├─ contracts/
│  ├─ toolchain.json
│  ├─ commands.json
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
│  │  └─ migration-authorization.schema.json
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
│  └─ support/
└─ examples/

docs/guards/V3_ifx/
├─ guard-system.json
├─ shared/
├─ stages/
│  ├─ analysis/
│  │  ├─ evidence/
│  │  ├─ drafts/
│  │  └─ reports/
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

artifacts/                       # 不进入 Git
├─ build/<package>/              # bin/obj
├─ generated/<package>/          # Stage Gate 源码、workflow candidate
└─ guards/<package>/<stage>/     # TRX、JSON report、logs、summary
```

- V3 是唯一 portable engine。V3_ifx 作为 IFX overlay 直接引用仓库内 V3 的公共 engine/contracts，不复制、不 fork 通用实现。
- 新仓库使用 V3 源码包 Bootstrap 生成自己的门禁，而不是复制 V3_ifx。
- 生成产物不再位于 package 内 `generated/`，统一写入 `artifacts/generated/<package>/`；激活副本只存在于目标位置（例如 `.github/`）。

## 6. Stage 职责

| Stage | 主要职责 | 典型输入 | 典型输出 |
| --- | --- | --- | --- |
| Bootstrap | 初始化包、建立未评审配置和安装前准备 | project ID、目标根、SDK | 初始 JSON、目录、可运行门禁骨架、状态报告 |
| Analysis | 只读发现目标事实并形成可评审提案 | repository、当前 profile | inventory、drafts、review report |
| Pre | 路径、area、owner、risk、rule 和 command 关联 | proposed paths 或 formal Plan | advisory/blocked summary |
| Post | 源码、项目引用、程序集、policy、专项和质量检测 | target tree、compiled outputs、policy | detector reports、summary |
| Diff | 最终 changed set 与正式 Plan、受保护路径和迁移授权对账 | trusted base、head、Plan、protection、authorizations | scope pass/fail |
| CI | 编排 Stage、生成激活候选、验证 required checks | Stage manifests、workflow template、required checks | workflow candidate、activation report |
| Shared/Governance | 跨 Stage 工具链、authority、decision、schema | reviewed JSON | 被多个 Stage 引用，不独立执行 |

每个 Stage 新增 `stage.json`。字段 owner 划分如下，禁止两处同时拥有同一字段：

| 字段 | owner | 另一方 |
| --- | --- | --- |
| `entryPoint`、`inputs`、`outputs`、`evidence`、`mutability`、`requiresExplicitAcceptance`、`platforms`、`stability` | `shared/commands.json` | `stage.json` 只引用 command ID |
| `id`、`commands`（command ID 列表）、`dependencies`、`enforcement`、`executionClass`、`documentation` | `stage.json` | `commands.json` 只引用 stage ID |

## 7. 脚本和可执行文件分类

### 7.1 公共命令 `commands/`

供 human、Agent 或 CI 直接调用的稳定 API。只暴露少量入口：

- `Invoke-V3.ps1`：Validate、Pre、Post、Diff、All。
- `Invoke-V3Setup.ps1`：Bootstrap、Analysis。
- `Invoke-V3Docs.ps1`：Render、Check；按 D4 移除现有 `Import` 模式。
- `Invoke-V3Deployment.ps1`：Generate、Check、Preview、Install、Verify 激活文件。
- IFX overlay 保留一个薄的 `Invoke-IFXGuardrails.ps1`，只负责选择 IFX package 和 Stage，不重复实现通用逻辑。

### 7.2 内部引擎 `engine/`

- 不承诺外部调用兼容性。
- 公共命令负责参数、帮助、退出码和结构化输出；内部模块负责实现。
- 共享 PowerShell 逻辑优先收敛为不导出内部细节的 `.psm1` 模块。
- `engine/trusted-base/` 负责 base worktree 建立、base 资产加载和 head 隔离（§11）。

### 7.3 生成器 `generators/`

- JSON → 只读 Markdown。
- Stage JSON/profile → .NET Stage Gate。
- workflow template + variables → workflow candidate。
- activation manifest → 目标文件候选或 managed block。
- Generate 只写 `artifacts/generated/`；Install 必须是独立显式操作。

### 7.4 Integrations、Maintenance 与 Test Support

- `integrations/`：GitHub、Agent hook、Skill 等宿主胶水，只调用公共命令。
- `maintenance/`：policy projection、history manifest、迁移和 hash 更新；写 authority 时必须要求 `Preview`/`Apply` 或等价显式语义。
- `tests/support/`：只服务 fixture、负例和临时仓库，不作为用户入口。

### 7.5 Command manifest

新增机器权威 `shared/commands.json`，为每个公共入口记录 §6 表中由它拥有的字段，以及 `id`、`kind`、`stages`、`audiences`。

CI 模板检查器和 `docs/generated/COMMANDS.md` 都从该 manifest 读取，不再手工维护命令清单；workflow 只允许调用 `kind = public` 的命令。

## 8. .NET 门禁工程分类和命名

### 8.1 Stage Gate

当前 profile 驱动的 Self/Post/Diff xUnit 工程改为职责名称，项目名由 profile project ID 参数化：

```text
artifacts/generated/<package>/gates/stage/
└─ {ProjectId}.Guards.StageGate.Tests/
   ├─ Self/
   ├─ Post/
   ├─ Diff/
   ├─ GeneratedInputs/
   └─ {ProjectId}.Guards.StageGate.Tests.csproj
```

- `Self` 证明检测器能接受正例并拒绝故意违规 fixture。
- `Post` 扫描项目引用和编译程序集。
- `Diff` 验证实际 changed set、Plan、受保护路径和迁移授权。
- 保留一个 csproj 以降低 restore/build 成本，通过目录、类名和 test trait 区分类别。
- `ArchUnitNET` 仅作为 package 依赖和实现说明，不进入稳定工程名称。
- 通用生成器定义 project ID 到合法 .NET identifier/namespace 的确定性转换（大小写、分隔符、数字开头、保留字），并在转换结果碰撞时失败关闭。
- 生成源码不进入 Git（D3）。

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

### 8.3 构建与运行输出

- 所有 `bin/obj` 定向到 `artifacts/build/<package>/`。
- TRX、JSON report 和 logs 定向到 `artifacts/guards/<package>/<stage>/`。
- 生成源码和 workflow candidate 定向到 `artifacts/generated/<package>/`。
- MSBuild 默认只自动加载距离项目最近的一份 `Directory.Build.props`。根 `Directory.Build.props` 当前包含 `NuGetAudit`、`NuGetAuditMode`、`NuGetAuditLevel` 和 `NU1903;NU1904` warnings-as-errors；输出重定向方案不得让 `docs` 下项目静默丢失这些配置。候选方案在 P5.1 比较并冻结：
  - **方案 A**：新增 `docs/Directory.Build.props`，显式 import 根 props 后设置 `ArtifactsPath`；
  - **方案 B**：不新增嵌套 props，由 V3 公共命令统一传入 `--artifacts-path` 或等价 MSBuild 输出属性。
- 无论采用哪种方案，都必须验证：
  - `Test-V3.ps1` synthetic fixture；
  - `docs/Directory.Packages.props` 与 Central Package Management 隔离；
  - Stage Gate Generate/Check/Test/Diff；
  - Architecture Conformance Gate build/test/scan；
  - Linux/Windows 路径一致性；
  - 并发 project/TFM 不共享同一 intermediate output；
  - clean 后 `docs/guards/**` 下不再生成 `bin/obj`；
  - 根 NuGet audit 和安全 warning 配置仍然生效。

## 9. Markdown 文档模型

### 9.1 文档分类

- `docs/authored/`：人工维护的架构理由、迁移说明、操作指导和决策背景。
- `docs/generated/`：从一个或多个 JSON 聚合生成，只读，禁止直接编辑。

首批生成：

- `OVERVIEW.md`：Stage 全景、入口、输入输出和 authority/candidate/activation/evidence 关系。
- `COMMANDS.md`：公共命令、执行者、副作用、输入输出和示例。
- `POST.md`：rules、detectors、coverage、Architecture Conformance 和专项/质量 gate。
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
- `Check` 验证 YAML 可解析、job DAG、只调用公共命令 ID、Stage 依赖、matrix 展开后的 check 名称与 `required-checks.json` 一致，以及生成漂移。
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
Base worktree（$RUNNER_TEMP/guard-base，位于 head checkout 之外）
├─ trusted V3 engine 与 contracts
├─ trusted Diff/protection config 与 policy
├─ trusted migration authorizations
└─ trusted activation contract

Head/merge checkout
└─ 被检查的 target files 与 changed set
```

实现必须满足：

- base SHA 来自可信 PR event，并验证 commit 可解析；
- engine、contracts、protection config、policy 和 migration authorization 从 base worktree 加载；
- head/merge worktree 仅作为 target repository 和 changed set；
- base engine 不从 head dot-source PowerShell、加载 module、执行脚本或读取可执行配置；
- base worktree 必须创建在 head checkout 之外。`Directory.Build.props`、`Directory.Build.targets`、`Directory.Packages.props`、`NuGet.config` 和 `global.json` 会从项目目录逐级向父目录查找；若 base worktree 位于 head 内部，base engine 构建时会加载 head 控制的这些文件，绕过信任边界；
- base engine 的 restore/build 显式指定 base 中的 `NuGet.config` 和 SDK 版本，不依赖向上搜索；
- 不使用 `pull_request_target` 执行不可信 PR 代码。

负向控制至少包括：PR 修改受保护路径清单、修改 engine 脚本、修改 policy、在 head 根 `Directory.Build.props` 注入失败或篡改逻辑，均不得改变 base engine 的判定。

### 11.2 首次引入例外

引入 Trusted Base Guard Execution 的 PR 在 base 中尚无该机制，只能由现有 CI 和专门负向控制兜底；ruleset 当前不强制 code owner review，该残余风险按 §18 O1 暂缓处理。该一次性例外必须写入 decision 记录，并在该 PR 合入后的下一个 PR 上验证机制生效。

### 11.3 Break-glass

base engine 自身误报时，修复 PR 会被旧 engine 阻断。break-glass 只能是仓库外部治理的最后手段（例如管理员临时调整 ruleset），不能实现为仓库内可自行调用的 bypass。至少记录：

- 授权人和复核人；
- 原因和受影响 check；
- 开始与恢复时间；
- 临时 ruleset 变化；
- 恢复后的配置证明；
- 事后正常/负向复验结果。

### 11.4 保证范围

workflow 定义本身以及 git 端审批设置不在 §11 的信任边界内，按 §18 O1 暂缓。§11 的保证范围仅限：在 workflow 未被修改的前提下，PR head 无法通过修改 engine、配置、policy、授权或 MSBuild 继承文件改变门禁判定。对外描述门禁能力时不得超出该范围。

## 12. 受保护路径迁移授权

### 12.1 两 PR 协议

1. **授权 PR**：将精确 migration authorization 写入 base（`V3_ifx/stages/diff/authorizations/`），不执行任何移动或删除。
2. **迁移 PR**：只能消费 base 中已存在的授权，完成精确移动或删除，并在同一 diff 中删除所消费的授权。

授权从 base 被合并删除后自然失效，不依赖 wall-clock 有效期或无状态的"已使用"标记。

### 12.2 授权内容

每条 authorization 至少包含：

- 唯一 authorization ID；
- source path；
- destination path（删除操作为空）；
- operation（move、delete）；
- source tree/content hash；
- 是否允许内容变化及允许范围；
- 对应 formal Plan 和 decision。

### 12.3 机械验证

迁移门禁必须验证：

- 授权存在于 base，而不是仅存在于 head；
- head 删除了所消费的授权；
- source、destination 和 operation 与授权完全匹配；
- source hash 匹配；
- 未授权的额外删除或重命名为零；
- ruleset `strict` up-to-date 生效，并发 PR 更新分支后因 base 中授权已被删除而失败，避免重复消费。

## 13. 现有目录到目标职责的初步映射

| 当前目录 | 初步目标 |
| --- | --- |
| `architecture/` | `docs/authored/architecture/`，目标提案移入 Analysis drafts |
| `analysis/ifx/` | `stages/analysis/{evidence,drafts,reports,migration}/` |
| `ci/jobs.json` | 由 `stages/ci/required-checks.json` 取代 |
| `contracts/` | `shared/contracts/` 或特定 Stage contracts |
| `decisions/` | `shared/decisions/` |
| `examples/` | `examples/` 或 `tests/fixtures/`，按是否面向用户区分 |
| `generated/stages/` | 取消跟踪；输出到 `artifacts/generated/<package>/gates/stage/` |
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
| `docs/guards/V3_backup/` | 删除（D2） |

## 14. 实施阶段

以下阶段全部处于未开始状态。PR 以"可独立验证和回退的迁移检查点"为单位拆分，不机械拆成大量微型 PR；每个 PR 都需要 formal Plan pair，涉及受保护路径删除或移动时还需要 §12 的授权 PR，拆分策略必须计入该治理成本。

### P0 — 基线冻结与完整分类（只读）

- [ ] P0.1 记录 V3、V3_backup、V3_ifx、`mcp/LayerGuard/` 和 `.github/` 激活文件的 tracked 文件、hash、引用、生成关系和当前 Validate/Check/Test 结果。
- [ ] P0.2 为每个文件标注 authority/implementation/generated/activation/evidence、Stage、owner 和保留/迁移/删除结论。
- [ ] P0.3 建立全部 PowerShell 及其他 executable 的调用图，区分公共入口和内部调用。
- [ ] P0.4 冻结两个 .NET gate 的源码、fixture、项目、package、测试类别和执行路径；列出 LayerGuard 中全部 IFX-specific binding（大小写不敏感扫描）。
- [ ] P0.5 登记已知漂移为迁移前缺陷：Markdown views、architecture review、DEPLOYMENT、文件计数、无效 `SourceConfig`、未受校验的 `ci/jobs.json`，以及 `ci/jobs.json` 中 `v3-historical-integrity` 声明的 `history-change-schedule-manual` 触发与 workflow 实际每次运行不一致（待核实）。
- [ ] P0.6 列出 V3 与 V3_ifx 的逐字节相同文件和已分叉文件，并把每处分叉归类为"通用加固"或"IFX-specific"。
- [ ] P0.7 只读记录 13 个 required checks 与 ruleset `23459908` 的当前远端状态。
- [ ] P0.8 盘点影响 `docs/guards` 下项目的 MSBuild/NuGet 继承配置：根 `Directory.Build.props`、`docs/Directory.Packages.props`、NuGet config 和 `global.json`。
- **门槛**：每个现有文件和命令都有唯一分类；未分类项不得进入后续阶段。

### P1 — 决策记录与已知漂移修复

- [ ] P1.1 为 D1–D12 建立 decision JSON/ADR。
- [ ] P1.2 修复 P0.5 登记的漂移。
- [ ] P1.3 建立只读 verifier：workflow job 名称 ↔ `ci/jobs.json` ↔ 远端 ruleset（含 `strict`），并有正反 fixture。
- [ ] P1.4 为旧目录和旧命令定义兼容期、deprecation 输出和删除条件。
- **门槛**：已知漂移清零并由 CI 阻止复发；required check 名称未变。

### P2 — Trusted Base Guard Execution

- [ ] P2.1 实现 §11.1：base worktree 位于 head 之外，base SHA 验证，base 资产加载，head 仅作为 target。
- [ ] P2.2 restore/build 显式使用 base 的 `NuGet.config` 与 SDK，不向 head 目录向上搜索。
- [ ] P2.3 完成 §11.1 列出的负向控制。
- [ ] P2.4 记录 §11.2 首次引入例外，并在下一个 PR 上验证机制生效。
- [ ] P2.5 在 `docs/authored/` 记录 §11.3 break-glass 外部治理流程和 §11.4 保证范围。
- **门槛**：在 §11.4 保证范围内，PR head 修改 engine、保护配置、policy 或 MSBuild 继承文件均无法改变判定。

### P3 — 通用 Diff 加固合回 V3

- [ ] P3.1 将 merge-base 校验和 empty-diff fail-closed 合回 V3 模板。
- [ ] P3.2 将受保护路径从通用 C# 模板参数化到 Diff 配置（V3_ifx `stages/diff/protection.json` 或等价旧路径位置），并由 trusted base 加载。
- [ ] P3.3 以明确决策统一 `Test-V3.ps1` 的 NuGet 源配置分叉（V3 离线 `NuGet.Offline.Config` 与 V3_ifx nuget.org `NuGet.Test.Config`）。
- [ ] P3.4 在 V3 补齐正反例和 Linux/Windows 测试。
- [ ] P3.5 证明 V3 Diff 与 V3_ifx 当前 Diff 等价或更强；此阶段不删除 V3_ifx 副本（见 P7.5）。
- **门槛**：V3 具备 V3_ifx 全部通用加固，通用模板中不含 IFX 路径。

### P4 — Base 预授权受保护迁移机制

- [ ] P4.1 定义并 schema 化 §12.2 授权格式。
- [ ] P4.2 在 Diff 中实现 §12.3 机械验证，授权从 trusted base 加载。
- [ ] P4.3 负向控制：仅 head 存在的授权、hash 不匹配、额外删除/重命名、未删除已消费授权、并发 PR 重复消费。
- [ ] P4.4 verifier 断言 ruleset `strict` 保持启用。
- [ ] P4.5 在临时仓库或 fixture 中完成一次完整两 PR 演练。
- **门槛**：受保护路径的删除和移动只能通过 base 预授权完成，且授权只能使用一次。

### P5 — 构建输出移出源码树（可与 P1–P4 并行）

本阶段不涉及受保护路径删除或移动，不依赖 P2–P4，可提前执行。

- [ ] P5.1 比较 §8.3 方案 A 与方案 B 并冻结选择。
- [ ] P5.2 实现 `bin/obj` → `artifacts/build/<package>/`，报告 → `artifacts/guards/<package>/<stage>/`。
- [ ] P5.3 完成 §8.3 全部验证项。
- [ ] P5.4 增加测试断言 clean 运行后 `docs/guards/**` 下无 `bin/obj`。
- **门槛**：源码树无构建输出，根 NuGet 安全审计仍然生效。

### P6 — LayerGuard 去重与 generic engine / IFX binding 分离

- [ ] P6.1 通过 §12 授权删除 `generated/dotnet/LayerGuard`，改为直接构建运行唯一源码；验证 build/test、policy binding、strict scan、正反 fixture、CI 调用路径和恢复。
- [ ] P6.2 参数化 runtime role 和 IFX project/type names，移入 IFX policy/fixtures；通用测试改用 synthetic fixture。
- [ ] P6.3 分离通用检测引擎与 IFX policy binding。
- [ ] P6.4 通用 engine 迁入 V3 `Guards.ArchitectureConformance*`；V3_ifx 只保留 policy、baseline、binding 和 IFX fixtures。
- [ ] P6.5 证明 policy composite hash、report 字段、失败类别和 `v3-architecture` check 名称不变。
- **门槛**：174 文件重复消除；V3 engine 大小写不敏感扫描无 IFX 标识；Architecture Conformance Gate 无需复制即可运行。

### P7 — Stage Gate 命名、输出与 overlay 切换

- [ ] P7.1 生成 `{ProjectId}.Guards.StageGate.Tests`，实现 identifier 转换与碰撞检查，内部划分 Self/Post/Diff。
- [ ] P7.2 通过授权从 Git 移除 `generated/stages`；Generate 输出迁入 `artifacts/generated/<package>/gates/stage/`。
- [ ] P7.3 同步更新 workflow、`Invoke-IFXGuardrails -Mode Diff`、`.gitignore` 和 Check 逻辑；profile snapshot 不再以 tracked generated copy 存在。
- [ ] P7.4 clean checkout 证明没有预生成源码也能完成 Generate/Check/Test/Diff。
- [ ] P7.5 V3_ifx 切换为直接引用 V3 engine，通过授权删除与 V3 逐字节相同的 scripts、hooks 和 tests。
- **门槛**：Stage Gate 可从 JSON 和模板确定性重建；V3_ifx 不含通用实现副本。

### P8 — 最小 manifests 与首批只读聚合文档

- [ ] P8.1 定义并 schema 化 `guard-system.json`、`stage.json`、`commands.json`、`docs-map.json`，按 §6 字段 owner 表校验无重复字段。
- [ ] P8.2 建立 `commands/` 稳定入口；旧公共路径保留薄 wrapper。
- [ ] P8.3 确认无消费者后移除 `Invoke-V3Docs` 的 `Import` 模式。
- [ ] P8.4 实现 renderer/checker，生成 `OVERVIEW.md`、`COMMANDS.md`、`POST.md`、`CI.md`，含来源路径、角色和 composite hash。
- [ ] P8.5 将人工背景迁入 `docs/authored/`，确保 Render 不覆盖。
- [ ] P8.6 决定 `profiles/ifx/views/` 保留为只读生成视图或并入首批文档。
- **门槛**：任意 authority 变化都会导致相关 Markdown Check 失败；无陈旧生成视图。

### P9 — 轻量 workflow candidate 与激活验证

- [ ] P9.1 建立 V3 通用 renderer 与 V3_ifx `workflow.template.yml`、`workflow.variables.json`、`required-checks.json`、`activation.json`。
- [ ] P9.2 实现 §10.2 的 Generate/Check，candidate 写入 `artifacts/generated/`。
- [ ] P9.3 实现 Preview、`Install -AcceptDeployment` 和人工复制后的 Verify；激活副本带 source path/hash 头。
- [ ] P9.4 以 `required-checks.json` 取代 `ci/jobs.json`，远端只读 verifier 比较 ruleset；远端写入保持独立授权。
- [ ] P9.5 CODEOWNERS managed block 纳入同一生命周期。
- [ ] P9.6 候选与现有激活 workflow 并行比较，不改变任何 check 名称，不立即切换。
- **门槛**：候选与激活副本之间不存在未解释差异；workflow 只调用公共命令；模板检查器有正反例。

### P10 — 物理目录迁移、V3_backup 删除与兼容入口清理

- [ ] P10.1 将 project map、risks、rules、toolchain、assembly manifest、protected paths、workflow 和 required checks 分配给明确 Stage/Shared authority；旧 profile 格式通过只读兼容加载器或一次性迁移器并行比较，不允许 silent fallback。
- [ ] P10.2 按 §13 映射以检查点分组移动，每组使用授权 PR + 迁移 PR。
- [ ] P10.3 将内部实现迁入 `engine/`，生成逻辑迁入 `generators/`，hooks/skills/GitHub glue 迁入 `integrations/`，policy sync、history regeneration 和迁移工具迁入 `maintenance/` 并补齐 Preview/Apply；按 Stage 重组测试，不改变覆盖。
- [ ] P10.4 每组移动后更新 manifest、链接、脚本、tests 和 docs，并运行完整 Check。
- [ ] P10.5 通过授权删除 V3_backup（D2）。
- [ ] P10.6 旧公共路径保留明确 deprecation wrapper；内部路径不提供永久兼容。
- [ ] P10.7 验证仓库引用扫描无悬空路径，无隐含外部配置权威。
- **门槛**：新结构可在 Linux/Windows clean checkout 重现，旧兼容入口只剩批准范围。

### P11 — 并行验证、切换、清理与回退证明

- [ ] P11.1 对 Analysis、Pre、Post、Diff、CI、专项、质量、历史完整性运行新旧正常与负向 parity。
- [ ] P11.2 验证目录移动、生成物缺失、hash drift、policy drift、protected deletion、未授权移动、授权重复消费、head 篡改 engine/配置、浅克隆、空 diff 和未知 command 均失败关闭。
- [ ] P11.3 从 V3 在空白 fixture 仓库执行 Bootstrap，得到可运行的 Pre/Post/Diff 与 Architecture Conformance 门禁。
- [ ] P11.4 通过真实 PR 验证候选 workflow 和 required checks 后，单独取得激活授权。
- [ ] P11.5 只有在激活与回退验证完成后，删除旧 wrappers、重复目录和失效文档。
- [ ] P11.6 保存精确删除清单、恢复 commit 和 selective restore 演练记录。
- **门槛**：新结构是唯一生产路径，旧路径零运行时引用，全部 blocking 能力有可审查正反证据。

## 15. 验收标准

全部满足后才可标记完成：

1. V3/V3_ifx 所需机器配置均在各自 package 内，外部仅有激活副本、构建输出和运行证据。
2. Analysis、Pre、Post、Diff、CI 的命令、依赖和证据可由目录和 manifest 直接识别；`stage.json` 与 `commands.json` 无重复字段 owner。
3. 通用 V3 engine/template 中不存在 IFX 路径、项目名、runtime role 或 policy 硬编码（大小写不敏感扫描）。
4. 每个公共命令都有 command manifest 分类；workflow 不直接调用 internal/maintenance/test-support。
5. Stage Gate 项目名由 project ID 参数化；Stage Gate 和 Architecture Conformance Gate 名称及职责清晰，不以 ArchUnitNET、LayerGuard 等实现细节作为稳定身份。
6. `templates/ifx-layerguard` 与 `generated/dotnet/LayerGuard` 的 174 文件重复被消除；Architecture Conformance 通用 engine 位于 V3。
7. `docs/guards` 下无 `bin/obj`、生成源码和运行报告；clean 后不会重新写入这些位置；根 NuGet 安全审计仍然生效。
8. 所有生成 Markdown、workflow candidate 和 Stage Gate 都能确定性重建并 Check；生成 Markdown 全部只读。
9. 激活 workflow 带来源/hash，可通过 Verify 证明与 candidate 一致。
10. stage/policy rule 不只校验 ID；coverage binding 能表达 full/subset/advisory 和 authority/hash。
11. 当前 views/review/deployment/jobs 声明漂移已清零，并由 CI 阻止复发。
12. PR 门禁使用 trusted base 的 engine、配置和授权；head 篡改负向控制全部失败关闭（范围见 §11.4）。
13. 受保护路径删除和移动只能通过 base 预授权完成，授权只能消费一次。
14. 13 个 required check 名称与迁移前完全一致。
15. 从 V3 在空白 fixture 仓库 Bootstrap 可得到可运行门禁。
16. V3_ifx 不含 V3 通用实现副本；V3_backup 已删除。
17. 新旧生产能力通过 Linux/Windows、正常/负向、clean checkout 和真实 PR 验证。
18. 迁移有精确回退清单，不修改或丢失历史证据和领域权威。

## 16. 风险与控制

| 风险 | 控制 |
| --- | --- |
| 大规模移动导致引用和 CI 同时失效 | 先 manifest、后分组移动；保留薄 wrapper；每组独立 Check |
| 现有受保护路径检查阻断迁移 | §12 base 预授权两 PR 协议；P4 完成前不执行任何受保护删除或移动 |
| PR 通过修改 engine 或配置削弱自身门禁 | §11 Trusted Base Guard Execution；负向控制；保证范围按 §11.4 明确声明 |
| head 通过 MSBuild/NuGet 向上搜索注入 base engine 构建 | base worktree 位于 head 之外；显式 NuGet.config 与 SDK；注入负向控制 |
| 迁移授权被自我授权或重复消费 | 授权只从 base 加载；消费即删除；ruleset strict up-to-date |
| workflow 定义或授权 PR 无需审批即可合入 | 已知残余风险；按 §18 O1 暂缓，本计划不做改变 |
| break-glass 被滥用为常态 bypass | 仅限仓库外部治理；完整记录与事后复验 |
| 直接切换 V3 canonical engine 造成安全回退 | P3 先合回 V3_ifx 通用加固并证明等价或更强，P7 才切换 |
| Stage 化导致 shared 配置复制 | `shared/` 唯一权威；stage manifest 只引用不复制 |
| 治理元数据过重并自身漂移 | 字段唯一 owner；首批四份文档；workflow 不做 DSL |
| 聚合 Markdown 隐藏来源 | 强制来源路径/角色与 composite hash；CI 逐字节 Check |
| workflow 模板产生有效 YAML 但无效门禁 | 校验 command/stage IDs 与 required checks，运行本地 dispatcher，真实 PR 负向控制 |
| 人工复制后目标文件漂移 | candidate header、activation manifest、Verify 和 required-check verifier |
| LayerGuard 去重或 binding 剥离降低覆盖 | 删除前执行 build/test、scan、fixture 和 policy binding 验证；composite hash 与报告字段不变 |
| 新命名影响 required checks | §10.3 名称不变量；显示名称与内部路径解耦 |
| 构建输出重定向丢失根安全配置 | §8.3 方案比较与验证清单 |
| 生成目录仍累积构建垃圾 | 输出强制定向 `artifacts/`；测试断言 docs 树无 bin/obj |

## 17. 设计决策

D1–D12 已根据 Review 共识关闭。后续若要改变这些决定，必须新增 decision JSON/ADR，并重新评估受影响阶段，不得在实施中静默改变。

### D1 — V3_ifx 的分发边界

- **决定**：仓库内使用 V3 canonical engine + V3_ifx overlay，V3_ifx 直接引用仓库内 V3，不维护通用实现的手工 fork。
- 不要求 V3_ifx 单独复制即可运行；不提供 self-contained distribution，不引入 `core.lock.json`。
- 新仓库使用 V3 源码包 Bootstrap 生成自己的门禁，由验收标准 15 证明。
- 来源：用户答复；Review §1、§6.1。

### D2 — V3_backup 的长期角色

- **决定**：删除 V3_backup，仅保留 V3 源码包；历史恢复依赖 Git history/tag，不保留 release snapshot。
- 删除在 P10.5 通过 §12 授权执行。
- 来源：用户答复；Review §1、§6.1。

### D3 — 是否跟踪生成的 Stage Gate 源码

- **决定**：不跟踪。CI 和本地验证每次从模板、JSON 和 manifest 执行 Generate + Check，输出位于 `artifacts/generated/`。
- Git 只跟踪权威配置、模板、生成器和生成资产 manifest；代码 Review 通过候选 diff、生成报告和确定性检查完成。
- 落实范围见 P7.2–P7.4。
- 来源：用户答复；Review R7、§6.6。

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

- **决定**：先完成基线、决策、信任模型和迁移授权，再按"V3 通用能力 → V3_ifx overlay"迁移，顺序见 §14。
- 禁止分别为 V3 与 V3_ifx 设计两套结构；IFX 需求先判断能否作为通用能力进入 V3，不能通用化的部分才进入 overlay。
- PR 以可独立验证和回退的检查点为单位。
- 来源：用户答复；Review §6.8。

### D8 — 历史完整性的 Stage 归属

- **决定**：目录上属于 `stages/post/gates/historical-integrity`，因为它产生 blocking validation；manifest 的 `executionClass` 标记为 `governance-audit`，允许 schedule/manual 与受影响路径触发策略。
- 触发策略调整必须满足 §10.3：`v3-historical-integrity` 作为 required check 不得在 PR 上永久 pending。
- 来源：用户答复。

### D9 — Trusted Base Guard Execution

- **决定**：PR 门禁的 engine、contracts、protection config、policy 和 migration authorization 取自 base worktree；head 仅作为被检查对象。实现约束、首次引入例外和 break-glass 见 §11。
- 来源：Review R2、§6.3、§7.4、§8.3、§9.2。

### D10 — 受保护路径迁移授权

- **决定**：采用 base 预授权、消费即删除的两 PR 协议，授权内容与机械验证见 §12。
- 来源：Review R1、§6.2、§7.3、§8.2。

### D11 — 轻量 workflow 模板

- **决定**：workflow 在 V3 内生成、验证后再复制，但采用 canonical YAML 模板 + 少量稳定变量，不引入 JSON DSL；`required-checks.json` 保持独立机器权威。见 §10。
- 来源：Review §3、§6.7、§7.2。

### D12 — Architecture Conformance Gate 所有权

- **决定**：LayerGuard 派生的通用检测引擎在剥离 IFX binding 后进入 V3；V3_ifx 只保留 policy、baseline、binding 和 IFX fixtures。§20 的后续替换只替换 V3 中的内部实现，不再移动 Gate 位置或改变稳定身份。
- 来源：Review R4、§6.5、§7.1。

## 18. 暂缓项

以下事项已识别，但**明确暂不做出任何改变决定**。本计划的门禁审查目标仅限项目本身的代码与架构层面，git 端审查标准保持现状。暂缓项不阻塞本计划的 Review、批准或实施；若未来要处理，必须另行立项并取得独立授权。

### O1 — Workflow 定义与 git 端审批设置（暂缓，不做决定）

**事实记录**（r2 只读核实 ruleset `23459908`，作用于默认分支与 `codex/guards-principles-plan`）：

- GitHub `pull_request` 事件使用 PR merge ref 中的 workflow 定义。PR 可以修改 `.github/workflows/v3-ifx-guardrails.yml`，在保持 job 名称不变的前提下跳过 §11.1 的 base 执行。
- `.github/CODEOWNERS` 将 `/.github/workflows/` 与 `/docs/guards/` 指派给 code owner，但 ruleset 为 `require_code_owner_review = false`、`required_approving_review_count = 0`，这些修改不需要审批即可合入。
- 因此 §11 不覆盖 workflow 定义本身；§12 的 base 预授权能防止同一 PR 自我授权，但不能防止"先合入授权、再合入迁移"的两步操作。

**当前处理**：

- 不修改 ruleset，不收紧 git 端审查标准，不为此增加实施阶段或验收标准。
- §11.4 明确声明信任边界的实际保证范围，避免对外宣称超出范围的保护。
- 该事实记录仅供未来参考；不要求在 Review 中选择任何候选方案。

## 19. 正式执行前置条件

在用户明确要求开始执行前，必须完成：

1. 本 r2 修订经重新 Review，状态从 `DRAFT` 改为 `APPROVED`。
2. 为 D1–D12 补充对应 decision JSON/ADR，并纳入正式 Plan 的 `decisionPaths`。
3. 基于最终路径建立匹配的 `YYYYMMDD-*.md` 与 `YYYYMMDD-*.plan.json` 正式 Plan pair，并给出 PR 检查点划分。
4. 正式 sidecar 列出精确 planned paths、area IDs、rule IDs、commands 和 decisions。
5. 运行 Pre 并确认所有 risk、area、rule 和 command 关联完整。
6. 记录 clean baseline、恢复 commit 和测试证据位置。
7. 再次获得明确的实施授权。

在上述条件满足前，本计划只允许继续评审和补充，不得据此执行目录移动、生成物切换、CI 激活或删除。

## 20. 本计划完成后的下一步改进：V3 原生替换 LayerGuard 派生实现

本节只登记后续方向，不属于 P0–P11 的实施范围。本计划完成并稳定运行后，再单独讨论、评审并建立正式计划。

### 20.1 目标

在 P6 完成后，Architecture Conformance 通用 engine 已位于 V3。后续目标是替换其 LayerGuard 派生的内部实现，由 V3 原生且可移植的检测器覆盖当前完整架构能力，同时保持稳定的 `ArchitectureConformance` 名称、位置、命令接口、输入 policy、summary schema 和 CI required-check 身份。

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

1. 先建立 LayerGuard 派生实现的完整 capability matrix 和 provenance 清单。
2. 为每项能力定义 V3 原生 detector contract、正例、故意违规负例和 coverage 边界。
3. 新旧实现并行运行，结论、失败类别和证据逐项对照。
4. 只有新实现覆盖相同或更强、跨平台稳定并通过真实 PR 负向控制后，才允许切换生产入口。
5. policy/baseline/report 迁移必须有独立 decision、回退清单和恢复演练。
6. 删除 LayerGuard 派生源码必须是后续计划的最后阶段，并通过 §12 授权执行。

### 20.4 与本计划的关系

本计划通过稳定 `ArchitectureConformance` 能力名称、位置、JSON 输入、报告契约和 CI 接口，为未来替换内部实现建立隔离层。本次完成去重、IFX binding 剥离和所有权迁移，是为了清晰化当前事实和降低维护成本，不是宣告最终实现已经完成。
