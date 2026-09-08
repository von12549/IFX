# Contracts / Adapters / Events 架构改进总计划

> 状态：Master Phase 0、03-A1 / LG-POLICY-READY 已完成；Plan 01/02 可开始（2026-09-08）
> 范围：编译期边界、模块间同步契约、集成事件与 LayerGuard 规则
> 基线：[`../target-contracts-adapters-events.zh-CN.md`](../target-contracts-adapters-events.zh-CN.md)
> G03 治理基线：[中文](../gates/G03/contract-event-governance.zh-CN.md) / [English](../gates/G03/contract-event-governance.en.md)；权威事实仅来自 [catalog](../gates/G03/contract-event-catalog.yaml)。
> G04 运行基线：[中文](../gates/G04/deployment-runtime-boundary.zh-CN.md) / [English](../gates/G04/deployment-runtime-boundary.en.md)；[PRE-READY closeout](../evidence/gates/G04/G04-phase12-handoff.md) 未关闭 Gate，最终关闭依赖 E3/E4/E6、G05、L5.1/L5.2、生产演练与五方批准。
> G05 上下文与敏感数据基线：[中文](../gates/G05/context-sensitive-data-boundary.zh-CN.md) / [English](../gates/G05/context-sensitive-data-boundary.en.md)；repository conformance 不替代 Plan 01/02 真实载体、03-A1 或生产安全证据。
> 计划概述与审查结论：[`README.md`](README.md)
> 进度规则：只有当某项的实现、验证与必要文档证据均已完成时，才勾选该项；Phase 内全部项目完成后，才勾选 Phase。

## 目标

本计划把现有以 `*.Abstractions` 为中心的模块间依赖，演进为由提供方拥有的窄 `Contracts`、消费方拥有的 Application Port、位于消费方外层的 Integration Adapter，以及可靠的 Integration Event 通道。与此同时，LayerGuard 将从与代码不一致的静态约定，升级为可在 CI 中执行的新架构边界。

本计划不把 `Integration` 定义为新的业务层。它是 Infrastructure/外层中的适配器角色；只有当项目物理拆分能显著改善编译期约束时，才建立独立的 `*.Integration` 或 `*.Infrastructure.Integrations` 项目。

## 计划索引

| 子计划 | 负责范围 | 完成标志 |
| --- | --- | --- |
| [`00-prerequisites.md`](00-prerequisites.md) | Plan 00 前置的事务、数据库、治理、部署与数据规则 | 先完成 Gate 1–5 前置放行；子计划回交真实实现后再最终关闭 |
| [`00-G01-transaction-boundary.md`](00-G01-transaction-boundary.md) | Gate 1 本地事务、Result/异常语义、并发及 Outbox/Inbox 原子接缝 | TX1–TX5 的实现、测试与文档全部验收 |
| [`00-G02-database-boundary.md`](00-G02-database-boundary.md) | Gate 2 DbContext/schema ownership、独立 history、Migrator job 与真实数据库测试 | DB1–DB4、DB9–DB11 的实现、迁移和文档全部验收 |
| [`00-G03-contract-event-governance.md`](00-G03-contract-event-governance.md) | Gate 3 Contract/Event ownership、版本兼容、权威目录、共享原语与变更治理 | GOV1/GOV2/GOV5 的目录、门禁、测试与文档全部验收 |
| [`00-G04-deployment-runtime-boundary.md`](00-G04-deployment-runtime-boundary.md) | Gate 4 业务发布边界、API/Worker roles、多实例 lease、部署、探针与关闭 | DP1/DP3/DP4/DP5 的运行、演练、健康与文档全部验收 |
| [`00-G05-context-sensitive-data-boundary.md`](00-G05-context-sensitive-data-boundary.md) | Gate 5 Correlation/Causation/Tenant/Trace、Contract/Event context 与敏感数据治理 | OPS1/OPS3/OPS-G1 的上下文、分类、门禁、测试与文档全部验收 |
| [`03-layerguard-alignment.md`](03-layerguard-alignment.md) | 首先建立新版 LayerGuard、改造前基线和迁移门禁；最后清零并开启严格模式 | 新依赖矩阵可自动验证，并且仓库零未豁免违规 |
| [`01-contracts-adapters-refactor.md`](01-contracts-adapters-refactor.md) | `Abstractions` → `Contracts/Ports/Adapters`；Contracts 与 Application 职责；现有代码迁移 | Application 不再直接引用其他模块 Contracts；所有跨模块同步调用经消费方 Port 与 Adapter |
| [`02-reliable-integration-events.md`](02-reliable-integration-events.md) | Integration Event 契约、Outbox/Inbox、投递、重试与运维 | 提交后发布、至少一次投递、消费幂等、失败可恢复 |
| [`TODO.md`](TODO.md) | 本轮未展开的数据库、事务、部署等边界 | 转化为后续评审与实施计划 |

