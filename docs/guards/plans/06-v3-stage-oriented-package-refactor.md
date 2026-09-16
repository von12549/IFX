# V3 Stage 化、自包含配置与门禁工程重构计划

> 状态：**DRAFT / 决策项已冻结 / 仅供评审，禁止执行**。
>
> 本文综合当前 V3、V3_backup、V3_ifx 对比 Review 及后续讨论形成。当前已冻结目标、原则、阶段、验收口径和 D1–D8 设计决策；不移动目录、不改名、不生成或安装 workflow、不改变 required checks、不删除任何现有文件。只有本文状态被人工改为 `APPROVED`、正式 Markdown/JSON Plan pair 建立并再次获得明确执行授权后，才允许开始 P0。

## 1. 背景与问题陈述

V3 已形成 Analysis、Pre、Post、Diff 和 CI 等阶段能力，V3_ifx 进一步接管了 IFX 的独立 LayerGuard、专项门禁、质量门禁、历史完整性和 CI 编排。现有能力总体有效，但目录和维护模型出现以下问题：

1. 通用 V3 源码、IFX 配置、运行脚本、模板、生成物、历史材料和证据按不同维度平铺在根目录，职责需要跨目录理解。
2. `.github/workflows/` 等激活文件位于 V3 外部，V3 内缺少完整的权威声明、确定性生成、预览、安装和反向验证链。
3. `scripts/` 同时包含人工入口、CI 入口、内部运行脚本、生成器和维护命令；仅看文件名无法判断调用边界、副作用和稳定性。
4. `templates/ifx-layerguard/` 与 `generated/dotnet/LayerGuard/` 存在整套逐字节重复；后者实际是正式架构门禁，不只是普通 Unit Test。
5. `generated/stages`、`generated/dotnet` 等名称主要表达实现技术，未准确表达 Stage、门禁职责和生命周期。
6. JSON 仍是机器权威，但现有 Markdown 视图覆盖有限，且已经出现 profile JSON、Markdown views 和 architecture review 不同步的实例。
7. V3 与 V3_ifx 的通用文件缺少机器可读的上游版本、允许偏移和同步验证契约。

## 2. 目标

### 2.1 配置与激活

- V3 所需的全部机器配置、模板、生成声明和部署映射都位于 V3 包自身目录。
- IFX 专用配置全部位于 V3_ifx 自身目录，不以 `.github/`、根脚本或其他历史目录作为隐藏配置权威。
- GitHub workflow、CODEOWNERS managed block 及其他必须复制到目标位置的文件，先在 V3 内确定性生成和验证，再由人工显式确认安装或复制。
- V3 内部候选文件是可再生产物；目标位置文件只是激活副本。二者必须能够反向验证。

### 2.2 Stage 信息架构

- 从目录、文件名、manifest 和文档中能够直接识别 Bootstrap、Analysis、Pre、Post、Diff、CI 以及 Shared/Governance 的职责。
- 配置以主要消费 Stage 归类；跨 Stage 输入只保留一个 `shared/` 权威，不在多个 Stage 复制。
- 每个 Stage 都声明入口、输入、输出、enforcement、证据路径、文档和依赖 Stage。

### 2.3 脚本与命令模型

- 区分公共命令、内部引擎、生成器、宿主适配器、维护工具和测试辅助程序。
- 人类、Agent 和 CI 尽量调用同一公共命令接口，不复制门禁逻辑。
- 每个可执行文件都有机器可读的 Stage、audience、副作用、稳定性、输入和输出声明。
- 未来加入 Python、JavaScript、.NET tool 或其他运行时，不改变分类模型。

### 2.4 .NET 门禁工程

- 生成工程按门禁职责命名，不按 `UnitTest`、`ArchUnitNET` 或 `dotnet` 等实现细节命名。
- V3 profile 驱动的 Self/Post/Diff 工程命名为 Stage Gate，并在工程内部按测试类别拆分。
- IFX LayerGuard 被视为正式 Architecture Conformance Gate；如果源码不存在参数化生成，不再维护 template/generated 两份副本。
- 本次将 LayerGuard 派生实现内化为 Architecture Conformance Gate 是过渡性收敛，不代表其检测引擎已经被 V3 原生实现取代；完整替换属于本计划完成后的独立改进主题。
- `bin/`、`obj/`、报告和运行日志全部移出 `docs/guards` 源码树。

