# V3_ifx CI 切换与旧 Guardrails 清理计划

> 状态：待实施（2026-09-15）。本计划只定义迁移、并行验证、切换和清理顺序；在 V3_ifx 的替代能力、CI 实跑和回退入口完成验收前，不删除现行 Coding Guardrails。
>
> 基线：`codex/guards-principles-plan` 已将 V3_ifx 与当前 Contracts/Adapter 架构对齐；V3 stage、独立 IFX LayerGuard、ArchUnitNET、Pre、Package 和 Tools 自测均已通过。现行 `.github/workflows/coding-guardrails.yml` 仍调用根 `scripts/guards/`、`tests/guards/` 和 `docs/guards` 非 V3 配置，因此 V3 尚未完成生产 CI 切换。

## 目标与完成后的结构

逐步把现行 Coding Guardrails 的项目配置、Schema、阶段执行器、正反测试、生成物和 CI 调用入口迁入 `docs/guards/V3_ifx`。经过并行验证和 CI 切换后，删除 `docs/guards` 下除 V3 项目外的旧内容，并清理随旧框架存在的 `scripts/guards`、`tests/guards` 和旧 workflow。

`mcp/LayerGuard` 是明确保留的独立架构门禁项目。本计划不删除、移动、内嵌或以 V3_ifx 生成副本替代它；`src/layerguard.json`、`mcp/LayerGuard/baselines/`、`scripts/Invoke-LayerGuard.ps1` 和 `.github/workflows/layerguard.yml` 继续构成其生产入口。V3_ifx 内的独立 LayerGuard 副本用于隔离验证和迁移能力，不改变 `mcp/LayerGuard` 的所有权。

目标目录如下：

```text
docs/guards/
  V3/                              # 通用、可移植的 V3 源码包
  V3_backup/                       # 已验证的通用 V3 快照
  V3_ifx/                          # IFX 配置、策略、执行器、测试、生成物和迁移记录
  plans/                           # 保留：Guardrails 各阶段计划、实施记录和本清理计划

mcp/LayerGuard/                    # 保留：现行独立 LayerGuard 项目

.github/workflows/
  layerguard.yml                   # 保留：mcp/LayerGuard 生产门禁
  v3-ifx-guardrails.yml            # 新建：调用 V3_ifx 入口
  contract-event-governance.yml    # 保留独立专项门禁
  g04-deployment-runtime.yml       # 保留独立专项门禁
  g05-context-boundary.yml         # 保留独立专项门禁
  plan04-governance.yml            # 保留独立专项门禁
  database-migrations.yml          # 保留独立专项门禁
```

GitHub Actions 只发现 `.github/workflows/` 下的 workflow，因此 workflow 文件不会物理放入 `V3_ifx`。迁移的是 workflow 调用的脚本、配置、契约、测试和报告；新 workflow 只做触发、环境准备、命令编排和证据上传。

## 保留、迁移与删除边界

### 永久保留

- `mcp/LayerGuard/**`、`src/layerguard.json`、`scripts/Invoke-LayerGuard.ps1`、`.github/workflows/layerguard.yml`。
- `docs/guards/V3/**`、`docs/guards/V3_backup/**`、`docs/guards/V3_ifx/**`。
- `docs/guards/plans/**`。现有 Plan 01–05 作为设计、实施证据和迁移记录保留在原目录；后续计划继续按编号放入该目录。
- G03、G04、G05、Plan 04、数据库迁移等专项 validator、权威输入和独立 workflow。V3_ifx 可以引用或校验它们的结果，但不得用静态快照冒充专项行为验证。
- 前端 lint、test、build 门禁；可以迁入新的 V3_ifx workflow 编排，也可以拆成独立 workflow，但不能因旧 Coding Guardrails 删除而消失。

### 迁入 V3_ifx 后删除旧副本

