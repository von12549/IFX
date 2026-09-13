# Coding Guardrails 首版执行计划

> 状态：本地框架、文档、正反测试与 CI workflow 已实施；远端 CI 运行及 required-check 配置尚未验证。实际证据和限制见 [实施记录](02-implementation-evidence.md)。
>
> 原则来源：[已确认原则](../principles/README.md)；[讨论背景](../principles/00-guard-architecture-discussion.md)。
>
> 目标：在 IFX 建立可复制到新项目的 Pre-Code、Post-Code、Diff、Architecture Test 与 CI 门禁框架；提供可编辑输入、README 引导的再生成流程、规则覆盖矩阵和机器证据。

## 1. 边界与设计决定

首版**生成**文档索引、规则覆盖矩阵和新门禁框架的声明/绑定清单；**实现**通用阶段运行器、输入校验器及 CI 漂移检查。`src/layerguard.json`、LayerGuard 程序与 `plan05.json` baseline、G03 catalog/生成视图、G04 manifest、G05 policy 仍按原有权威链维护。再生成器只读取、校验、引用这些资产，不修改或复制其中的策略事实。现有工作流及专用 validator 保留；新工作流只负责本计划新增的检查，避免重新执行一整套已有 Gate。

门禁类型与阶段分开：LayerGuard、Roslyn/架构测试、G03/G04/G05、数据库与行为测试是**检测器**；Pre-Code、Post-Code、Diff 和 CI 是**触发与裁决阶段**。同一规则可以在多个阶段被引用，但只能有一个权威来源。Agent 阅读 README 后可以编排再生成和实现缺失检测器；任意自然语言规则不能自动变成“已机械验证”。

普通变更的 Pre-Code 摘要保存在任务记录中，不要求增加仓库文件。跨模块、公共契约、数据库、认证/租户、消息或部署等高风险变更需有独立决策记录或已有 ADR 的可核验链接。本地 hook 可提供提示，不作为合入资格证明。CI required checks 是最终机械门禁。

## 2. 计划交付的目录与接口

以下为目标结构；具体文件在相应阶段创建。输入采用 **JSON + JSON Schema**：人可手动编辑，机器字段无歧义；README 和规则说明使用 Markdown，不另存同一权威事实的副本。通用运行器选择 PowerShell 7，因为 IFX 的本地与现有 Linux/Windows CI 已使用 `pwsh`；新项目需提供 `pwsh` 运行环境，并替换项目绑定，而无需采用 .NET。

```text
docs/guards/
  README.md                         # 人与 Agent 的唯一入口、编辑/再生成/验证步骤
  principles/                       # 已确认原则与讨论记录
  plans/                            # 本执行计划及实施证据索引
  inputs/
    TECH_STACK.json                 # 可编辑：语言、工具链、命令与版本约束
    PROJECT_MAP.json                # 可编辑：模块/层/owner、路径与风险触发器
    rules/*.json                     # 可编辑：规则元数据或既有权威的引用
  bindings/ifx.json                 # IFX 检测器、权威文件、CI job 与触发器绑定
  contracts/
    tech-stack.schema.json
    project-map.schema.json
    rule.schema.json
    binding.schema.json
    guard-result.schema.json
    guard-manifest.schema.json
  generated/
    INDEX.md                        # 规则、阶段和文档入口索引
    COVERAGE_MATRIX.md              # 每条规则的检测器、覆盖深度与盲区
    guard-manifest.json             # 新阶段运行器消费的派生清单
  templates/new-project/            # 空白输入、绑定示例与接入说明

scripts/guards/
  Invoke-GuardRegeneration.ps1      # Generate / Check；仅写生成物白名单
  Invoke-CodingGuard.ps1            # Pre / Post / Diff 阶段入口
  ...                               # 输入校验、diff 分类和结果写入的模块
tests/guards/                      # 正反例、再生成与跨项目 fixture
.github/workflows/coding-guardrails.yml
```