## 关键架构约束

- [x] M-C01 提供方拥有并版本化自己的公共 `Contracts`；Contracts 只表达模块能力和已发生的公共事实。
- [x] M-C02 提供方 Application 实现自身同步 Contract；模块 Composition 负责把实现注册到根 DI 容器。
- [x] M-C03 消费方 Application 只依赖自己定义的 Port，不直接引用其他模块的 Contracts。
- [x] M-C04 消费方的 Integration Adapter 位于外层，引用“自己的 Application Port + 提供方 Contracts”，并完成协议/模型转换。
- [x] M-C05 Presentation 是入站 HTTP Adapter，可以含路由、认证和协议映射；它与 Contracts 都不得包含业务规则或直接访问 DbContext。
- [x] M-C06 Domain Event 与 Integration Event 分离；Integration Event 是跨边界、可版本化、可重复投递的公共事实。
- [x] M-C07 ApiHost 仅承担组合根和宿主职责，不实现模块业务逻辑，也不代替模块实现 Contracts。
- [x] M-C08 每个模块保持自己的数据和本地事务边界；跨模块工作流不宣称共享 ACID 原子性。
- [x] M-C09 所有架构和规则设计完成后必须文档化，至少包含设计解释、架构图、关键流程图、失败/状态说明及规则到验证机制的映射。
- [x] M-C10 五个业务模块保持同一后端发布边界；同 release 的 API/Worker Runtime Roles 可独立扩容，但不能独立选择业务模块版本。
- [x] M-C11 业务关联、单次操作、直接因果、事件身份、W3C trace 和租户 scope 使用不同语义；所有入口由可信 Adapter 建立显式 ExecutionContext。
- [x] M-C12 Contract/Event 公共字段必须完成 C0-C4 分类和目的登记；C4 Secret 零暴露，普通日志/trace 不成为敏感数据旁路。

## 依赖与实施顺序

本计划使用四个控制点，既让新版分析能力先于 Gate 实施，又避免 Gate 的最终验收与下游实现形成循环依赖：

- **LG-BOOTSTRAP**：先建立不依赖 Gate artifact 的 LayerGuard Core、fixture、执行入口和 B0.5。
- **前置放行（Prerequisite Release）**：在 bootstrap 门禁保护下完成 Gate 的架构决策、阻塞性现存缺陷、协议接缝、ownership 和 conformance 要求。
- **LG-POLICY-READY**：将 Gate 输出绑定到完整目标规则，生成正式 B1；之后才开始 Contracts/Events 迁移。
- **最终关闭（Final Closure）**：原子子计划已把 Gate 规则应用到真实 Contracts、Outbox/Inbox、Dispatcher 和 LayerGuard，Gate 的全部 Phase/DoD 与文档证据完成。

Gate Plan 是总计划的一部分，不是与原子子计划平行维护的第二份实现 backlog。涉及真实 Contract/Event 的代码只在对应原子子计划实施，Gate Plan 负责规则、前置基础和最终验收。

```text
子计划 3-A0：LayerGuard Core + B0.5 bootstrap 检查
      |
      v
Gate 1-5 决策 + 阻塞基础 + conformance 要求
      |
      v
前置放行（PRE-READY）
      |
      v
子计划 3-A1：绑定 Gate policy + 正式 B1 + 禁止新增违规
      |
      v
子计划 1：Contracts / Ports / Adapters --> B2 检查
      |
      v
子计划 2：事件契约 + Outbox / Inbox --> B3 检查
      |
      v
子计划 3-B：违规清零 + 严格模式 + B4 前后对比
      |
      v
Gate 1-5 最终关闭 + 总体验收
```