| 现有内容 | V3_ifx 目标位置或替代能力 |
| --- | --- |
| `docs/guards/inputs/TECH_STACK.json` | `V3_ifx/profiles/ifx/tech-stack.json` |
| `docs/guards/inputs/PROJECT_MAP.json` | `V3_ifx/profiles/ifx/project-map.json` |
| `docs/guards/inputs/rules/*.json` | `V3_ifx/profiles/ifx/rules/`、`policy/layerguard.json` 及对应可读 views |
| `docs/guards/bindings/ifx.json` | V3_ifx profile、policy 和新 CI 命令映射；不得保留第二套权威绑定 |
| `docs/guards/contracts/*.schema.json` | `V3_ifx/contracts/` 中等价或扩展后的 V3 Schema |
| `docs/guards/generated/*` | `V3_ifx/profiles/ifx/views/`、`generated/stages/` 和机器结果 Schema |
| `docs/guards/templates/new-project/` | 通用能力进入 `V3/examples/minimal`、`V3/templates`；IFX 部分留在 `V3_ifx` |
| `docs/guards/decisions/*.json` | 迁入 `V3_ifx/decisions/history/`，或由 V3 Plan/decision 契约接管 |
| `docs/guards/plans/*.md` | 永久保留在原目录；更新其中失效的运行命令和链接，历史事实继续明确标注为历史 |
| `docs/guards/principles/` | 有长期价值的背景迁入 `docs/guards/plans/history/`；其余内容确认已被计划记录覆盖后删除 |
| `scripts/guards/*` | 由 `V3_ifx/scripts/` 的 Validate、Generate、Check、Pre、Post、Diff、Test 入口替代 |
| `tests/guards/*` | 由 `V3_ifx/tests/` 的通用、IFX、CI 和负例测试替代 |
| `.github/workflows/coding-guardrails.yml` | 由 `.github/workflows/v3-ifx-guardrails.yml` 替代 |

最终删除 `docs/guards/README.md`、`bindings/`、`contracts/`、`decisions/`、`generated/`、`inputs/`、`principles/` 和 `templates/`，保留 `plans/`，使 `docs/guards` 顶层只剩三个 V3 目录和计划目录。删除必须在引用扫描、并行 CI 和回退验证完成后一次性执行，避免两套配置长期漂移。

## P0 — 冻结现状与建立迁移矩阵

- [ ] P0.1 记录当前分支 SHA、非 V3 文件清单（原 tracked 基线 47 个，另含本计划）、`scripts/guards`、`tests/guards`、`.github/workflows/coding-guardrails.yml`、CODEOWNERS 和所有外部引用；把 `docs/guards/plans/**` 标记为保留范围，并记录 V3/V3_ifx/V3_backup 文件集及生成状态。
- [ ] P0.2 在干净 checkout 重跑现行 Coding Guardrails、`mcp/LayerGuard` 测试与严格扫描、V3/V3_ifx 全套测试、前端质量和 solution build，保存命令、退出码、测试数和报告路径。失败项必须先修复或明确为已知基线。
- [ ] P0.3 为旧 workflow 的四个 job 建立能力映射：`guard-framework`、`framework-windows`、`frontend-quality`、`assembly-domain`。逐项写出 V3_ifx 替代命令、输入、输出、正反测试和未覆盖项。
- [ ] P0.4 冻结永久保留清单。任何后续删除脚本不得匹配 `mcp/LayerGuard/**`、`src/layerguard.json`、`scripts/Invoke-LayerGuard.ps1` 或 `.github/workflows/layerguard.yml`；在清理测试中为这些路径增加存在性和 Git 状态断言。
- **验收**：每个旧文件和 CI job 都有唯一的“保留、迁移、归档或删除”结论；不存在以“V3 测试通过”代替 CI/专项门禁等价性证明的项目。

## P1 — 收敛 V3_ifx 权威输入与文档

- [ ] P1.1 比较根 `TECH_STACK.json`、`PROJECT_MAP.json`、rules、binding 与 `V3_ifx/profiles/ifx`、`policy/layerguard.json`。把仍有效但尚未进入 V3_ifx 的 area、owner、risk trigger、command ID、规则 authority、coverage 和限制迁入；重复事实只保留一个权威来源。
- [ ] P1.2 扩展 V3 decision/Plan/Diff 契约，使高风险变更仍能机械关联受影响路径、area、规则、验证命令和 decision。保留现行 Diff Guard 已验证的增删改名、未跟踪文件、越界路径、受保护删除和缺少 decision 等失败语义。
- [ ] P1.3 将有效历史 decision 迁到 `V3_ifx/decisions/history`，将仍需保留的原则背景迁到 `docs/guards/plans/history`。现有 Plan 01–05 留在 `docs/guards/plans` 原位置。更新 V3_ifx README、DEPLOYMENT、计划和内部链接；历史内容不得继续充当运行时配置。
- [ ] P1.4 用 `Invoke-V3Docs -Mode Render/Check` 和 V3 Generate/Check 生成唯一的可读 views 与机器项目；禁止手工维护第二套 INDEX、COVERAGE_MATRIX 或 manifest。
- **验收**：V3_ifx 可以仅依靠自己的 profile、policy、contracts 和 package-local 输入完成 Validate、Generate、Check、Pre、Diff 和文档检查；运行时不读取待删除的根 `docs/guards` 内容。

## P2 — 补齐旧 Coding Guardrails 的 V3_ifx 等价能力