生成物白名单限定为 `docs/guards/generated/*`。`scripts/guards/` 是首版实施时创建、后续人工维护的通用框架代码；`guard-manifest.json` 由输入再生成并驱动它，不生成任意 PowerShell 代码。新项目模板是人工维护的脚手架，不因 IFX 输入变化而覆盖。再生成器不得写 `src/`、`mcp/LayerGuard/`、`deployment/`、G03/G04/G05 目录、既有 workflow 或 baseline。

### 2.1 规则与结果契约

每条 `rules/*.json` 至少包含：稳定 `id`、说明、`authority`（唯一的文件/选择器或规则自身）、适用项目/路径、风险触发器、目标阶段、`enforcement`（blocking/advisory）、检测器 ID、覆盖级别（full/partial/none）、已知盲区和证据要求。引用现有 LayerGuard/Gate 规则时只记权威路径与选择器，不复制允许列表或 provider graph。新增规则若无检测器必须列为 `none`；`blocking + none` 在校验与 CI 中失败。既有意图性规则可以明确为 advisory，但不得用 advisory 覆盖已经阻断的现行 Gate。

`guard-result.schema.json` 固定字段：`gateId`、`stage`、`status`（pass/fail/not-run/blocked/advisory）、`scope`、`ruleIds`、输入/权威文件摘要、检查项、证据路径及失败原因。汇总器只在全部适用 blocking 检查确实通过时给出 pass；未运行、输入缺失、扫描不完整或报告解析失败不能转成 pass。运行报告允许时间戳；提交仓库的生成物须排序稳定、路径相对仓库、UTF-8/LF、无时间戳，以保证可重复再生成。

`COVERAGE_MATRIX.md` 不只显示“绿色/红色”，还区分 full、partial、none 与 out-of-scope，说明由哪个检测器证明、它不检查什么、CI 在哪个 job 执行。LayerGuard 的 `notChecked`、G03/G04/G05 的语义责任以及数据库/行为测试分工应映射进去。每个检测器有唯一 ID 和可核验的执行入口；重复运行不等于额外覆盖。

## 3. 实施阶段

### Phase 0 — 冻结现状与规则清单

- [x] P0.1 固定当前工作树、LayerGuard 工具版本、`src/layerguard.json`、`plan05.json`、G03/G04/G05 输入和全部现有 workflow 的文件摘要；记录当前可复现的检查命令及结果，不改原有 baseline。
- [x] P0.2 逐项登记现有规则 ID/规则簇、唯一权威、检测器、项目范围、CI job、已知盲区和现有例外。至少覆盖 LayerGuard、G03/G04/G05、Plan 04、数据库迁移与安全边界。只引用 Gate 的事实，不把它们重写进新规则文件。
- [x] P0.3 单列质量门禁现状：确认后端构建/测试由哪些现有 job 执行，核验前端 `lint`、`test:run`、`build` 和 .NET 格式/静态分析是否已经进入 CI。当前仓库前端有这些 npm 命令，但现有 workflow 未直接调用；把它登记为待补覆盖，不误标为已通过。
- [x] P0.4 给每项标记 full/partial/none，列出需要新增检测器的缺口；优先核对 LayerGuard 的语法匹配与语义绑定边界、Diff Guard 缺口及跨项目触发规则。对不能机器判定的要求标记人工审查，不伪装成硬门禁。
- **验收**：规则清单能从每条要求追溯到权威文件和实际检查入口；IFX 现有策略文件摘要与阶段开始时一致；未覆盖项显式列出。

### Phase 1 — 完整文档目录、可编辑输入与 schema