### 2.5 JSON 与 Markdown

- JSON 继续是唯一机器语义权威。
- Markdown 可以聚合多个 JSON；每份生成文档必须列出来源路径、角色和 SHA-256。
- 生成 Markdown 与人工 Markdown 分离；生成器不得覆盖人工设计理由。
- 聚合 Markdown 默认单向生成。只有另行评审并满足原子事务、逐块 source hash 和全量回滚时，才允许多 JSON Import。

## 3. 非目标

- 本计划不改变 IFX 当前业务架构规则的语义。
- 本计划不借目录迁移弱化、豁免或删除任何 blocking gate。
- 本计划不自动安装 GitHub workflow、修改远端 ruleset 或变更 required checks。
- 本计划不在未完成正反例与并行验证前删除旧入口。
- 本计划不要求每个 Stage 建立独立进程或独立 .NET 项目。
- 本计划不以目录整洁为理由复制 shared 配置或拆分出重复实现。
- 本计划不重写或移除 LayerGuard 派生的检测引擎；只调整其所有权、命名、位置、调用契约和重复生成模型。

## 4. 权威与生命周期模型

按照以下优先级定义事实：

1. **JSON authority**：Stage 配置、规则、policy、toolchain、activation、command 和 document manifest。
2. **Implementation**：PowerShell/.NET/其他语言实现与模板；实现解释 JSON，不暗藏项目 policy。
3. **Generated candidate**：Markdown、Stage Gate 源码、GitHub workflow、CODEOWNERS managed block 等可再生产物。
4. **Activated copy**：目标 `.github/` 等宿主读取位置中的副本。
5. **Runtime evidence**：`artifacts/guards/` 下的报告、TRX、日志、hash 和 summary。

低层不得反向成为高层的隐含权威。激活副本不得直接编辑；运行证据不得被当成当前配置。

## 5. 建议目标结构

以下是方向性结构。最终路径在正式执行 Plan 中冻结。

```text
docs/guards/V3/
├─ guard-system.json
├─ shared/
│  ├─ contracts/
│  ├─ toolchain.json
│  ├─ authorities/
│  └─ decisions/
├─ stages/
│  ├─ bootstrap/
│  ├─ analysis/
│  ├─ pre/
│  ├─ post/
│  ├─ diff/
│  └─ ci/
├─ commands/
├─ engine/
│  ├─ common/
│  ├─ modules/
│  └─ stages/
├─ generators/
│  ├─ docs/
│  ├─ dotnet-gates/
│  └─ activation/
├─ integrations/
│  ├─ github/
│  └─ agents/
├─ maintenance/
├─ docs/
│  ├─ authored/
│  ├─ generated/
│  └─ docs-map.json
├─ generated/
│  ├─ activation/
│  └─ gates/
├─ tests/
│  ├─ analysis/
│  ├─ pre/
│  ├─ post/
│  ├─ diff/
│  ├─ ci/
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
│  │     ├─ architecture/
│  │     ├─ specialized/
│  │     ├─ quality/
│  │     └─ historical-integrity/
│  ├─ diff/
│  └─ ci/
├─ commands/
├─ integrations/
├─ maintenance/
├─ docs/
├─ generated/
└─ tests/
```

V3 是唯一 portable engine。V3_ifx 默认作为 IFX overlay 使用 V3 公共 engine/contracts，不再复制和修改通用实现。若未来要求单独复制 V3_ifx 即可运行，应通过带 `core.lock.json` 的发布/打包过程产生自包含分发包，而不是维护第二套手工 fork。

## 6. Stage 职责

