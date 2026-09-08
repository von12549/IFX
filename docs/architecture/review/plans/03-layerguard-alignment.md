# 子计划 3：LayerGuard 对齐新架构

> G04 反向链接：L5.1/B1/B4 必须约束 Runtime Host 仅引用 Composition/host primitives；见 [G04 runtime baseline](../gates/G04/deployment-runtime-boundary.zh-CN.md)。

> 状态：03-A0 Core Bootstrap 与 03-A1 Gate Policy Binding 已完成；03-B 待实施
> 上级计划：[`00-master-plan.md`](00-master-plan.md)
> 执行位置：03-A0 在 Gate 01–05 之前；03-A1 在 Gate 前置放行之后；03-B 在子计划 1/2 之后。
> 治理输入：[`00-G03-contract-event-governance.md`](00-G03-contract-event-governance.md) 在 03-A1 提供 module ownership、合法 provider/consumer 边、shared primitives allowlist 和 waiver policy。
> G03 交接入口：[治理说明](../gates/G03/contract-event-governance.zh-CN.md)、[catalog](../gates/G03/contract-event-catalog.yaml) 与 [generated governance input](../gates/G03/generated/layerguard-governance-input.json)；L5.1 必须直接消费并验证 catalog hash，不能复制 ownership 配置。
> 可执行交接包：[`G03 -> Plan 03 handoff`](../gates/G03/handoffs/plan03-layerguard-handoff.md)，含 owner、L5.1/B1–B4 回访条件、fail-closed 清单和回交证据。
> 上下文输入：[`00-G05-context-sensitive-data-boundary.md`](00-G05-context-sensitive-data-boundary.md) 在 03-A1 提供 Context/Messaging schema primitive allowlist、Contract/Event 声明与禁止框架规则；字段分类和值传播由专用 validator/tests 负责。
> 当前控制点：`src/layerguard.json` 使用 03-A1 target policy，直接校验 G03/G04/G05 artifact 与组合 hash；正式 B1 已冻结，后续 B2/B3/B4 必须保持相同目标语义。

## 目标依赖矩阵

| From | 允许依赖 | 明确禁止 |
| --- | --- | --- |
| Domain | 本模块 Domain、经批准的 Domain primitives | Contracts、Application、Presentation、Infrastructure、其他模块 |
| Contracts | BCL、经批准的 contract/context/messaging primitives | Domain、Application、Infrastructure、Presentation、Security implementation、ASP.NET、EF/MediatR/transport SDK |
| Application | 本模块 Domain、本模块 Contracts、本模块 Application abstractions | 其他模块 Contracts/实现、Infrastructure、Presentation |
| Presentation | 本模块 Application、HTTP 框架、必要的宿主协议类型 | DbContext、Repository、其他模块实现 |
| Integration Adapter | 本模块 Application Port、目标提供方 Contracts、必要 transport client | 目标模块实现/Domain/DbContext、业务规则复制 |
| Infrastructure | 本模块 Application/Domain、持久化与外部技术 | 其他模块 DbContext/实现；除 Integration Adapter 外的外部 Contracts |
| Composition | 本模块各项目、必要宿主 DI primitives | 业务逻辑、跨模块数据库访问 |
| Runtime Host（API/Worker） | 各模块 Composition、宿主/运行原语 | 模块业务实现、Repository/DbContext 直接调用；Worker 不引用 Presentation |

## 执行里程碑

本子计划分三段执行，不能等 Gate 或其他代码改造完成后才第一次建立新分析能力：

- **03-A0 LayerGuard Core Bootstrap**：在 Gate 01 之前完成 Phase 0–4，建立所有权/角色识别、可配置规则能力、正反 fixture、统一执行入口和 B0.5 bootstrap 报告；只启用不依赖未产出 Gate artifact 的确定性规则。
- **03-A1 Gate Policy Binding**：Gate 01–05 前置放行后完成 Phase 5，把权威 catalog、allowlist、Runtime Role 和 context policy 绑定到工具，保存正式 B1 并启用“历史 baseline 可暂存、禁止新增违规”的 CI 门禁。
- **03-B Strict Closure**：子计划 1/2 完成后执行 Phase 6–8，生成 B2/B3/B4 对比、清零未豁免违规并开启严格模式。