- [x] P1.1 建立第 2 节目录，编写顶层 README：文件所有权、可编辑/派生边界、Agent 的“读取 → 修改输入 → Validate → Generate → 检查漂移 → 运行门禁 → 审查 diff → 报告”步骤，以及新项目接入路径。
- [x] P1.2 定义 JSON Schema 和 IFX 输入。`TECH_STACK.json` 声明 .NET、前端、PowerShell 与实际构建/测试入口；`PROJECT_MAP.json` 声明模块、层、风险路径；`rules/*.json` 包含 P0 清单的规则元数据；`bindings/ifx.json` 指向现有权威及检测器命令。
- [x] P1.3 schema 校验除字段类型外还拒绝重复 ID、缺失 authority、无效相对路径、未知检测器、循环绑定、`blocking + none`、与现有 Gate 权威冲突及不在仓库内的路径。命令只能通过受信任的 binding ID 调用，不从规则描述字符串执行 shell。
- [x] P1.4 提供 `templates/new-project/`，不含 IFX 专有模块名或绝对路径；另用最小非 IFX fixture 验证模板可填写、可校验。
- **验收**：README 能让新 Agent 分清哪些文件可手改；合法 IFX 与新项目 fixture 通过 schema；每类无效输入都有失败测试。

### Phase 2 — 再生成与漂移检查

- [x] P2.1 实现 `pwsh scripts/guards/Invoke-GuardRegeneration.ps1 -Mode Generate`，仅根据已校验的输入/绑定生成 `INDEX.md`、`COVERAGE_MATRIX.md` 和 `guard-manifest.json`。对既有权威只读取并记录路径、选择器和摘要。
- [x] P2.2 实现 `-Mode Check`：在临时位置计算预期产物并逐字节比较，不修改工作树；输入、权威路径、schema 或生成物缺失/漂移时非零退出并指出具体文件与规则 ID。
- [x] P2.3 生成器采用固定排序、相对路径和 LF 输出，排除机器路径与当前时间；两次 Generate 后应无第二次 diff。写入前校验输出白名单，拒绝路径穿越或覆盖非生成文件。
- [x] P2.4 为手改 Tech Stack、项目映射、Rule、绑定、删除检测器、破坏权威摘要、篡改生成物等场景建立正反测试；证明 Check 可发现漂移且原有策略文件字节不变。
- **验收**：`Generate → Generate` 幂等；`Generate → Check` 通过；故意修改任一受管输入或产物时 Check 按预期失败；未检测规则不会显示为通过。

### Phase 3 — Pre-Code、Post-Code 与 Diff Guard 框架

- [x] P3.1 实现 `Invoke-CodingGuard.ps1 -Stage Pre -PlannedPaths ...`：按项目映射返回 owner、层、相关规则、相似实现的查找入口、风险触发器和建议验证路径。普通变更由 Agent 在任务记录中摘要；高风险变更要求独立决策记录，记录可指向已有 ADR。用结构化元数据关联规则 ID、受影响路径和决策文件，供 CI 核验；Pre 的报告标识为“计划影响分析”，不能声称已经验证未来代码。
- [x] P3.2 实现 `-Stage Post -Scope Focused|Full`：Focused 根据变更项目与反向依赖选择快速静态检查、构建和定向测试；无法可靠推导影响面时升级为 Full。Full 使用现有 IFX 入口运行完整 LayerGuard、G03/G04/G05、数据库/安全与 solution 测试，并运行前端 `lint`、`test:run`、`build`；分别保存原报告及统一结果，不重复实现其规则。CI 现有专用工作流仍各自运行。
- [x] P3.3 实现 `-Stage Diff -BaseRef ...`：本地读取 merge-base 到工作树的变更并包括未跟踪文件；PR CI 使用明确的 base/head SHA。识别新增/重命名/删除、生成物、依赖与锁文件、公共契约、迁移、认证/租户、消息、规则/baseline/validator/CI 自身变更。高风险变更缺少决策记录、生成物漂移、越过声明范围的文件、受保护门禁被削弱等可机械判定的项阻断；业务意图、测试充分性和无关清理输出为审查项。
- [x] P3.4 所有阶段写同一结果 schema；命令失败、超时、空报告、未知状态和依赖缺失按 fail/blocked 记录并使适用 blocking gate 非零退出。对每个阶段至少有合法、违规、输入缺失和跳过检查的 fixture。
- **验收**：普通与高风险 Pre 分类准确；Focused 不漏掉变更项目的反向依赖，不能确定时 Full；Diff 能在 Windows/Linux 路径与重命名、未跟踪文件场景工作；三阶段报告可由同一 schema 验证。