| Stage | 主要职责 | 典型输入 | 典型输出 |
| --- | --- | --- | --- |
| Bootstrap | 初始化包、建立未评审配置和安装前准备 | project ID、目标根、SDK | 初始 JSON、目录、状态报告 |
| Analysis | 只读发现目标事实并形成可评审提案 | repository、当前 profile | inventory、drafts、review report |
| Pre | 路径、area、owner、risk、rule 和 command 关联 | proposed paths 或 formal Plan | advisory/blocked summary |
| Post | 源码、项目引用、程序集、policy、专项和质量检测 | target tree、compiled outputs、policy | detector reports、summary |
| Diff | 最终 changed set 与正式 Plan 对账 | base/head、Plan、protected paths | scope pass/fail |
| CI | 编排 Stage、生成激活候选、验证 required checks | Stage manifests、workflow JSON | workflow candidate、activation report |
| Shared/Governance | 跨 Stage 工具链、authority、decision、schema | reviewed JSON | 被多个 Stage 引用，不独立执行 |

每个 Stage 新增 `stage.json`，至少声明 `id`、`entryPoint`、`inputs`、`outputs`、`dependencies`、`enforcement`、`documentation` 和 `supportedPlatforms`。

## 7. 脚本和可执行文件分类

### 7.1 公共命令 `commands/`

供 human、Agent 或 CI 直接调用的稳定 API。建议最终只暴露少量入口：

- `Invoke-V3.ps1`：Validate、Pre、Post、Diff、All。
- `Invoke-V3Setup.ps1`：Bootstrap、Analysis。
- `Invoke-V3Docs.ps1`：Render、Check；是否支持 Import 由 D4 决定。
- `Invoke-V3Deployment.ps1`：Generate、Preview、Install、Verify 激活文件。
- IFX overlay 可以保留一个薄的 `Invoke-IFXGuardrails.ps1`，但只负责选择 IFX package 和 Stage，不重复实现通用逻辑。

### 7.2 内部引擎 `engine/`

- 不承诺外部调用兼容性。
- 公共命令负责参数、帮助、退出码和结构化输出；内部模块负责实现。
- 共享 PowerShell 逻辑优先收敛为不导出内部细节的 `.psm1` 模块。

### 7.3 生成器 `generators/`

- JSON → Markdown。
- Stage JSON/profile → .NET Stage Gate。
- CI JSON → workflow candidate。
- activation manifest → 目标文件候选或 managed block。
- Generate 只写 package 内 `generated/`；Install 必须是独立显式操作。

### 7.4 Integrations、Maintenance 与 Test Support

- `integrations/`：GitHub、Agent hook、Skill 等宿主胶水，只调用公共命令。
- `maintenance/`：policy projection、history manifest、迁移和 hash 更新；写 authority 时必须要求 `Preview`/`Apply` 或等价显式语义。
- `tests/support/`：只服务 fixture、负例和临时仓库，不作为用户入口。

### 7.5 Command manifest

新增机器权威 `shared/commands.json`，为每个入口记录：

- `id`、`entryPoint`、`kind`；
- `stages`、`audiences`；
- `mutability`、`requiresExplicitAcceptance`；
- `inputs`、`outputs`、`evidence`；
- `platforms`、`stability`。

CI 生成器和 `docs/generated/COMMANDS.md` 都从该 manifest 读取，不再手工维护命令清单。

## 8. .NET 门禁工程分类和命名

### 8.1 Stage Gate

当前 profile 驱动的 Self/Post/Diff xUnit 工程改为职责名称：

```text
generated/gates/stage/
└─ IFX.Guards.StageGate.Tests/
   ├─ Self/
   ├─ Post/
   ├─ Diff/
   ├─ GeneratedInputs/
   └─ IFX.Guards.StageGate.Tests.csproj
```

- `Self` 证明检测器能接受正例并拒绝故意违规 fixture。
- `Post` 扫描项目引用和编译程序集。
- `Diff` 验证实际 changed set、Plan 和 protected paths。
- 保留一个 csproj 以降低 restore/build 成本，通过目录、类名和 test trait 区分类别。
- `ArchUnitNET` 仅作为 package 依赖和实现说明，不进入稳定工程名称。

### 8.2 Architecture Conformance Gate

当前 IFX LayerGuard 改为正式源码，而不是生成副本：

```text
stages/post/gates/architecture/dotnet/
├─ IFX.Guards.ArchitectureConformance/
├─ IFX.Guards.ArchitectureConformance.Tests/
└─ IFX.Guards.ArchitectureConformance.slnx
```