旧规则产生的 B0 和新引擎的 B0.5 只用于说明工具能力；正式前后对比必须使用绑定全部 Gate policy 后、具有相同目标规则语义的 B1 与 B4。若规则缺陷必须修正，应重跑受影响基线并记录规则版本、配置和原因。

| 检查点 | 时点 | 用途 |
| --- | --- | --- |
| B0 | 修改 LayerGuard 前 | 记录旧工具能发现什么；不作为正式改善基准。 |
| B0.5 | 03-A0 完成、Gate 01 尚未实施 | 验证新引擎、通用角色和确定性规则；不冒充完整 Gate policy 基线。 |
| B1 | 03-A1 完成、Contracts/Events 尚未改造 | 正式改造前基线，冻结完整目标规则语义和历史违规集合。 |
| B2 | Contracts/Ports/Adapters 迁移完成 | 证明同步调用边界违规被消除且没有新增绕行依赖。 |
| B3 | Integration Events 迁移完成 | 证明事件声明、Inbound Adapter 和运行边界违规被消除。 |
| B4 | 严格模式启用 | 最终零未豁免违规报告，与 B1/B2/B3 形成审查证据。 |

## Phase 0 — 建立规则基线与能力差距

- [x] **Phase 0 完成**：本 Phase 下全部项目均已完成并附有证据。证据：[`../evidence/03-a0-layerguard-bootstrap.md`](../evidence/03-a0-layerguard-bootstrap.md)。

- [x] L0.1 运行当前 LayerGuard，保存所有结果、误报、漏报和配置解析行为作为基线。
- [x] L0.2 生成真实项目引用图与 namespace 引用图，比较 `src/layerguard.json` 声明和代码现实。
- [x] L0.3 将上方目标矩阵逐条转成可测试的正例与反例，不以自然语言规则代替验证用例。
- [x] L0.4 检查 LayerGuard 当前是否能区分“本模块 Contracts”与“其他模块 Contracts”。
- [x] L0.5 检查 LayerGuard 当前是否能识别 Integration Adapter 子目录、独立项目或命名约定。
- [x] L0.6 检查工具能否验证直接项目引用、源码 namespace 使用、声明位置与传递依赖。
- [x] L0.7 对无法由现有配置表达的规则建立工具增强清单，确认是扩展配置 schema 还是调整物理项目结构。
- [x] L0.8 建立可扩展的门禁职责模型：LayerGuard 只验证静态依赖、声明和禁止类型；字段、值和运行时语义由外部 validator/test 负责，具体 Gate 05 绑定延后至 Phase 5。

## Phase 1 — 设计迁移期 ring 与项目识别

- [x] **Phase 1 完成**：本 Phase 下全部项目均已完成并附有证据。

- [x] L1.1 为 `Contracts`、`IntegrationAdapter`、`Composition` 增加可识别的 ring/role，或定义等价的 ownership-aware project role。
- [x] L1.2 在迁移期同时识别 `*.Abstractions` 与 `*.Contracts`，但禁止新增旧命名的项目和引用。
- [x] L1.3 更新当前 X-1 规则：Application 可以引用本模块 Contracts，但不得引用其他模块 Contracts。
- [x] L1.4 定义可读取或一致性生成 shared primitives allowlist 的输入 schema，并用 provisional fixture 验证 default-deny；不在 03-A0 复制尚未产出的 Gate 03/05 权威数据。
- [x] L1.5 明确 Adapter 若保留在 Infrastructure 项目中时的目录/namespace 边界，避免整个 Infrastructure 获得外部 Contracts 许可。
- [x] L1.6 实现可配置的 Composition 与 API/Worker Runtime Host 模式匹配能力，并用 provisional fixture 验证允许边和禁止内容；实际 Gate 04 role matrix 在 Phase 5 绑定。
- [x] L1.7 为历史违规建立临时 baseline/waiver 格式，要求 owner、原因、创建日、到期日和删除条件。

## Phase 2 — 增强 ownership-aware 规则能力