## LayerGuard Bootstrap 准入门槛

- [x] M-BOOT 在 Gate 01 实施前完成子计划 3 的 Phase 0–4：保留 B0、建立新引擎/角色/规则/fixture/执行入口、生成 B0.5，并对不依赖 Gate artifact 的确定性规则阻断新增违规。证据：[`../evidence/03-a0-layerguard-bootstrap.md`](../evidence/03-a0-layerguard-bootstrap.md)。

## Plan 00 Gate 准入门槛

- [x] M-PRE 在 M-BOOT 后完成 [`00-prerequisites.md`](00-prerequisites.md) 的 Gate 1–5 前置放行和 PRE-READY 验收；随后执行 03-A1，Gate 最终关闭可依赖原子子计划的真实实现证据，但必须在总计划最终验收前完成。证据：[`../evidence/plan00-prerequisite-release.md`](../evidence/plan00-prerequisite-release.md)。

## Phase 0 — 建立基线与冻结架构决策

- [x] **Phase 0 完成**：本 Phase 下全部项目均已完成并附有证据。

- [x] M0.1 对现有项目引用、跨模块接口、DI 注册、事件发布者和处理器生成可复查清单，并保存基线证据。
- [x] M0.2 评审并确认上方 M-C01 至 M-C12；确认记录：[`../evidence/plan00-phase0-architecture-decisions.md`](../evidence/plan00-phase0-architecture-decisions.md)。
- [x] M0.3 采用渐进式物理命名迁移：先建立 `*.Contracts` 项目/兼容 namespace 与最小 shim，逐项迁移消费者后，在 Plan 01 Phase 6 删除 `*.Abstractions` 与过期 shim；不执行不可分割的一次性全仓重命名。
- [x] M0.4 Integration Adapter 初期保留在消费方 `Infrastructure/Integrations/<Provider>`；仅当数量、技术栈或独立部署约束显著增加且有批准记录时拆为独立项目，两种形态均由 LayerGuard 精确识别。
- [x] M0.5 为三份子计划指定负责人、目标里程碑和验收人，并确认数据库/事务前置项的负责人。责任矩阵与接受记录：[`../evidence/plan00-phase0-architecture-decisions.md`](../evidence/plan00-phase0-architecture-decisions.md)。
- [x] M0.6 记录 Gate 前置放行后的构建、事务/migration 测试与 B0.5 结果，作为 03-A1 和后续“无回归”输入；正式架构差异仍以 B1/B4 为准。证据：[`../evidence/plan00-prerequisite-release.md`](../evidence/plan00-prerequisite-release.md)。

### M0.5 责任矩阵

| 工作流 | Delivery owner | 目标里程碑 | 验收人 |
| --- | --- | --- | --- |
| Plan 03 — LayerGuard policy binding | `@von12549` | 03-A1 / 正式 B1 | Junxi (`@jimkeecn`) |
| Plan 01 — Contracts / Ports / Adapters | `@von12549` | B2 | Junxi (`@jimkeecn`) |
| Plan 02 — Reliable Integration Events | `@von12549` | B3 | Junxi (`@jimkeecn`) |
| G01/G02 事务与数据库回交 | `@von12549` | Plan 02 E2/E4 回交并通过 G01/G02 conformance | Junxi (`@jimkeecn`) |

上述验收职责已于 2026-09-08 被接受。这里的验收人负责子计划里程碑验收；Gate Final Closure
仍须满足各 Gate 已定义的多角色批准，不因本矩阵而降级为单人批准。

## Phase 1 — 绑定 Gate Policy 并建立正式 B1 基线

- [x] **Phase 1 完成**：本 Phase 下全部项目均已完成并附有证据。证据：[`../evidence/03-a1-layerguard-policy-binding.md`](../evidence/03-a1-layerguard-policy-binding.md)。