- 直接 build/test/run 唯一源码。
- policy 仍由 JSON 参数传入。
- `Check` 验证源码 manifest、policy binding 和 fixture，而不是比较两份相同目录。
- 删除 `templates/ifx-layerguard` 与 `generated/dotnet/LayerGuard` 的双份维护前，必须完成完整 parity 和回退证明。

### 8.3 构建与运行输出

- 所有 `bin/obj` 定向到 `artifacts/build/v3-ifx/`。
- TRX、JSON report 和 logs 定向到 `artifacts/guards/v3-ifx/<stage>/`。
- `generated/` 只包含可由 authority + implementation 重建的候选源码或激活文件。
- 除非 D3 决定跟踪生成源码，否则 `generated/gates/` 默认不进入 Git，仅由 Generate/Check 在 CI 中重现。

## 9. Markdown 文档模型

### 9.1 文档分类

- `docs/authored/`：人工维护的架构理由、迁移说明、操作指导和决策背景。
- `docs/generated/`：从一个或多个 JSON 聚合生成，禁止直接编辑。

建议生成：

- `OVERVIEW.md`：Stage 全景、入口和输入输出。
- `AUTHORITY.md`：authority、projection、candidate、activation 和 evidence 关系。
- `ANALYSIS.md`：inventory、review 状态和未决差异。
- `PRE.md`：project map、risk、Plan、commands 和适用 rules。
- `POST.md`：rules、detectors、coverage、LayerGuard 和专项/质量 gate。
- `DIFF.md`：changed set、protected paths、Plan scope 和失败语义。
- `CI.md`：job DAG、触发条件、required checks、候选与激活状态。
- `COMMANDS.md`：公共命令、执行者、副作用、输入输出和示例。
- `GENERATED-ASSETS.md`：所有生成产物及其 source/target/lifecycle。

### 9.2 `docs-map.json`

每个生成文档声明：

- output path；
- sources/globs；
- source role；
- renderer；
- generation mode；
- 是否允许 Import。

生成文档头部必须包含来源表和 hash。`Docs Check` 验证精确内容、完整文件集和 source hash，并纳入 Validate/CI。

## 10. CI 激活模型

V3 内新增：

```text
stages/ci/
├─ workflow.json
├─ required-checks.json
├─ activation.json
└─ templates/github-actions.yml.in

generated/activation/
└─ .github/workflows/v3-ifx-guardrails.yml
```

标准生命周期：

```text
Declare → Generate → Check → Preview → Approve → Install/Copy → Verify
```

- `Generate` 只写 V3 内候选路径。
- `Check` 验证 YAML、job DAG、命令 ID、Stage 依赖、稳定 check 名和生成漂移。
- `Preview` 比较候选与 `.github/` 激活副本。
- `Install` 需要 `-AcceptDeployment`，或者由人工复制后运行 `Verify`。
- `Verify` 检查目标文件头部 source path/hash 与内容。
- GitHub ruleset 继续作为远端状态；本地 `required-checks.json` 是期望声明，只读 verifier 比较远端实际状态，任何远端写入仍需独立授权。

## 11. 现有目录到目标职责的初步映射

| 当前目录 | 初步目标 |
| --- | --- |
| `architecture/` | `docs/authored/architecture/`，目标提案移入 Analysis drafts |
| `analysis/ifx/` | `stages/analysis/{evidence,drafts,reports,migration}/` |
| `ci/` | `stages/ci/` |
| `contracts/` | `shared/contracts/` 或特定 Stage contracts |
| `decisions/` | `shared/decisions/` |
| `examples/` | `examples/` 或 `tests/fixtures/`，按是否面向用户区分 |
| `generated/` | `generated/{activation,gates}/`；运行输出移入 `artifacts/` |
| `history/` | `stages/post/gates/historical-integrity/` |
| `hooks/`、`skills/` | `integrations/agents/` |
| `policy/` | `stages/post/policy/`，authority registry 在 `shared/authorities/` |
| `profiles/ifx/` | 拆分到 `shared/`、`stages/pre/`、`stages/post/`、`stages/diff/` |
| `quality/` | `stages/post/gates/quality/` |
| `rules/` | 机器规则进入 `stages/post/rules/`，authoring guide 进入 `docs/authored/` |
| `scripts/` | 按 command/engine/generator/integration/maintenance 分类 |
| `specialized/` | `stages/post/gates/specialized/` |
| `templates/dotnet/` | `generators/dotnet-gates/` |
| `templates/ifx-layerguard/` | 转为唯一 Architecture Conformance Gate 源码 |
| `tests/` | 按 Stage 分类，公共 fixture/support 单列 |