- [x] **Phase 2 完成**：本 Phase 下全部项目均已完成并附有证据。

- [x] L2.1 实现并测试 module ownership 解析，使规则能区分 own module 与 foreign module。
- [x] L2.2 实现规则：Domain 不得引用任何 Contracts，包括本模块 Contracts。
- [x] L2.3 实现规则：Application 可引用本模块 Contracts，但不得引用 foreign Contracts。
- [x] L2.4 实现规则：Integration Adapter 只可引用本模块 Application Port 与声明的 provider Contracts。
- [x] L2.5 实现规则：Contracts 不得引用任何模块内层或基础设施项目。
- [x] L2.6 实现规则：Presentation 不得直接引用 DbContext、Repository 实现或外部模块实现。
- [x] L2.7 实现规则：Infrastructure 不得跨模块引用 DbContext/Repository/implementation assembly。
- [x] L2.8 实现规则：API/Worker Runtime Host 只能通过 Composition 装载模块，禁止直接引用业务实现类型；Worker role 不得引用或映射业务 Presentation。
- [x] L2.9 为未识别项目、模糊 ownership 和无法解析引用采用 fail-closed 或明确告警策略，避免静默跳过。
- [x] L2.10 实现 provider/consumer graph 输入能力，用 fixture 验证 Adapter 只能引用图中登记的 provider Contracts，并阻断未登记同步依赖环；权威图在 Phase 5 接入。
- [x] L2.11 实现 context runtime 位置和 primitive allowlist 的可配置检查能力，用 fixture 验证 Application 不依赖 runtime context implementation；批准位置和原语在 Phase 5 接入。

## Phase 3 — 增加声明与框架泄漏规则

- [x] **Phase 3 完成**：本 Phase 下全部项目均已完成并附有证据。

- [x] L3.1 验证同步 Contract、公共 DTO 与 Integration Event 只能声明在提供方 Contracts 允许的 namespace。
- [x] L3.2 验证消费方 Port 声明在消费方 Application 的约定位置，不能放入提供方 Contracts。
- [x] L3.3 验证 Integration Adapter 的实现放在外层约定位置并实现本模块 Port。
- [x] L3.4 禁止 Contracts 引用 EF Core、MediatR、ASP.NET、具体序列化器、broker SDK 与 DI 容器包。
- [x] L3.5 禁止 Contracts 声明 Handler、DbContext、Repository、DI extension 或实现类。
- [x] L3.6 禁止 Integration Event payload 使用 Domain Entity、EF Entity 或其他模块内部类型。
- [x] L3.7 为命名规则提供有限且明确的例外机制，避免只靠 `Reader`/`Handler` 字符串产生大量误报。
- [x] L3.8 禁止 ContractRequestContext/Event Envelope 引用 HttpContext、ClaimsPrincipal、JWT/token 类型、Activity、ILogger、DI、Security implementation 或 broker carrier。
- [x] L3.9 实现同步 Contract metadata/业务 DTO、Event Envelope/payload 声明分区规则，并定义与外部字段分类 validator 的职责接口；具体 C0-C4/purpose policy 在 Phase 5 绑定。

## Phase 4 — 建立 LayerGuard 自动化测试套件

- [x] **Phase 4 完成**：本 Phase 下全部项目均已完成并附有证据。

- [x] L4.1 为每条允许边建立最小正例 fixture，防止规则过严阻断合法架构。
- [x] L4.2 为 Domain → Contracts、Application → foreign Contracts 等每条禁止边建立反例 fixture。
- [x] L4.3 添加“同名模块前缀”“嵌套模块名”“测试项目”“生成代码”等 ownership 边界用例。
- [x] L4.4 添加 Adapter 位于独立项目与 Infrastructure 子目录两种组织方式的用例；最终未采用的模式可保留为工具能力测试。
- [x] L4.5 添加直接引用、间接/传递引用、源码 using、fully-qualified name 和反射配置等绕过场景测试。
- [x] L4.6 添加模块循环依赖与 Contract 循环依赖检测测试。
- [x] L4.7 添加配置错误、未知 ring、重复规则和过期 waiver 的失败测试。
- [x] L4.8 验证报告包含违规源、目标、规则编号、所属模块与可执行修复提示。
- [x] L4.9 添加合法 BCL-only context primitive 正例，以及 Contracts → ASP.NET/Security implementation/Activity/broker 和 Application → runtime context implementation 反例。
- [x] L4.10 提供统一的本地/CI 执行入口，运行新引擎及所有不依赖 Gate artifact 的确定性规则，保存 B0.5 报告并在 G01–G05 实施期间阻断这些规则的新增违规。

