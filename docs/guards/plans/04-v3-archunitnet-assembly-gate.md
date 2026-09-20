# V3 ArchUnitNET 编译后架构检测器实施计划

> 状态：已实施可选检测器和 IFX 并行能力试验（2026-09-15）。未来全 Module Inbound Adapter 代码迁移与生产 CI 激活仍是独立阶段。

## 目标和现状

在通用 `V3` 源码包中增加**可选**的 ArchUnitNET 编译后检测能力。它检查已编译类型的依赖、接口实现和声明位置，补强项目文件检测；继续由 V3 的配置、生成器、测试和报告约束检测范围。项目引用、未编译源码、Plan/Pre/Diff、策略来源、基线及专门的运行时/行为测试不交给 ArchUnitNET。

当前 V3 仅实现 `forbidden-project-reference`，生成一个 xUnit 项目；`contracts/rule.schema.json` 没有程序集规则种类或输入清单。`V3_ifx` 的独立 LayerGuard 仍是 IFX 现行的完整架构门禁，V3 stage 只有 `L2.2` 的部分 Post 检测。现行 IFX policy 允许 Application 引用本模块 Contracts，部分 Application 还使用事件和共享 Context Contracts。未来的目标架构面向**所有 Module**：提供方 Infrastructure 的 Inbound Adapter 实现公开 Contract、转换协议并调用本模块 Application 用例；Application 不依赖本模块的对外 Contract。是否进一步禁止事件或共享平台 Contracts 必须在目标架构审查中单独决定。

## 实施边界

- `V3` 只增加通用模板、Schema、生成器逻辑、合成 fixture 和说明；不得内置 IFX 项目名、规则、程序集或生产策略。没有选择程序集检测器的 profile 继续生成现有项目，不增加 ArchUnitNET 依赖。
- `V3_ifx` 用于并行能力验证，保留本地 policy、现有独立 LayerGuard、旧门禁和 CI。不要把未来“Application 零对外 Contracts 依赖”直接设为当前 IFX 的 blocking 规则。
- `V3_backup` 只在通用实现及 IFX 隔离验证通过后同步；备份不接收 IFX 配置或生成产物。CI 激活与未来所有 Module 的业务架构迁移是独立阶段。

## P0 — 固定检测语义和输入清单

1. 为每一候选规则写出“项目文件事实”与“已编译类型事实”的边界。首个通用垂直切片覆盖：禁止某组源程序集/命名空间的类型依赖目标类型，以及限定某接口的实现类所在程序集/命名空间。名称匹配、例外、是否允许零个匹配、跨模块所有权和错误位置都需在 Schema 中明确；未实现的组合保持 advisory。
2. 扩展目标技术配置，显式给出待构建 solution/project、Debug 配置、预期程序集及其项目来源。不能只以通配符搜索 `bin/` 并把找到的文件当作完整覆盖。明确多目标框架、同名程序集、依赖程序集解析及缺失/无法加载程序集的失败策略。选定与生成测试项目兼容的 ArchUnitNET 包与固定版本，并记录 SDK/NuGet 前提。
3. 为每个检测器规定 `ruleId`、权威来源、配置哈希、预期与实加载程序集、匹配类型/接口数量、违规证据和未覆盖范围。零匹配、未加载目标或不支持的规则配置必须显式失败，不得成为绿色测试。

## P1 — 通用 V3 生成能力

1. 扩展 `contracts/rule.schema.json` 与 `tech-stack.schema.json`（或增加专用程序集清单 Schema），只接受已实现的程序集检测器种类及完整参数；更新 `Invoke-V3.ps1` 的验证、输入快照、生成和字节级 `Check`。旧 `forbidden-project-reference` 配置及 `examples/minimal` 保持可用。
2. 在 `templates/dotnet/` 增加条件生成的 ArchUnitNET 测试源码及固定包引用。生成器读取配置而非 IFX 名称；复用现有 `Self`/`Post` 分类和 rule ID。`Self` 使用独立合成程序集验证允许、禁止、例外及缺失目标；`Post` 加载显式清单中的目标程序集并核对覆盖数量。生成机器可读的规则证据，区分已检查、违规和未检查。输出必须能与现有项目引用检测同时运行。
3. 为编译后阶段加入可靠的构建顺序：执行已审查的目标 Debug 构建，再运行生成的测试；不得复用不明来源的陈旧 DLL。构建失败、清单过期、程序集缺失或加载失败时失败关闭。`Pre` 仍可在未构建时运行，不能被 ArchUnitNET 前提拖住。
4. 保持 `Generate → Check` 的文件集和 UTF-8 字节一致性；记录二进制规则只证明实际编译类型关系，不能把未使用的 `ProjectReference`、禁用条件编译源码、动态反射或运行时验证描述为已覆盖。

## P2 — 通用正反例及组合验收