## 12. 实施阶段

以下阶段全部处于未开始状态。

### P0 — 冻结基线和完整分类

- [ ] P0.1 记录 V3、V3_backup、V3_ifx 的 tracked 文件、hash、引用、生成关系和当前 Validate/Check/Test 结果。
- [ ] P0.2 为每个文件标注 authority/implementation/generated/activation/evidence、Stage、owner 和保留/迁移/删除结论。
- [ ] P0.3 建立全部 PowerShell 及其他 executable 的调用图，区分公共入口和内部调用。
- [ ] P0.4 冻结两个 .NET gate 的源码、fixture、项目、package、测试类别和执行路径。
- [ ] P0.5 将当前已知漂移登记为迁移前缺陷：Markdown views、architecture review、DEPLOYMENT、文件计数、无效 `SourceConfig`、未受校验的 `ci/jobs.json`。
- **门槛**：每个现有文件和命令都有唯一分类；未分类项不得进入后续移动。

### P1 — 冻结新契约和决策

- [ ] P1.1 定义并 schema 化 `guard-system.json`、`stage.json`、`commands.json`、`docs-map.json`、`activation.json` 和 generated asset manifest。
- [ ] P1.2 明确配置、projection、candidate、activation 和 evidence 的 authority 顺序。
- [ ] P1.3 关闭本文第 15 节全部待决策项，并记录 decision JSON/ADR。
- [ ] P1.4 为旧目录和旧命令定义兼容期、deprecation 输出和删除条件。
- **门槛**：新路径和名称未冻结前，不移动任何生产文件。

### P2 — 在旧路径上建立 manifest 与漂移检查

- [ ] P2.1 使用 manifest 描述现有文件，而不先移动目录。
- [ ] P2.2 为 V3 与 V3_ifx 建立 upstream/core lock 和允许偏移清单。
- [ ] P2.3 将现有 profile views、analysis reports、CI job 声明和文档纳入统一 Check。
- [ ] P2.4 让 CI 在现有布局下先阻止 Markdown、analysis 和 activation drift。
- **门槛**：先证明新元数据和检查模型有效，再开始结构迁移。

### P3 — Stage 配置拆分

- [ ] P3.1 将 project map、risks、rules、toolchain、assembly manifest、protected paths、workflow 和 required checks 分配给明确 Stage/Shared authority。
- [ ] P3.2 将 IFX-specific protected paths 从通用 C# template 移入 Diff 配置。
- [ ] P3.3 建立旧 profile 格式到新 Stage 配置的只读兼容加载器或一次性迁移器。
- [ ] P3.4 保持旧 profile 不变运行并与新配置并行比较，不允许 silent fallback。
- **门槛**：新旧配置生成的 Pre/Post/Diff 语义和报告一致或有批准的增强差异。

### P4 — 命令、引擎和脚本重构

- [ ] P4.1 建立 `commands/` 稳定入口和 `shared/commands.json`。
- [ ] P4.2 将内部实现迁入 `engine/` 和模块；外部调用旧路径保留薄 wrapper。
- [ ] P4.3 将 docs、dotnet、workflow 生成逻辑迁入 `generators/`。
- [ ] P4.4 将 hooks/skills/GitHub glue 迁入 `integrations/`。
- [ ] P4.5 将 policy sync、history regeneration 和迁移工具迁入 `maintenance/`，补齐 Preview/Apply 语义。
- [ ] P4.6 按 Stage 重组测试和 test-support，不改变测试覆盖。
- **门槛**：CI 和人工入口只调用公共命令；内部脚本不再被 workflow 直接引用。

### P5 — .NET Gate 重命名、分类和去重

