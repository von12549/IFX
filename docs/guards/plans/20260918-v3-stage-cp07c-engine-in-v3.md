# CP07c — Plan 06 P6.4–P6.6：通用 engine 迁入 V3、混合型 trust contract 与不变性证明

本 pair 是 [正式 Plan pair](20260916-v3-stage-oriented-package-refactor.md) 检查点 CP07c 的变更 PR，按 [Plan 06](06-v3-stage-oriented-package-refactor.md) §14 P6.4–P6.6、D12 与 D29 把通用 Architecture Conformance engine 迁入 V3，写入混合型 trust contract，并证明 policy composite hash、report 字段、失败类别与 `v3-architecture` check 名称不变。它消费 `20260918-v3-stage-cp07c-authorization` 加入的授权。

## 1. 变更

**engine 迁入 V3**

- `docs/guards/V3_ifx/templates/ifx-layerguard/src/LayerGuard/` 的 27 个源码文件迁入 `docs/guards/V3/stages/post/gates/architecture/dotnet/Guards.ArchitectureConformance/`，项目与 assembly 名为 `Guards.ArchitectureConformance`/`layerguard`；C# namespace 仍为 `LayerGuard`，作为内部兼容面而非稳定门禁身份（D29）；
- 删除 V3_ifx 的 engine 项目文件；CP07c-prep 留下的空桥项目 `tests/LayerGuard.Tests/` 本检查点**保留**并改为引用 V3 engine：base（CP07c-prep）仍拥有该路径，候选验证会把 base 的 engine 测试恢复到那里，桥项目必须存在才能编译运行它们；删除推迟到 base 不再拥有该路径的后续检查点；
- IFX binding 与 host（`src/LayerGuard.Ifx`）改为引用 V3 engine 项目；solution 声明 V3 engine、V3 engine 测试、IFX host、IFX binding 测试与保留的空桥项目五个项目；
- `shared/trusted-components.json`：engine 组件覆盖 V3 engine 树、IFX binding/host 与保留的空桥项目路径，base-owned 组件收敛到 `tests/LayerGuard.Ifx.Tests/` 与 V3 测试/fixture（组件路径不得重叠）；
- `build/locks/`：`Guards.ArchitectureConformance*` 的 reviewed lock 更新，退役 engine 项目的 lock 删除，桥项目的 lock 保留；
- `scripts/Invoke-IFX.ps1`：engine 路径指向 V3，精确项目集合与引用相应收敛，IFX 标识扫描覆盖整棵 V3 engine 树。

**P6.5 混合型 trust contract**

`stages/post/stage.json` 的 `v3-architecture` trust contract 增加：

- `policyBinding`：engine 自身不含任何仓库 policy，IFX binding 由 base 的 IFX host 注册；配置中出现无 binding 的段时失败关闭；
- `guarantee`：evaluator、policy binding 与 policy 全部来自 base，判定覆盖 csproj XML 与 C# 源码文本中的引用、ring、ownership、declaration、package、import 与 G03/G04/G05 绑定；
- `knownGaps` 与 `crossCover`：MSBuild 求值后才存在的引用与属性（import、Condition、SDK 默认、生成项）由 `v3-quality-assembly` 以同一 commit 的已编译程序集交叉兜底，生成源码由 `v3-quality-solution` 的编译与测试兜底；
- `importInjectionRule`：针对 import 注入的检测规则仅登记为独立规则提案，不属于本 gate；
- `contracts/stage.schema.json` 增加上述字段，`shared/policy-config.json` 为它们登记 6 条 monotonicity 声明（comparator `none`）。

## 2. P6.6 不变性证明

| 不变量 | 证据 |
| --- | --- |
| policy composite hash | 迁移后报告 hash `d25e881a0cb6f2408b7e0a8fd5f2af37cd362e25ba241d5bb516d2d2f0c7a76f`，与 `policy/baselines/plan05.json` 的 `rulesetHash` 相同 |
| report 字段 | `tool`、`toolVersion`、`scope`、`checked`、`notChecked`、`projects`、`outside`、`clusters`、`rulebook`、`ruleset`、`baseline`、`durationMs` 不变；12 条 policy binding（G03、G03-catalog、G04 与 8 个 G04 绑定、G05）不变 |
| tool version | `0.4.0-a1` |
| 失败类别 | 规则 ID 与 violation 类别由 engine 规则集决定，未修改；`Test-IFXPackage.ps1` 的 L2.2 负向扫描仍产生同一阻断发现 |
| check 名称 | `v3-architecture` 与 13 个 required check 名称不变；`ci/jobs.json` 未变 |
| policy 文件 | 全部逐字节不变 |

## 3. 验证方式

- `Invoke-IFX.ps1 -Mode Test`：engine 测试 184 个从 V3 测试项目运行、IFX binding 测试 10 个从本包 fixture 运行，全部通过；严格扫描经 IFX host 通过；
- `Invoke-IFX.ps1 -Mode Check`：跨包源码清单、精确项目集合与引用（含保留的空桥项目）、TCB 覆盖、V3 engine 树的 IFX 标识扫描、通用与 IFX fixture 检查通过；
- `Test-IFXPackage.ps1`（含负向）、`Test-IFXManifests.ps1`、`Test-IFXTrustedBase.ps1` 通过；
- 候选验证（桥的「迁移后」一侧）：base（CP07c-prep）的 base-owned engine 测试位于 V3 路径、只引用 V3 engine 项目，在源码迁入后仍编译并全部通过；
- 本地两 PR 模拟：保护义务由授权恰好覆盖，Validate、Architecture、HistoricalIntegrity 通过。

## 4. 与 Plan 06 文字的差异

| Plan 06 描述 | 实际实现 | 理由 |
| --- | --- | --- |
| P6.4 通用 engine 迁入 V3 `Guards.ArchitectureConformance*` | 项目与 assembly 改名，C# namespace 保留 `LayerGuard` | 候选验证以 base 测试编译候选，namespace 改名会破坏它；稳定身份是 gate 与 check 名称（D29，用户批准） |
| V3_ifx 只保留 policy、baseline、binding 和 IFX fixtures | 基本达成：本包只剩 policy、baseline、IFX binding/host 与 IFX fixture，外加一个不含任何测试的空桥项目 | base 仍拥有 `tests/LayerGuard.Tests/`，候选验证会把 base 的 engine 测试覆盖回该路径；expand/contract 的 contract 一侧（删除空桥）留待 base 不再拥有该路径的后续检查点 |

## 5. 回退

还原本 pair 会把 engine 移回 V3_ifx，属于受保护路径移动与 TCB 变更，需要新的 `move` 与 `change-trusted-base` 授权。