## Phase 5 — 绑定 Gate Policy 并保存正式改造前基线

- [x] **Phase 5 完成**：本 Phase 下全部项目均已完成并附有证据。证据：[`../evidence/03-a1-layerguard-policy-binding.md`](../evidence/03-a1-layerguard-policy-binding.md)。

- [x] L5.1 Gate 03 module ownership、provider/consumer graph、shared primitives、backup owner 与 waiver policy 由生成视图和 catalog 双向校验后直接加载；配置不复制 provider graph。
- [x] L5.2 Gate 04 release runtime manifest、全部绑定 artifact hash、`api/worker/all` role 和 RuntimeHost → Composition-only 规则已接入并 fail closed。
- [x] L5.3 Gate 05 Context/Messaging project、BCL-only policy 与禁止框架类别已绑定；字段、值、传播、安全输出和 replay 行为仍明确交给专用 validator/tests。
- [x] L5.4 `src/layerguard.json` 已切换为 03-A1 target policy，并只保存物理 ring/pattern 与工具规则解释；Gate ownership/provider/allowlist 数据来自绑定 artifact。
- [x] L5.5 完整规则在 Contracts/Events 改造前代码上生成 116 个历史 finding，并按 44 条真实 from/to 依赖边聚类。
- [x] L5.6 正式 B1 migration baseline 已建立：116/116 matched、0 new、0 stale；每项含 owner、原因、创建/到期日和删除条件，且受 90 天和不可豁免规则约束。
- [x] L5.7 CI 运行 G03 Phase 7 reconciliation、完整 LayerGuard tests 和 B1 repository scan；输入不可读、hash 漂移、未知 role、扫描失败、过期/超期 waiver、新增或陈旧 baseline 均失败。
- [x] L5.8 Gate policy binding 已增加正反测试，覆盖 catalog hash/projection、G04 hash、G05 BCL-only、未知 role、policy hash、waiver 上限与不可豁免规则。
- [x] L5.9 B1 报告保存 LayerGuard `0.4.0-a1`、组合 policy hash、12 个绑定 artifact/hash、运行参数语义、44 个 finding clusters 与扫描耗时，作为 B2/B3/B4 固定对照。

## Phase 6 — 跟随 Contracts / Events 迁移并清理违规

- [ ] **Phase 6 完成**：本 Phase 下全部项目均已完成并附有证据。

- [ ] L6.1 随子计划 1 迁移 CRM/Registry → Transaction 同步依赖并清除对应 Application foreign Contract 违规。
- [ ] L6.2 子计划 1 完成后使用 B1 的目标规则语义生成 B2 报告，说明每条依赖边的新增、消除或保留原因。
- [ ] L6.3 随子计划 2 迁移 Holdings 外部事件 handler 并清除 Application foreign Event Contract 违规。
- [ ] L6.4 子计划 2 完成后使用相同目标规则语义生成 B3 报告，并与 B1/B2 对比。
- [ ] L6.5 修复 Contracts 的框架/实现泄漏、未使用公共表面及 ApiHost/Composition 装配越界。
- [ ] L6.6 修复 CurrentUser/context 迁移后的引用和声明位置违规，验证 context primitive allowlist 未扩大为通用 SharedKernel 许可。
- [ ] L6.7 将 LayerGuard 结果与 Gate 03 catalog/source reconciliation 串联，防止配置复制 ownership 数据后发生漂移。
- [ ] L6.8 将 Gate 05 catalog/schema/security test 结果与 LayerGuard 报告共同发布，但失败来源和责任规则保持可区分。
- [ ] L6.9 审核全部例外；缺少 owner、风险、到期日、删除条件或超过默认期限的 waiver 不得进入严格模式，不可豁免规则不得建立例外。