- 在独立的多 Module 合成目标中验证命名模式可配置，而非 CRM 特例：Application 无公开 Contract 类型依赖、指定 Infrastructure.Inbound 类实现公开接口、违规实现落在 Application/其他 Infrastructure namespace、未加载或零匹配程序集、同程序集其他类绕过 Inbound 边界。
- 同时放入“只声明但未使用的禁止 `ProjectReference`”负例，证明旧项目检测器继续失败，而 ArchUnitNET 不冒充此项覆盖；放入实际类型依赖负例，证明编译后检测器会失败。
- 运行 V3 现有 `Test-V3.ps1`、`Test-V3Tools.ps1`，以及新增程序集 fixture、Generate/Check 漂移和未选程序集检测器的兼容性测试。记录每个规则的匹配数量、通过/失败原因和命令结果。

## P3 — IFX 并行能力试验及未来架构入口

1. 将经过验证的通用实现复制到 `V3_ifx`，只用当前代码**已经满足**的编译后规则做试验，例如 Contracts 类型/声明位置；与独立 LayerGuard 对照规则 ID、违规样本及未覆盖项。保持 `L2.3` 的当前语义和既有 policy 原样。运行 IFX 的 `Invoke-V3 -Mode Test`、`Invoke-IFX -Mode Test`、隔离正反例及项目 Check。
2. 在 IFX 的**目标架构提案**中对所有 Module 建立预期公开 Contract、Inbound Adapter、Application 用例及 Composition 装配映射。列出同步接口、事件、IAM 和 `Platform.Context.Contracts` 的不同迁移策略；更新相矛盾的旧计划和 policy **只能**作为未来独立迁移的执行项，不能以本检测器的安装暗中改变现行规则。
3. 待全部 Module 的代码迁移及行为测试完成，再提议把“Application 不引用本模块对外 Contracts”加入项目级硬门禁，把“仅批准的 Inbound Adapter 实现公开接口”加入编译后硬门禁。运行 DI 解析、版本/调用方校验顺序、租户及业务授权测试；ArchUnitNET 不能替代这些行为证据。

## P4 — 文档、备份和启用条件

- 更新 V3 的 README、架构、技术、规则编写和部署文档；新增检测器的真实命令、依赖、构建顺序、覆盖矩阵、限制及故障排查。文档中区分当前能力、完成后的能力和未来 IFX 架构。
- 只有 P1–P3 的通用和 IFX 试验通过、`Generate → Check` 无漂移后，逐文件同步 `V3` 到 `V3_backup`，比较相对路径与 SHA-256。未完成时保留备份原样。
- CI 先并行运行新编译后测试和旧 LayerGuard；在干净检出、Debug 构建、目标程序集完整性及故意违规负例都通过后，再单独决定 required check。不得用“测试运行成功但匹配数为零”作为启用证据。

## 完成定义

通用包对没有程序集规则的项目零回归；对配置了规则的项目可以确定性生成、构建、检查和报告；所有正反例及缺失程序集负例通过；IFX 并行试验不改变现行架构权威；备份在验收后同步。未来全 Module Inbound Adapter 迁移及现行 IFX policy 收紧不属于本计划实施完成的必要条件。

## 实施和验收记录

- 通用 `V3` 已增加两种受 Schema 限定的编译规则、显式 Debug 程序集清单、条件生成的 `TngTech.ArchUnitNET` 0.13.4 测试源码/依赖、构建与身份/刷新检查，以及 `artifacts/guards/v3-assembly.json` 报告。未选择编译规则的 profile 不携带该包引用或测试文件。
- `tests/Test-V3ArchUnit.ps1` 的多项目正反例覆盖实际类型依赖、实现类落错命名空间、零匹配、缺失程序集、只声明但未使用的禁止项目引用以及退出可选检测器后的生成文件清理。通用和 IFX 拷贝均通过。`Test-V3.ps1`、`Test-V3Tools.ps1`、IFX 的 Pre/Tools/Package 测试也通过。
- IFX `ARCH.BINARY.DOMAIN.CONTRACTS` 是现行 CRM Domain→Contracts 边界的并行编译试验：清单加载 CRM Domain/Contracts，匹配 12 个 Domain Entity 类型和 4 个公开 Contract 类型，8/8 stage 测试通过。独立 IFX LayerGuard 190/190 测试及严格扫描通过；其 policy、旧门禁和生产 CI 未改变。
- [全 Module 目标提案](../V3_ifx/docs/authored/architecture/INBOUND-ADAPTER-TARGET.md)区分 CRM、Registry、IAM 的同步接口迁移、Transaction/Registry 事件、Holdings 消费端及共享 Context Contracts。它不自动收紧当前 IFX 规则。
- 验收后把 40 个通用源码文件同步到 `V3_backup`；相对路径集合和逐文件 SHA-256 与 `V3` 完全一致，IFX 的 9 个共享实现文件也与通用源码哈希一致。IFX profile、policy 和生成产物未进入备份。
- 尚未建立生产 CI required check；这需在干净检出和故意违规负例通过后单独部署。二进制规则不覆盖未编译源码、反射、DI 行为或未声明在清单里的项目。