- [x] M1.1 子计划 3 Phase 5 已把 Gate 03 ownership/catalog/allowlist、Gate 04 Runtime Role 和 Gate 05 context policy 绑定到规则能力。
- [x] M1.2 LayerGuard 与 Gate validator 职责已分离：静态依赖/声明由 LayerGuard，字段、值、传播和运行行为由专用 tests 检查。
- [x] M1.3 已在 Contracts/Events 改造前代码上运行完整目标规则，并生成按 44 条真实依赖边聚类的正式 B1。
- [x] M1.4 B1 已保存工具版本、目标规则、组合 policy hash、12 个 Gate artifact/hash、运行参数语义与性能结果。
- [x] M1.5 完整迁移门禁已接入 CI：受控 B1 暂存历史 finding，新增/陈旧 finding、未知 role、扫描异常、hash 漂移和不合法 waiver 均失败。
- [x] M1.6 B0/B0.5 保留为工具演进证据；正式架构改造前后比较固定使用 B1/B4 的相同目标规则语义。

## Phase 2 — 建立 Contracts / Ports / Adapters 编译期边界

- [ ] **Phase 2 完成**：本 Phase 下全部项目均已完成并附有证据。

- [ ] M2.1 以 Gate 03 权威目录、ownership、V1 identity/shared primitives allowlist，以及 Gate 05 ContractRequestContext、ExecutionScope 和字段分类为输入，执行子计划 1 的迁移。
- [ ] M2.2 优先迁移当前真实同步依赖：CRM 的 KYC 校验与 Registry 的 Class subscription 状态查询。
- [ ] M2.3 清除 Transaction.Application 对 CRM/Registry Contracts 的直接项目引用，并用依赖图验证。
- [ ] M2.4 清理未被生产代码消费的公共 Reader，避免为了假想扩展面继续暴露公共查询模型。
- [ ] M2.5 分离 Application 内部 DTO 与公共 Contract DTO，按 capability 最小化字段并应用 Gate 05 C0-C4 分类，防止公共模型成为内部用例模型或敏感数据捷径。
- [ ] M2.6 完成子计划 1 的单元、DI、集成和架构测试，使用同一新版门禁生成 B2 报告并与 B1 对比后，勾选本 Phase。

## Phase 3 — 建立可靠 Integration Event 通道

- [ ] **Phase 3 完成**：本 Phase 下全部项目均已完成并附有证据。

- [ ] M3.1 以 Gate 03 事件目录/版本政策和 Gate 05 Event Envelope、Correlation/Causation/Tenant/Trace、字段分类为输入，执行子计划 2；schema primitives 与运行时端口保持分离。
- [ ] M3.2 实现生产方本地事务内“业务数据 + Outbox”原子保存，移除提交前直接发布路径。
- [ ] M3.3 按 Gate 04 Worker role、唯一 instance identity 和多实例 claim/lease 规则实现提交后 Dispatcher、重试和失败状态，并保留可替换 transport 的边界。
- [ ] M3.4 将外部事件处理从消费方 Application 移入入站 Integration Adapter；Adapter 先验证 producer/schema/tenant/context，再建立隔离的 ExecutionContext 并映射为内部命令。
- [ ] M3.5 实现 Inbox 去重及“消费方业务数据 + Inbox”本地原子保存。
- [ ] M3.6 完成崩溃窗口、重复投递、毒消息、上下文传播/隔离、敏感字段、回放和端到端测试，使用同一新版门禁生成 B3 报告并与 B2 对比后，勾选本 Phase。

## Phase 4 — 收紧 LayerGuard 并形成 CI 门禁

- [ ] **Phase 4 完成**：本 Phase 下全部项目均已完成并附有证据。

- [ ] M4.1 执行子计划 3-B，修复 B3 中的剩余违规，但不得通过放宽 B1 已冻结的目标规则制造绿色结果。
- [ ] M4.2 移除迁移期针对 `*.Abstractions` 的兼容许可，并禁止新建同类项目/namespace。
- [ ] M4.3 将 Contracts 禁止依赖业务/基础设施框架、Application 禁止外部 Contracts、Adapter 依赖方向等规则设为阻断级别。
- [ ] M4.4 验证直接和传递依赖、项目引用与 namespace 声明均无法绕过规则。
- [ ] M4.5 在标准 CI 路径中启用严格 LayerGuard，生成零未豁免违规的 B4 报告，并与 B1/B2/B3 形成可审查前后对比。
- [ ] M4.6 保持门禁职责清晰：LayerGuard 验证引用/声明/框架泄漏，Gate 03/05 catalog 与 schema/security/runtime tests 验证字段、值和传播语义。