## Phase 7 — 清零违规并开启严格 CI 门禁

- [ ] **Phase 7 完成**：本 Phase 下全部项目均已完成并附有证据。

- [ ] L7.1 子计划 1 完成后移除 `*.Abstractions` 兼容规则，并验证仓库不存在旧项目/namespace。
- [ ] L7.2 子计划 2 完成后开启 Integration Event 声明位置与 inbound Adapter 的严格规则。
- [ ] L7.3 将 CI 从“禁止新增违规”提升为“阻断全部未豁免违规”，记录切换条件和日期。
- [ ] L7.4 达到零未豁免违规后生成 B4 报告；用固定目标规则语义比较 B1/B2/B3/B4，并解释规则或 baseline 的每次变化。
- [ ] L7.5 为新模块模板预置 Contracts/Application/Adapters/Composition 的合规结构。
- [ ] L7.6 建立定期 waiver 审核和依赖图审查，防止配置与代码再次漂移。
- [ ] L7.7 由架构负责人确认严格模式、B1/B4 对比和零未豁免违规，并批准完成。
- [ ] L7.8 汇总最终规则矩阵、违规清零结果、waiver 状态及 Gate 03/05 输入，作为 Phase 8 文档来源。

## Phase 8 — 架构与规则文档化

- [ ] **Phase 8 完成**：本 Phase 下全部项目均已完成并附有证据。

- [ ] L8.1 编写完整中文规则说明，解释项目识别、ownership-aware 依赖、声明位置、框架泄漏和 waiver 规则。
- [ ] L8.2 编写与中文内容一致的英文规则说明，并建立双向链接。
- [ ] L8.3 保存目标编译期依赖矩阵和项目/模块 ownership 架构图。
- [ ] L8.4 保存从项目发现、项目图/源码分析、catalog reconciliation 到本地/CI 报告的检查流程图。
- [ ] L8.5 保存迁移模式到严格模式的状态图，标明启用条件、失败行为和 waiver 到期处理。
- [ ] L8.6 提供每条核心规则的正例、反例、诊断信息、修复方式和允许的最小例外。
- [ ] L8.7 说明 Gate 03 权威目录与 Gate 05 context/分类规则如何输入同一门禁，但保持失败责任可区分。
- [ ] L8.8 保存 Mermaid 源文件及可审阅的 SVG/PNG 渲染结果，并更新规则与架构索引。

## 完成标准（Definition of Done）

- [ ] L-D01 LayerGuard 能区分 own/foreign Contracts，并准确验证新架构矩阵。
- [ ] L-D02 Integration Adapter 的有限许可不会扩大为整个 Infrastructure 可访问 foreign Contracts。
- [ ] L-D03 所有核心规则均有通过与失败 fixture，错误报告可定位和修复。
- [ ] L-D04 CI 阻断新增和未豁免架构违规，扫描异常不能静默通过。
- [ ] L-D05 旧 `Abstractions` 兼容规则最终移除，仓库规则与目标文档一致。
- [ ] L-D06 所有 waiver 都可追责、会过期且有明确删除条件。
- [ ] L-D07 Contract/Event context 只能依赖 Gate 05 批准的 BCL-only primitives，运行时 HttpContext/Activity/Security/broker 类型不能泄漏进公共 schema 或 Application。
- [ ] L-D08 LayerGuard 与 Gate 05 Catalog/schema/security/runtime tests 分工清晰，任一门禁失败都不能由另一门禁的绿色结果掩盖。
- [ ] L-D09 中英文规则说明、依赖图、检查流程图、模式状态图及正反例完整且与门禁实现一致。
- [ ] L-D10 新版迁移门禁在其他代码改造前启用；B1/B4 使用相同目标规则语义并形成可复查的前后对比。
## G05 反向链接

03-A1 只绑定 G05 的项目/依赖/类型结构规则；字段分类、敏感值、传播和 replay 语义继续由 G03 catalog 与 G05 schema/runtime/security tests 负责。边界与回交要求见 [G05 双语设计](../gates/G05/context-sensitive-data-boundary.zh-CN.md)。