### Phase 4 — Architecture Test 责任补齐

- [ ] P4.1 按覆盖矩阵识别 LayerGuard 无法证明而风险较高的规则；仅对真实缺口增加 Roslyn/编译后架构测试或现有 validator 的新断言，不复制 LayerGuard 的项目图规则。优先评估全限定类型名的语义归属、真实装配关系和方法行为等已知盲区。
- [x] P4.2 每个新增 blocking 检测器同时提交正确与错误 fixture，证明违规会使本地与 CI 失败；若暂时不能验证，保留 partial/none 和责任说明，不创建永远通过的占位测试。
- [x] P4.3 将相关行为、契约和数据库测试映射到规则 ID；架构测试只证明其实际断言，不以一个测试项目名称代表所有边界已覆盖。
- **验收**：覆盖矩阵中每个新增 full 声明都有可运行正反测试；既有 LayerGuard/Gate 规则与新检测器没有相互冲突的权威定义。

### Phase 5 — CI 接入、保护与可移植性验收

- [x] P5.1 新建 `.github/workflows/coding-guardrails.yml`：在 PR 运行再生成 Check、Diff Guard、框架测试及本计划新增检测器；在 main push 运行再生成 Check 与新检测器。增设独立前端质量 job，使用锁文件安装依赖并执行 `lint`、`test:run`、`build`，补齐 P0 核实的 CI 缺口。上传统一 JSON 报告及可追溯的原始证据。既有 LayerGuard、G03/G04/G05、Plan 04、数据库工作流继续作为各自独立状态，不在新 workflow 再跑一遍；.NET 格式/静态分析按 P0 的实际基线决定引入范围，不把尚未执行的检查标为覆盖。
- [x] P5.2 为 `docs/guards/inputs/`、`bindings/`、`contracts/`、`scripts/guards/`、新 workflow 和现有策略/基线变更加 CODEOWNERS/审查路由；守护配置自身变化由 Diff Guard 分类，不能由同一 PR 静默移除检查。
- [x] P5.3 核验仓库保护规则中的 required checks：新增 guardrails job 与现有必需工作流都被列入；如无法通过仓库文件核验或设置，留下明确的外部配置/验证待办，不在报告里声称已经阻止合入。
- [ ] P5.4 在 IFX 干净 checkout 执行全部新增检查及受影响现有 Gate；用 `templates/new-project/` 的独立 fixture 验证无 IFX 路径、模块名或 .NET 构建前提；在 Windows 与 Linux 各运行一次再生成和 diff 测试。
- **验收**：PR 中修改可编辑输入而未再生成时 CI 失败；篡改生成物、缺失权威、删除 blocking 检测器、无决策记录的高风险 diff 均失败；正常变更通过。现有 LayerGuard/G03/G04/G05/baseline 文件与 P0 摘要一致；required checks 已被实际核验或如实标记未完成。

## 4. 执行顺序、回退与最终交付

顺序为 P0 → P1 → P2 → P3 → P4 → P5。每个阶段提交其文档、实现、正反测试和证据，后一个阶段不借“框架尚未完成”将失败标成成功。先以新框架的 advisory 报告比较现有检查，再在 P5 完成正反例与跨平台验证后把对应 CI job 设为 required；现有严格 Gate 在整个过程中保持原有强制级别。

若新框架出现误报或跨平台故障，回退新增 workflow/runner/生成物与输入的对应版本，保留原有 LayerGuard 和 G03/G04/G05/数据库门禁运行；不得通过放宽 `src/layerguard.json`、清空现有报告或改写 baseline 回退。任何正式新增 blocking 规则的放宽都需单独审查并更新覆盖矩阵与证据。

最终交付应包含：完整 `docs/guards/` 目录及 README、可编辑输入/schema、IFX 绑定和新项目模板、确定性再生成与只读 Check、新阶段运行器、统一结果报告、覆盖矩阵、正反测试、CI workflow、required-check 核验记录和已知未覆盖清单。完成时逐项报告实际执行结果；仅创建文件或通过文档校验不等于门禁已投入使用。