- [ ] P2.1 为 CI 增加稳定、非交互的 V3_ifx 入口，明确 Linux/Windows 参数、目标根目录、输出目录和退出码。所有报告写入 `artifacts/guards/`，并符合 V3 机器结果契约。
- [ ] P2.2 完成 CI-safe Diff：显式消费 PR base/head SHA，检查完整 changed set，并按 V3 Plan/decision 验证风险覆盖。不得只检查 Plan 声明路径而忽略真实 diff，也不得因空 diff 或浅克隆误报成功。
- [ ] P2.3 将现行 Domain assembly 检测的真实覆盖迁入 V3 编译后门禁。显式列出所有受保护 Domain 程序集及预期引用，保留允许、违规、缺程序集、陈旧程序集和零匹配负例。只有与 `Invoke-DomainAssemblyGuard.ps1` 覆盖对照一致后，才允许删除旧 assembly-domain 实现。
- [ ] P2.4 把 portable template、自身配置、生成漂移、Pre/Post/Diff、架构 policy、package isolation 和跨平台换行行为纳入 V3_ifx tests。每个 blocking 能力同时具有正例与会导致非零退出码的负例。
- [ ] P2.5 为 frontend quality 保留 `npm ci`、lint、`test:run`、build 四步及锁文件缓存。V3 profile 负责命令 ID 和影响映射，workflow 负责安装 Node 并执行命令；V3 不把未执行命令报告为通过。
- **验收**：旧 `guard-framework`、`framework-windows`、`assembly-domain` 和 `frontend-quality` 的每项实际检查都已有可运行替代；差异清单为零，或差异被明确批准且没有降低 blocking 覆盖。

## P3 — 新建 V3_ifx workflow 并保持并行运行

- [ ] P3.1 新建 `.github/workflows/v3-ifx-guardrails.yml`。至少包含：profile/docs/generated Check，V3 stage tests，IFX independent LayerGuard test/strict scan，PR Diff，portable/IFX tools tests，frontend quality，以及完成 P2.3 后的 compiled architecture job。
- [ ] P3.2 workflow 在 PR 和 main push 上运行；checkout 对 Diff 使用完整或足够的 Git 历史，并显式传入 base/head SHA。固定 .NET、PowerShell、Node 和 NuGet 前提，使用锁文件及可审查的依赖版本。
- [ ] P3.3 Linux 和 Windows 分别运行需要跨平台证明的 Validate/Generate Check/Diff 测试；耗时构建只在能够保持等价覆盖的 job 中去重。所有 job 即使失败也上传对应 JSON 和测试日志。
- [ ] P3.4 保留 `.github/workflows/coding-guardrails.yml` 并行运行，不修改 `layerguard.yml` 和各专项 workflow。比较新旧 job 的触发范围、结论、报告和耗时，禁止先删除旧 workflow 再观察缺口。
- **验收**：至少一个正常 PR 在 Linux/Windows 所需 job 上全绿；故意制造生成漂移、缺 decision、越界 diff、Domain 违规和 frontend 失败的验证分支均被对应新 job 阻断。

## P4 — 切换 required checks 与生产入口

- [ ] P4.1 记录新旧 workflow 在同一提交上的并行结果，核对所有 blocking 结论。V3_ifx strict scan 必须为零项 baseline clean，`mcp/LayerGuard` 继续独立通过。
- [ ] P4.2 将 branch protection/ruleset 的 required checks 从旧 Coding Guardrails job 切换到稳定命名的 V3_ifx job，同时保留 `mcp/LayerGuard` 和 G03/G04/G05/Plan 04/数据库等专项 required checks。
- [ ] P4.3 若仓库套餐或权限无法配置 required checks，记录 API/UI 证据并将该项保持未完成；不得声称 workflow 文件存在等于门禁已经强制。未完成时旧 workflow 继续保留。
- [ ] P4.4 切换后再运行一次正常 PR 和一组故意违规 PR，确认 required checks 实际阻止合入；记录 check 名称，避免 workflow/job 重命名导致保护规则失效。
- **验收**：新 V3_ifx checks 已在真实 PR 上运行并被实际配置为 required，或外部限制被明确记录且清理阶段保持阻塞；`mcp/LayerGuard` required check 未被替换或移除。

## P5 — 删除旧运行时与非 V3 文档