- [ ] P5.1 将 profile 生成工程重命名为 `IFX.Guards.StageGate.Tests`，内部划分 Self/Post/Diff。
- [ ] P5.2 将 LayerGuard 转为唯一 `IFX.Guards.ArchitectureConformance` 正式源码。
- [ ] P5.3 在删除 template/generated 重复前完成文件、测试、scan、policy binding 和负例 parity。
- [ ] P5.4 将所有 `bin/obj` 输出定向到 `artifacts/build/`，报告定向到 `artifacts/guards/`。
- [ ] P5.5 验证 clean checkout 可以从 JSON 和模板重建 Stage Gate；Architecture Gate 无需复制即可运行。
- **门槛**：174 文件重复消除，两个 Gate 的角色、输入、输出和测试证据可独立解释。

### P6 — 聚合 Markdown 文档

- [ ] P6.1 实现 `docs-map.json` 和通用 renderer/checker。
- [ ] P6.2 生成 OVERVIEW、AUTHORITY、ANALYSIS、PRE、POST、DIFF、CI、COMMANDS 和 GENERATED-ASSETS 文档。
- [ ] P6.3 每份生成文档列出全部来源、角色和 hash。
- [ ] P6.4 将人工背景迁入 `docs/authored/`，确保 Render 不覆盖。
- [ ] P6.5 按 D4 结论实现只读文档或受限原子 Import。
- **门槛**：任意 authority 变化都会导致相关 Markdown Check 失败；无陈旧生成视图。

### P7 — CI candidate、激活和远端验证

- [ ] P7.1 从 CI JSON 生成 package 内 GitHub workflow candidate。
- [ ] P7.2 校验 job DAG、Stage/command IDs、matrix 展开后的 required-check 名称和触发条件。
- [ ] P7.3 实现 Preview、显式 Install 或人工复制后的 Verify。
- [ ] P7.4 建立 required-checks 远端只读 verifier；远端写入保持独立授权。
- [ ] P7.5 先并行运行旧激活文件和新候选生成链，不立即切换 required checks。
- **门槛**：候选与激活副本之间不存在未解释差异；workflow 生成器有正反例。

### P8 — 物理目录迁移与兼容期

- [ ] P8.1 按第 11 节映射逐组移动，不进行一次性大爆炸迁移。
- [ ] P8.2 每组移动后更新 manifest、链接、脚本、tests 和 docs，并运行完整 Check。
- [ ] P8.3 旧公共路径保留明确 deprecation wrapper；内部路径不提供永久兼容。
- [ ] P8.4 处理 V3_backup 的冻结、发布或移除方案。
- [ ] P8.5 验证仓库引用扫描无悬空路径，无隐含外部配置权威。
- **门槛**：新结构可在 Linux/Windows clean checkout 重现，旧兼容入口只剩批准范围。

### P9 — 并行验证、切换、清理与回退证明

- [ ] P9.1 对 Analysis、Pre、Post、Diff、CI、专项、质量、历史完整性运行新旧正常与负向 parity。
- [ ] P9.2 验证目录移动、生成物缺失、hash drift、policy drift、protected deletion、浅克隆、空 diff 和未知 command 均失败关闭。
- [ ] P9.3 通过真实 PR 验证候选 workflow 和 required checks 后，单独取得激活授权。
- [ ] P9.4 只有在激活与回退验证完成后，删除旧 wrappers、重复目录和失效文档。
- [ ] P9.5 保存精确删除清单、恢复 commit 和 selective restore 演练记录。
- **门槛**：新结构是唯一生产路径，旧路径零运行时引用，全部 blocking 能力有可审查正反证据。

## 13. 验收标准

全部满足后才可标记完成：