## Phase 5 — 收尾、发布与架构验收

- [ ] **Phase 5 完成**：本 Phase 下全部项目均已完成并附有证据。

- [ ] M5.1 删除已废弃的接口、DTO、注册代码、兼容 shim 与旧事件直发代码，确认无生产引用。
- [ ] M5.2 更新架构图、模块开发指南、Contract/Event 版本策略、上下文/敏感数据规则和故障处理手册。
- [ ] M5.3 对所有模块执行完整构建、测试、LayerGuard 和关键业务回归，并保存结果。
- [ ] M5.4 审核 `TODO.md`：将阻塞当前验收的剩余事项完成或转为具备负责人和时间点的正式计划，已提取事项不得重复维护。
- [ ] M5.5 由架构与模块负责人共同确认 Definition of Done，并记录最终偏差或临时豁免的到期日。
- [ ] M5.6 按 Gate 04 顺序演练 Migrator → Worker consumers → API producers → schedules → cleanup，并验证 probes、drain、backpressure 和安全回退。

## 总体验收标准（Definition of Done）

- [ ] M-D01 代码中的项目引用图与目标架构图一致，且由自动化规则验证。
- [ ] M-D02 Contracts 不含业务逻辑、DbContext、Repository、Handler、DI 注册或传输实现。
- [ ] M-D03 所有跨模块同步读取均通过消费方 Port 和外层 Adapter，能够替换为 HTTP/gRPC Adapter 而不改消费方 Application。
- [ ] M-D04 所有跨模块事件均在源事务提交后投递，支持重复投递且消费幂等。
- [ ] M-D05 ApiHost 仅加载模块 Composition；模块负责实现和注册自身能力。
- [ ] M-D06 `dotnet build`、相关 `dotnet test` 与 LayerGuard 在 CI 中全部通过。
- [ ] M-D07 所有临时兼容与规则豁免均有 owner、原因、到期日和删除条件。
- [ ] M-D08 各 Gate 和子计划均已交付并审核中英文设计说明、架构图、流程图及必要状态图，文档与最终代码和自动化规则一致。
- [ ] M-D09 Contract/Event 权威目录与源码、API/schema 快照、依赖图和 LayerGuard 保持一致，所有 Active 协议均有唯一 owner 和真实 consumer。
- [ ] M-D10 API/Worker roles、多实例 Dispatcher、role-specific readiness、优雅关闭与 consumer-first 发布均通过自动化或受控演练。
- [ ] M-D11 HTTP、job、同步 Contract 与 Event consumer 使用统一且隔离的 ExecutionContext，Correlation/Causation/Tenant/Trace 传播和失败语义通过测试。
- [ ] M-D12 所有 Active Contract/Event 字段完成 C0-C4 分类和目的登记；C4 零暴露，日志/trace/error/health 无未批准敏感信息。

## 风险与回退原则

- [ ] M-R01 每次只迁移一条可观察的模块依赖边，保留可快速切回旧 Adapter 的组合根开关，避免大爆炸式切换。
- [ ] M-R02 公共 Contract/Event 的破坏性变化采用并行版本或适配转换，不通过共享内部 Domain 类型规避版本问题。
- [ ] M-R03 Outbox/Inbox 上线前完成数据库 migration、部署顺序与旧实例兼容验证。
- [ ] M-R04 严格 LayerGuard 规则先验证真实代码可达，再从报告模式提升为阻断模式。
- [ ] M-R05 任何回退都不得绕过审计：记录被恢复的旧路径、回退原因和再次切换条件。
- [ ] M-R06 Context/schema 兼容只能通过有 owner 和到期日的显式 Adapter；不得恢复默认租户、全局补值或明文敏感日志。
- [ ] M-R07 B0.5 不作为正式改善基准；B1 与 B4 必须使用相同的目标规则语义。若工具或规则必须修正，应重跑受影响基线并记录原因，禁止用规则漂移伪造改善。