- [ ] P5.1 停止并删除 `.github/workflows/coding-guardrails.yml`；如 frontend quality 被拆分为独立 workflow，先验证新文件已运行。更新 CODEOWNERS，使 V3/V3_ifx、`mcp/LayerGuard`、policy、workflow 和专项门禁仍有明确 owner。
- [ ] P5.2 删除已被 V3_ifx 替代的 `scripts/guards/` 和 `tests/guards/`。保留根 `scripts/Invoke-LayerGuard.ps1` 及其他专项 validator；使用精确文件清单删除，禁止对整个 `scripts` 或 `tests` 目录递归清理。
- [ ] P5.3 删除 `docs/guards` 下非 V3、非 plans 的 README、bindings、contracts、decisions、generated、inputs、principles 和 templates。`docs/guards/plans` 及其全部计划文件必须保留。执行前确认需保留的 decision/原则背景已经迁入 V3_ifx 或 plans，并验证每个删除目标的解析结果严格位于 `docs/guards` 且不位于 `docs/guards/plans`。
- [ ] P5.4 更新所有 README、CLAUDE/Agent guidance、workflow、脚本、测试、CODEOWNERS 和文档链接。运行 `git grep`/`rg`，对已删除路径、旧脚本名、旧 workflow 名和旧 check 名要求零运行时引用；历史引用若保留，必须明确标注为历史且不提供失效命令。
- [ ] P5.5 最终断言 `docs/guards` 顶层仅含 `V3`、`V3_backup`、`V3_ifx`、`plans`；断言 Plan 01–05 和 `mcp/LayerGuard` 的 tracked 文件集、项目入口、baseline、workflow 全部存在。
- **验收**：干净 checkout 不包含任何旧 Guardrails 运行时或悬空链接；V3_ifx 和保留的独立门禁均不读取已删除路径；工作流清单只删除被证明等价替代的 Coding Guardrails workflow。

## P6 — 最终回归、证据与回退验证

- [ ] P6.1 在干净 Linux 和 Windows checkout 运行 V3/V3_ifx Validate、Generate/Check、Docs Check、Pre/Diff 正反例、V3 stage Test、IFX package/tools tests、IFX strict scan、`mcp/LayerGuard` 全测试与严格扫描。
- [ ] P6.2 运行 solution build、相关 .NET 测试、frontend lint/test/build，以及 G03/G04/G05/Plan 04/数据库专项 workflow 的本地等价命令。记录实际通过数、warning、报告路径和未执行的外部步骤。
- [ ] P6.3 从删除前提交演练回退：只恢复旧 Coding Guardrails workflow、根配置、脚本和测试即可重新运行旧门禁；回退不得修改或重建 `mcp/LayerGuard`、其 baseline 或专项 gate 权威。
- [ ] P6.4 在 `V3_ifx/DEPLOYMENT.md` 和迁移记录中写明最终 CI job、required check、维护入口、生成流程、故障排查、保留的独立门禁及已删除内容。计划状态只有在全部机械与外部条件完成后才改为已完成。
- **验收**：新生产入口可从干净 checkout 重现；全部故意违规负例仍失败；无 tracked/untracked 旧目录回生；`mcp/LayerGuard` 与专项门禁保持独立、可执行、可追踪。

## 删除门槛

以下条件必须全部满足，才能执行 P5：

1. V3_ifx 已覆盖旧 Coding Guardrails 四个 job 的实际职责，并有正反例证明。
2. 新 workflow 已在真实 PR 与 main 路径运行；需要的 Linux/Windows job 均通过。
3. V3_ifx Diff 使用真实 base/head changed set，并保留高风险 decision 和受保护删除语义。
4. compiled architecture 覆盖不低于旧 Domain assembly guard；零匹配、缺程序集和陈旧程序集失败关闭。
5. frontend quality 和各专项 workflow 仍处于活动状态。
6. `mcp/LayerGuard` 项目、policy、baseline、脚本和 workflow 已通过存在性与运行验证。
7. required checks 已实际切换；如果受套餐或权限阻塞，则不得删除旧 workflow。
8. 所有待删除路径的运行时引用为零，需保留的历史资料已经迁入 V3_ifx 或 `docs/guards/plans`；清理命令明确排除 plans。

## 完成定义

完成后，`docs/guards` 顶层只包含 `V3`、`V3_backup`、`V3_ifx` 和 `plans`。Plan 01–05 保留在 `docs/guards/plans`，后续计划沿用该目录和编号。新的 `.github/workflows/v3-ifx-guardrails.yml` 从 V3_ifx 读取唯一的 IFX profile、policy、contracts、tests 和生成物，并承担旧 Coding Guardrails 的阶段、Diff、架构补充和前端质量编排。`mcp/LayerGuard` 及其生产 workflow 完整保留并继续独立执行；G03/G04/G05、Plan 04 和数据库等专项门禁未被静态 V3 快照替代。清理后所有生成检查、正反例、跨平台 CI、solution/frontend 回归和真实 PR required checks 都有可审查证据，且不存在对已删除路径的运行时引用。