1. V3/V3_ifx 所需机器配置均在各自 package 内，外部仅有激活副本和运行证据。
2. Analysis、Pre、Post、Diff、CI 的入口、输入、输出和证据可由目录和 manifest 直接识别。
3. 通用 V3 engine/template 中不存在 IFX 路径、项目名或 policy 硬编码。
4. 每个 executable 都有 command manifest 分类；workflow 不直接调用 internal/maintenance/test-support。
5. Stage Gate 和 Architecture Conformance Gate 名称及职责清晰，不以 ArchUnitNET 等实现细节作为稳定身份。
6. `templates/ifx-layerguard` 与 `generated/dotnet/LayerGuard` 的 174 文件重复被消除。
7. `docs/guards` 下无 `bin/obj` 和运行报告；clean 后不会重新写入这些位置。
8. 所有生成 Markdown、workflow candidate 和 Stage Gate 都能确定性重建并 Check。
9. 激活 workflow 带来源/hash，可通过 Verify 证明与 package candidate 一致。
10. stage/policy rule 不只校验 ID；coverage binding 能表达 full/subset/advisory 和 authority/hash。
11. 当前 views/review/deployment 文档漂移已清零，并由 CI 阻止复发。
12. 新旧生产能力通过 Linux/Windows、正常/负向、clean checkout 和真实 PR 验证。
13. 迁移有精确回退清单，不修改或丢失历史证据和领域权威。

## 14. 风险与控制

| 风险 | 控制 |
| --- | --- |
| 大规模移动导致引用和 CI 同时失效 | 先 manifest、后分组移动；保留薄 wrapper；每组独立 Check |
| Stage 化导致 shared 配置复制 | `shared/` 唯一权威；stage manifest 只引用不复制 |
| 聚合 Markdown 隐藏来源 | 强制 source path/role/hash 表；CI 逐字节 Check |
| workflow generator 产生有效 YAML 但无效门禁 | 校验 command/stage IDs，运行本地 dispatcher，真实 PR 负向控制 |
| 人工复制后目标文件漂移 | candidate header、activation manifest、Verify 和 required-check verifier |
| LayerGuard 去重时降低覆盖 | 删除前执行完整文件、测试、scan、fixture 和 policy parity |
| 新命名影响 required checks | job/check 名单独建权威；显示名称与内部路径解耦 |
| 通用 V3 与 IFX overlay 再次分叉 | core lock、允许偏移 manifest、禁止复制通用实现 |
| 生成目录仍累积构建垃圾 | MSBuild 输出强制定向 `artifacts/build`；测试断言 docs 树无 bin/obj |

## 15. 已冻结设计决策

D1–D8 已根据评审结论全部关闭。后续若要改变这些决定，必须新增 decision JSON/ADR，并重新评估受影响阶段，不得在实施中静默改变。

### D1 — V3_ifx 的分发边界

- **决定**：仓库内使用 V3 canonical engine + V3_ifx overlay，V3_ifx 不再维护通用实现的手工 fork。
- 如果未来要求把 V3_ifx 单独复制到另一仓库即可运行，通过发布/打包步骤生成 self-contained distribution，并包含 `core.lock.json`、来源版本和文件 hash；不恢复第二套活动源码。

Answer: 不要求把V3_ifx单独复制即可运行。V3_ifx是V3对IFX的门禁框架，在新的仓库中，将使用V3源码包生成新的门禁。

### D2 — V3_backup 的长期角色

- **决定**：迁移期间保留 V3_backup；新结构稳定并通过最终验收后，将其冻结为只读 release snapshot。
- snapshot 必须包含版本、来源 commit、完整文件 hash manifest 和生成日期；禁止通过日常同步把它继续当作第二套活动源码。
- 后续如 Git release/tag 已能满足恢复与审计需求，是否删除 snapshot 必须进入独立清理决策，不属于本计划的自动删除范围。

Answer: A 可以删除，仅保留V3的源码包作为长期角色

### D3 — 是否跟踪生成的 Stage Gate 源码

- **决定**：不跟踪生成的 Stage Gate 源码。CI 和本地验证每次从模板、JSON 和 manifest 执行 Generate + Check。
- Git 只跟踪权威配置、模板、生成器和生成资产 manifest；代码 Review 通过候选 diff、生成报告和确定性检查完成。

Answer: A

### D4 — 聚合 Markdown 是否允许反向 Import

- **决定**：仅一对一配置页可以保留受控 Import；多 JSON 聚合文档全部只读生成。
- 一对一 Import 继续要求 source path/hash、schema、完整 profile 校验和失败回滚；聚合文档不得成为编辑入口。

Answer: A 全部只读。

### D5 — 激活文件的安装方式

- **决定**：同时支持人工复制 + Verify，以及工具化 `Install -AcceptDeployment`。
- Generate/Check/Preview 不得写目标位置；Install 必须显式确认并记录 source/target/hash。人工复制后必须运行同一个 Verify。

Answer: 接受建议

### D6 — 稳定命名语言

- **决定**：目录、JSON ID、command ID 和 project 名使用英文；生成/人工文档可以使用中文。
- 稳定能力名称采用 `StageGate` 和 `ArchitectureConformance`；不把 ArchUnitNET、LayerGuard 等具体工具品牌写入长期稳定的项目身份。迁移文档和 provenance 仍必须明确记录实现来源。

Answer: 接受建议

### D7 — 迁移单位

- **决定**：先完成 P0–P2 的共同契约和旧路径映射，再按“V3 通用能力 → V3_ifx overlay”小步迁移。
- 禁止分别为 V3 与 V3_ifx 设计两套结构；IFX 需求先判断能否作为通用能力进入 V3，不能通用化的部分才进入 overlay。

Answer: 接受建议

### D8 — 历史完整性的 Stage 归属

- **决定**：目录上属于 `stages/post/gates/historical-integrity`，因为它产生 blocking validation；manifest 的 execution class 标记为 `governance-audit`，允许 schedule/manual 与受影响路径触发策略。

Answer: 接受建议

## 16. 正式执行前置条件

在用户明确要求开始执行前，必须完成：

1. 本文状态从 `DRAFT` 改为 `APPROVED`。
2. 为已经关闭的 D1–D8 补充对应 decision JSON/ADR，并纳入正式 Plan 的 `decisionPaths`。
3. 基于最终路径建立匹配的 `YYYYMMDD-*.md` 与 `YYYYMMDD-*.plan.json` 正式 Plan pair。
4. 正式 sidecar 列出精确 planned paths、area IDs、rule IDs、commands 和 decisions。
5. 运行 Pre 并确认所有 risk、area、rule 和 command 关联完整。
6. 记录 clean baseline、恢复 commit 和测试证据位置。
7. 再次获得明确的实施授权。

在上述条件满足前，本计划只允许继续评审和补充，不得据此执行目录移动、生成物切换、CI 激活或删除。

## 17. 本计划完成后的下一步改进：V3 原生替换 LayerGuard 实现

本节只登记后续方向，不属于 P0–P9 的实施范围。本计划完成并稳定运行后，再单独讨论、评审并建立正式计划。

### 17.1 目标

最终使 Architecture Conformance Gate 不再依赖 LayerGuard 派生实现，由 V3 原生且可移植的检测器覆盖当前完整架构能力，同时保持稳定的 `ArchitectureConformance` 名称、命令接口、输入 policy、summary schema 和 CI required-check 身份。

### 17.2 必须保留的能力边界

后续替换至少需要逐项覆盖并证明：

- layer 与 ownership boundary；
- direct/transitive project reference；
- package、import、source 和 declaration placement；
- interface implementation、payload 和 compiled dependency；
- G03/G04/G05 policy binding 与 composite hash；
- strict baseline、zero-match、missing-input 和 stale-input 失败关闭；
- 当前正例、负例、fixture 和报告字段。

### 17.3 后续实施前提

1. 先建立 LayerGuard 派生实现的完整 capability matrix 和 provenance 清单。
2. 为每项能力定义 V3 原生 detector contract、正例、故意违规负例和 coverage 边界。
3. 新旧 Architecture Conformance Gate 并行运行，结论、失败类别和证据逐项对照。
4. 只有新实现覆盖相同或更强、跨平台稳定并通过真实 PR 负向控制后，才允许切换生产入口。
5. policy/baseline/report 迁移必须有独立 decision、回退清单和恢复演练。
6. 删除 LayerGuard 派生源码必须是后续计划的最后阶段，不得在本次结构重构中提前发生。

### 17.4 与本计划的关系

本计划通过稳定 `ArchitectureConformance` 能力名称、JSON 输入、报告契约和 CI 接口，为未来替换内部实现建立隔离层。本次将 LayerGuard 派生代码从 template/generated 双份复制收敛为单一正式源码，是为了清晰化当前事实和降低维护成本，不是宣告最终实现已经完成。
