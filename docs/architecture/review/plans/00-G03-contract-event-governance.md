# Plan 00 / Gate 03：Contract / Event Ownership 治理实施计划

> 状态：Architecture Decisions Approved / 待实施
> 上级前置计划：[`00-prerequisites.md`](00-prerequisites.md)
> 上级总计划：[`00-master-plan.md`](00-master-plan.md)
> 工具前置：[`03-layerguard-alignment.md`](03-layerguard-alignment.md) 03-A0 已完成；本 Gate 产出的 catalog/graph/allowlist/waiver policy 在 03-A1 绑定为权威规则输入。
> 字段与上下文规则：[`00-G05-context-sensitive-data-boundary.md`](00-G05-context-sensitive-data-boundary.md) 已确认 Correlation/Causation/Tenant/Trace、Envelope/Contract context 与 C0-C4 分类；本 Gate 负责在权威目录中承载并验证。
> 范围：GOV1、GOV2、GOV5，以及同步 Contract、Integration Event、共享契约原语和变更治理所需的准入规则
> 前置放行：catalog/owner/consumer/identity/compatibility/allowlist 可供子计划使用；真实 V1 schema 迁移后回交 Active/Retired 证据
> Gate 关闭条件：本计划全部 Phase、Definition of Done 和文档交付均已完成

## 目标

为 IFX 建立单一、可追踪、可自动验证的 Contract/Event 治理体系：每项公共能力和事件都有唯一 Provider owner、真实 Consumer、稳定 identity、生命周期与兼容策略；消费方通过自己的 Application Port 和外层 Adapter 使用提供方协议；公共 Contracts 只依赖最小共享原语；现有未被消费的 `Abstractions` 表面被明确归类并进入内化、替换或删除路径。

本 Gate 负责先建立治理事实、版本基线、审批流程和自动化接缝。具体的 Reader/DTO 迁移由 [`01-contracts-adapters-refactor.md`](01-contracts-adapters-refactor.md) 实施，可靠 Outbox/Inbox 与 Event transport 由 [`02-reliable-integration-events.md`](02-reliable-integration-events.md) 实施，完整编译期依赖规则由 [`03-layerguard-alignment.md`](03-layerguard-alignment.md) 实施。

## 非目标

- [ ] G03-N01 不在本 Gate 完成全部 `*.Abstractions` → `*.Contracts` 代码迁移或删除遗留类型。
- [ ] G03-N02 不在本 Gate 实现 Outbox、Inbox、Dispatcher、broker、dead-letter 或 replay。
- [ ] G03-N03 不在本 Gate 重新定义 Gate 05 已批准的 Correlation/Operation/Causation/Tenant/Trace 与敏感字段 schema；只负责治理登记、ownership 和变更控制。
- [ ] G03-N04 不因当前为单一 ApiHost 而引入 localhost HTTP，也不把 Contracts 当成可独立执行的服务。
- [ ] G03-N05 不建立承载跨模块业务模型、通用 `Result<T>` 或 Domain 类型的 SharedKernel。

## 当前实现基线

| 事实 | 当前证据 | 风险 |
| --- | --- | --- |
| 四个模块存在 `*.Abstractions` | CRM、Registry、Holdings、Transaction | 名称无法表达同步协议、事件 schema 与内部模型的不同职责 |
| 公共 Reader 表面偏大 | 4 个 Reader、15 个方法 | 只有 CRM KYC 与 Registry subscription availability 两个方法存在真实跨模块调用 |
| 公共 DTO 与内部 DTO 混用 | 7 个 Abstractions DTO；Holdings Application 直接复用公共 DTO | 内部用例变化会无意扩大公共兼容责任 |
| 事件表面缺少消费者约束 | 20 个 Integration Event 类型 | 只有 `TransactionProcessed` 与 `ClassStatusChanged` 存在已注册跨模块消费者 |
| 存在孤立事件 | `HoldingFrozenEvent` 没有发现生产者或消费者 | 预设契约可能长期占据公共表面而无人负责 |
| Consumer Application 直接引用 Provider Abstractions | Transaction → CRM/Registry；Holdings → Registry/Transaction | 提供方协议变化直接污染消费方核心层 |
| 消息契约与运行时端口混放 | `IFX.Platform.Messaging.Abstractions` 同时含 event base、bus、handler 和 DI package | 模块 Contracts 会被迫依赖运行时机制与框架包 |
| 无正式兼容基线 | 未发现公共 API snapshot、serialization golden files 或 contract catalog | 同仓库编译通过不能证明 wire/schema 兼容 |
| LayerGuard 尚不认识目标角色 | 只识别四个传统 ring，且不会自动在 CI 运行 | ownership、Adapter 许可和 Contract allowlist 不能执行 |

基线盘点必须排除 `bin/obj` 生成文件，并将“代码中发布”与“存在真实消费者”分别统计。

## 已确认架构决策

### Ownership 与公共表面

- [x] G03-D01 每项公共 Contract 和 Integration Event 只有一个 owner，即业务能力或事实所属的 Provider Module。
- [x] G03-D02 Provider 拥有 Provider Contract；Consumer 拥有自己的 Application Port 与 Integration Adapter，三者不能合并为一个共享抽象。
- [x] G03-D03 新增公共表面必须记录 owner、真实 consumer、业务用例、通信方式、tenant/授权、错误、新鲜度、版本和废弃方式；假想需求不能作为准入理由。
- [x] G03-D04 Contracts 只允许能力接口、专用 Request/Response、Integration Event schema 和必要公开值；禁止业务、持久化、DI、handler、transport 与内部模型。
- [x] G03-D05 同步接口按业务能力发布，不继续扩张通用 `Reader` 或跨模块 Repository。
- [x] G03-D06 当前仅将 CRM account compliance 与 Registry class subscription availability 视为真实同步能力；其余 Reader/DTO 默认内化，除非 consumer audit 提供证据。
- [x] G03-D07 Integration Event schema 由事实生产模块拥有；Consumer 只拥有 subscription、Inbox、入站 Adapter、内部映射与幂等处理。
- [x] G03-D08 当前仅将 `TransactionProcessed` 与 `ClassStatusChanged` 视为已证实的跨模块事件；其余事件进入 consumer audit，`HoldingFrozenEvent` 需判定遗漏发布还是移除。

### 版本、兼容与变更

- [x] G03-D09 现有 `*.Abstractions` 尚非正式兼容基线；首次目标迁移可原子更新仓库内 producer/consumer。`*.Contracts.V1` 快照批准后启用严格兼容治理。
- [x] G03-D10 版本属于具体同步协议或事件，不依赖整个程序集版本；首次正式版本为 V1，sync/event 可独立演进，当前无需先发布 NuGet。
- [x] G03-D11 所有公共变化分类为 Compatible、Conditional、Breaking 或 Internal；字段删除/改名/类型或语义改变、required 增加、接口破坏及事件事实/时点改变默认为 Breaking。
- [x] G03-D12 optional 扩展只有在 C# 构造、序列化、unknown value fallback 和 consumer 测试均安全时才是 Compatible。
- [x] G03-D13 Breaking change 发布并行 V+1；Provider 同时支持旧/新版本，Consumer 迁移并提供无旧流量证据后才能删除旧版。
- [x] G03-D14 默认废弃窗口至少为两个成功生产发布和 30 个自然日，并须完成全部 consumer 迁移、零旧流量观察以及 backlog/dead-letter/replay 检查，以最晚条件为准。
- [x] G03-D15 新增、Conditional、Breaking、envelope/shared primitive 和 Retire 分别要求 Provider、受影响 Consumer、Platform/架构角色按影响共同批准；ApiHost 不是业务 owner。
- [x] G03-D16 每次公共变化必须有 Contract Change Record；Breaking change 必须形成 ADR 或版本迁移文档。
- [x] G03-D17 正式基线至少包含 public API snapshot、serialization golden snapshot、Provider contract tests 和 Consumer compatibility tests。

### 目录、共享原语与自动化

- [x] G03-D18 在 `docs/architecture/review/gates/G03/contract-event-catalog.yaml` 建立唯一机器可读 source of truth；中英文文档不复制维护独立事实。
- [x] G03-D19 每个公共协议使用独立于 CLR 类型名的全局唯一稳定 identity；Active 后不得改名/复用，Retired identity 永久保留历史。
- [x] G03-D20 将 BCL-only、transport-neutral 的 `IFX.Platform.Messaging.Contracts` 与 bus、handler、dispatcher、DI、serializer、broker 等运行时端口/实现分离。
- [x] G03-D21 Contracts 默认只依赖 BCL；同步 metadata 与消息 schema 可分别依赖 Gate 05 批准的 Context.Contracts 与 Messaging.Contracts。共享 primitive 需满足三模块同义复用或统一基础设施协议的必要性。
- [x] G03-D22 生命周期采用 Proposed → Active → Deprecated → Retired；迁移期只允许有 owner、计划和到期日的 `LegacyPendingMigration`，且不得用于新增类型。
- [x] G03-D23 Consumer 分为 internal-module、external-service、external-client；外部 consumer 必须登记 owner/contact、版本、证据和最后确认日期。
- [x] G03-D24 由目录生成依赖图；禁止同步环，事件反馈环必须有 workflow identity、causation、幂等和终止条件，混合环必须评审。
- [x] G03-D25 使用 catalog、source reconciliation、API/schema snapshot、contract tests、LayerGuard 与 ownership approval 组成分层门禁，并分阶段从基线模式提升为严格模式。
- [x] G03-D26 变更必须在同一变更集中更新协议、catalog、Change Record 与测试，依次经过自动检查、Provider/Consumer 审批、发布与观察。
- [x] G03-D27 waiver 必须有 owner、风险、创建/到期时间和删除条件，默认不超过 90 天或命名里程碑；无 owner/consumer、内部模型泄漏、C4 或未批准 C3 暴露和 identity 复用不可豁免。
- [x] G03-D28 Gate 交付中英文说明、inventory/ownership 矩阵、依赖/生命周期/变更/版本图、模板、验证映射和 Mermaid + SVG/PNG。
- [x] G03-D29 Gate 关闭前必须完成全量分类、Active consumer 证据、权威目录验证、共享原语 allowlist、兼容快照、waiver expiry 门禁及文档审核。

## 初始 Ownership 与真实依赖

### 模块业务与数据 Ownership

| Module | 业务能力与事实 ownership |
| --- | --- |
| Auth | 身份、认证主体、凭据和外部身份映射 |
| CRM | Party、Investor、Investment Account、KYC/compliance |
| Registry | Product、Fund、Fund Class、subscription status |
| Transaction | Order、Transaction 及处理生命周期 |
| Holdings | Holding、position、持仓冻结状态 |

### 已证实的目标公共关系

| Identity 候选 | 方式 | Provider | Consumer | 当前用途 | Gate 初始结论 |
| --- | --- | --- | --- | --- | --- |
| `crm.account-compliance.v1` | Sync | CRM | Transaction | 创建订单/交易前取得账户 KYC 事实 | 建立正式 V1 候选 |
| `registry.class-subscription-availability.v1` | Sync | Registry | Transaction | 创建申购/转入前取得 Class 可申购事实 | 建立正式 V1 候选 |
| `ifx.transaction.transaction-processed.v1` | Event | Transaction | Holdings | 交易处理后更新持仓 | 建立正式 V1 候选 |
| `ifx.registry.class-status-changed.v1` | Event | Registry | Holdings | Class 状态关闭后冻结持仓 | 建立正式 V1 候选 |

Identity、业务语义和字段只有在 Phase 2/3 完成审核和测试后才能从 Proposed 提升为 Active。

### 遗留分类起点

| 范围 | 初始状态 | 必须完成的判断 |
| --- | --- | --- |
| `IHoldingsReader`、`ITransactionReader` | LegacyPendingMigration | 删除、内部化或由真实 consumer 证明新的窄能力 |
| CRM/Registry Reader 其余方法与 Summary DTO | LegacyPendingMigration | 从公共面移除或为命名 consumer 建立能力 Contract |
| 除两个已证实事件外的现有事件 | LegacyPendingMigration | 外部 consumer 证明、内部事件重分类或删除 |
| `HoldingFrozenEvent` | LegacyPendingMigration / orphan | 补齐真实发布/消费业务用例，否则删除 |
| Holdings/Transaction 内部复用公共 DTO | LegacyPendingMigration | 替换为 Application-owned models |

## 目标治理关系

```text
                    contract-event-catalog.yaml
                       single source of truth
                                  |
          +-----------------------+------------------------+
          |                       |                        |
          v                       v                        v
  ownership/change review   catalog reconciliation   dependency graph
          |                       |                        |
          +-----------+-----------+------------+-----------+
                      |                        |
                      v                        v
             API/schema snapshots         LayerGuard
                      |                        |
                      +-----------+------------+
                                  |
                                  v
                         CI admission decision
```

## Contract 生命周期

```text
Proposed --owner + consumer + tests--> Active
   |                                  |
   | rejected/internalized            | replacement announced
   v                                  v
Internal/Removed                 Deprecated
                                      |
                       2 releases + 30 days + all migrated
                         + zero traffic/backlog evidence
                                      |
                                      v
                                   Retired

LegacyPendingMigration --named plan + expiry--> Active / Internal / Removed
```

## 变更评审流程

```text
Author updates protocol + catalog + Change Record + tests
                              |
                              v
             catalog / API / serialization checks
                              |
                              v
                     Provider owner review
                              |
                              v
                  affected Consumer reviews
                              |
                   +----------+----------+
                   |                     |
              Compatible             Breaking
                   |                     |
              same version          parallel V+1
                   |                     |
                   +----------+----------+
                              |
                     deploy and observe
                              |
                     deprecate / retire
```

## Phase 0 — 建立可复查基线

- [x] **Phase 0 完成**：公共源码、运行路径、消费者和现有治理能力已形成可重复生成的基线。

- [x] G03-0.1 枚举所有 `*.Abstractions` 项目、公开类型、方法、DTO、事件、继承关系和 package/project references，排除生成目录。
- [x] G03-0.2 分别扫描每个同步方法的调用者，以及每个事件的声明、发布、subscription 和 handler，禁止把 producer 自用视为 consumer 证据。
- [x] G03-0.3 保存当前项目引用图和源码 namespace 图，突出 Transaction.Application 与 Holdings.Application 的 foreign Abstractions 依赖。
- [x] G03-0.4 盘点已有 owner、CODEOWNERS/审批、API diff、serialization snapshot、schema registry 和 CI 能力，记录缺口。
- [x] G03-0.5 为所有外部/动态消费者建立调查路径；找不到源码的 consumer 只有提供系统、owner、版本和接入证据后才成立。
- [x] G03-0.6 将基线脚本、输入范围、commit SHA、生成时间和结果保存为可重现证据。

Phase 0 证据：[`G03-phase0-baseline.md`](../evidence/gates/G03/G03-phase0-baseline.md)、
[`G03-contract-event-inventory.json`](../evidence/gates/G03/G03-contract-event-inventory.json)、
[`G03-phase0-guard-report.json`](../evidence/gates/G03/G03-phase0-guard-report.json) 与
[`G03-phase0-layerguard-report.json`](../evidence/gates/G03/G03-phase0-layerguard-report.json)。

## Phase 1 — 建立模块能力、数据与消费目录

- [x] **Phase 1 完成**：所有模块、能力、数据事实和跨模块关系均有明确 owner 与来源证据。

- [x] G03-1.1 创建 `docs/architecture/review/gates/G03/contract-event-catalog.yaml` schema 与 validator，定义 module、capability、contract、event、consumer、version、lifecycle 和 waiver 节点。
- [x] G03-1.2 登记 Auth、CRM、Registry、Transaction、Holdings 的业务能力、数据 ownership 和负责角色；owner 必须能解析到真实维护者，不允许占位符。
- [x] G03-1.3 登记同步 provider → consumer、事件 producer → consumer、Adapter/subscription 和相应业务用例。
- [x] G03-1.4 按 Gate 05 登记 execution scope、授权、新鲜度、失败语义、字段 C0-C4、purpose、retention、log policy、例外和测试位置；不得保留“待定”猜测值进入 Active。
- [x] G03-1.5 为 external-service/client consumer 记录 owner/contact、supported version、接入证据和 last-confirmed-at（当前无已证实 external consumer；schema 与 validator 已强制其必填证据）。
- [x] G03-1.6 从目录生成模块依赖图并检查 sync、async 与 mixed cycles；不允许手工维护第二份关系图数据。
- [x] G03-1.7 为 catalog schema、唯一 identity、合法状态转换、必填 owner/consumer 和引用完整性建立测试。

Phase 1 证据：[`contract-event-catalog.yaml`](../gates/G03/contract-event-catalog.yaml)、
[`contract-event-catalog.schema.json`](../gates/G03/contract-event-catalog.schema.json)、
[`G03-phase1-catalog-report.json`](../evidence/gates/G03/G03-phase1-catalog-report.json)、
[`G03-phase1-guard-report.json`](../evidence/gates/G03/G03-phase1-guard-report.json) 与
[`G03-phase1-layerguard-report.json`](../evidence/gates/G03/G03-phase1-layerguard-report.json)。

## Phase 2 — 全量分类现有公共表面

- [x] **Phase 2 完成**：每个现有 Reader、方法、DTO 和 Event 均有明确目标状态、owner、consumer 证据或迁移承诺。

- [x] G03-2.1 将 account compliance 与 class subscription availability 登记为 Proposed V1 同步能力，明确 Provider/Consumer 和业务语义边界。
- [x] G03-2.2 将 `TransactionProcessed` 与 `ClassStatusChanged` 登记为 Proposed V1 Integration Event，明确事实发生时点与 Holdings 消费用例。
- [x] G03-2.3 对其余 Reader 方法和 DTO 逐项判定 Active candidate、Internalize、Replace 或 Remove；不以程序集公开性替代业务准入。
- [x] G03-2.4 对其余事件逐项核实真实 consumer；无证据者标记 LegacyPendingMigration 并关联 Event 子计划处置项。
- [x] G03-2.5 对 `HoldingFrozenEvent` 形成明确结论：当前无 producer/consumer，进入 Plan 02 删除路径。
- [x] G03-2.6 为所有 LegacyPendingMigration 项记录 owner、目标状态、执行计划、到期日和删除条件，禁止新增此状态。
- [x] G03-2.7 生成当前/目标 inventory diff 与 public surface burn-down 基线。

Phase 2 证据：[`G03-phase2-report.md`](../evidence/gates/G03/G03-phase2-report.md)、
[`G03-phase2-catalog-report.json`](../evidence/gates/G03/G03-phase2-catalog-report.json)、
[`G03-phase2-guard-report.json`](../evidence/gates/G03/G03-phase2-guard-report.json) 与
[`G03-phase2-layerguard-report.json`](../evidence/gates/G03/G03-phase2-layerguard-report.json)。

## Phase 3 — 建立 Identity、版本与兼容政策

- [x] **Phase 3 完成**：所有 Active candidate 都有稳定 identity、版本、兼容矩阵、生命周期与 Change Record。

- [x] G03-3.1 冻结 sync/event identity 命名规范、namespace/version 映射和 Retired identity 保留规则。
- [x] G03-3.2 为 Compatible、Conditional、Breaking 和 Internal 建立逐项判定矩阵，覆盖字段、requiredness、类型、语义、错误码、接口方法和事件产生时点。
- [x] G03-3.3 定义 DTO 设计规则：optional 扩展不破坏 C# 构造；Consumer 容忍未知字段和值；公共状态具有受控 fallback。
- [x] G03-3.4 定义 Breaking V+1 并行支持、Adapter 切换、双版本观测与旧版删除流程。
- [x] G03-3.5 将默认废弃条件编码为可检查政策：两个生产发布、30 天、全部 consumer 迁移、零旧流量，以及无待处理旧 schema 消息。
- [x] G03-3.6 创建 Contract Change Record 与 Breaking migration/ADR 模板，并验证必填字段。
- [x] G03-3.7 明确首次 `Abstractions` cutover 与正式 V1 baseline marker；基线后禁止无版本的静默破坏。

Phase 3 证据：[`compatibility-policy.md`](../gates/G03/compatibility-policy.md)、
[`templates/contract-change-record.md`](../gates/G03/templates/contract-change-record.md)、
[`templates/breaking-version-migration.md`](../gates/G03/templates/breaking-version-migration.md)、
[`G03-phase3-report.md`](../evidence/gates/G03/G03-phase3-report.md)、
[`G03-phase3-guard-report.json`](../evidence/gates/G03/G03-phase3-guard-report.json) 与
[`G03-phase3-layerguard-report.json`](../evidence/gates/G03/G03-phase3-layerguard-report.json)。

## Phase 4 — 收敛共享 Contract Primitives

- [x] **Phase 4 完成**：Contracts 的依赖 allowlist 足够小、transport-neutral，并与运行时消息端口彻底分离。

- [x] G03-4.1 盘点 `IFX.Platform.Messaging.Abstractions` 的 schema 类型、bus、handler、DI/package dependency 和现有引用者。
- [x] G03-4.2 设计 BCL-only `IFX.Platform.Messaging.Contracts`，只承载 marker/schema identity 与 Gate 05 批准后的 envelope/value primitives。
- [x] G03-4.3 将 `IIntegrationEventBus`、`IIntegrationEventHandler<T>`、dispatcher、serializer、broker、DI 和可靠性实现明确留在运行时项目。
- [x] G03-4.4 建立 Contract project dependency allowlist：BCL 默认允许；Context.Contracts 仅对调用 metadata、Messaging.Contracts 仅对事件 schema 允许；其他依赖默认拒绝。
- [x] G03-4.5 建立 shared primitive 准入测试：三模块完全同义复用或统一协议必要性、稳定 owner、序列化定义和兼容政策缺一不可。
- [x] G03-4.6 明确禁止 `Result<T>`、Domain/Security/Application types、EF/MediatR/ASP.NET/DI/serializer/broker SDK 和泛化 SharedKernel。
- [x] G03-4.7 将物理拆分实现交付给 Contracts/Event 子计划，并提供保持 build green 的迁移顺序。

Phase 4 证据：[`shared-contract-primitives.md`](../gates/G03/shared-contract-primitives.md)、
[`G03-phase4-report.md`](../evidence/gates/G03/G03-phase4-report.md)、
[`G03-phase4-guard-report.json`](../evidence/gates/G03/G03-phase4-guard-report.json) 与
[`G03-phase4-layerguard-report.json`](../evidence/gates/G03/G03-phase4-layerguard-report.json)。

## Phase 5 — 建立 Ownership 与变更审批机制

- [ ] **Phase 5 完成**：每类变更都有可执行审批路径，Provider 与 Consumer 责任清晰且不会转移给 ApiHost。

- [ ] G03-5.1 为每个模块和 Platform Messaging 指定真实 owner/backup owner，并映射到仓库实际审批能力。
- [x] G03-5.2 定义新增、Compatible、Conditional、Breaking、shared primitive/envelope、Deprecated 和 Retired 所需 reviewer 集合。
- [x] G03-5.3 确保任何 Active contract/event 至少由 Provider 与首个 Consumer 双方批准。
- [x] G03-5.4 将 Change Record 纳入 PR 流程；Breaking change 无 ADR/迁移计划、发布顺序和回退路径时不得合并。
- [x] G03-5.5 建立 consumer confirmation 与定期复核机制，外部 consumer 的 last-confirmed-at 过期后触发告警而非静默删除。
- [x] G03-5.6 建立紧急安全/监管变更路径，要求显式影响清单、协调发布和事后 ADR，不允许借紧急名义复用 identity。

Phase 5 当前为 PRE-READY：[`G03-phase5-pre-ready.md`](../evidence/gates/G03/G03-phase5-pre-ready.md)、
[`ownership-and-change-approval.md`](../gates/G03/ownership-and-change-approval.md)、
[`G03-phase5-guard-report.json`](../evidence/gates/G03/G03-phase5-guard-report.json) 与
[`G03-phase5-layerguard-report.json`](../evidence/gates/G03/G03-phase5-layerguard-report.json)。仓库证据只解析出一位
当前维护者，不能虚构独立 backup owner；须在首次 Proposed → Active 或 Gate 关闭前由 repository owner 指定并回访。

## Phase 6 — 建立兼容性与目录自动化

- [ ] **Phase 6 完成**：未登记、无 owner/consumer、非法版本变化与 schema/API 破坏可以被自动发现。

- [x] G03-6.1 实现 catalog validator，并为 duplicate identity、missing owner/consumer、非法状态和断裂引用建立失败测试。
- [x] G03-6.2 实现 source/catalog reconciliation，比较公开声明、PublishAsync/Outbox producer、subscription/handler 与目录记录。
- [x] G03-6.3 对 Proposed → Active 的同步 Contract 生成 public API snapshot，检测公开签名变化（当前为显式 pre-Active baseline，真实 Contracts.V1 需 Plan 01 回交）。
- [x] G03-6.4 对 Proposed → Active 的 Event、Request 和 Response 生成 serialization golden files，固定 wire name、字段、类型、requiredness 与版本（当前为显式 pre-Active baseline，真实 schema 需 Plans 01/02 回交）。
- [ ] G03-6.5 建立 Provider contract tests，覆盖 tenant、授权、NotFound、Denied、Unavailable、取消和协议语义。
- [ ] G03-6.6 建立 Consumer compatibility tests，覆盖 optional/unknown 字段和值、支持期旧版本及 Adapter 映射。
- [x] G03-6.7 自动生成 provider → consumer 图并阻断同步环；event/mixed loop 缺少 workflow、causation、idempotency 或 termination 声明时失败。
- [x] G03-6.8 先以 LegacyPendingMigration baseline 禁止新增债务，迁移完成后切换为零未登记/未豁免严格模式。

Phase 6 当前为 PRE-READY：[`G03-phase6-pre-ready.md`](../evidence/gates/G03/G03-phase6-pre-ready.md)、
[`G03-sync-api-snapshot.json`](../gates/G03/snapshots/G03-sync-api-snapshot.json)、
[`G03-serialization-golden.json`](../gates/G03/snapshots/G03-serialization-golden.json)、
[`G03-phase6-source-reconciliation.json`](../evidence/gates/G03/G03-phase6-source-reconciliation.json)、
[`G03-phase6-guard-report.json`](../evidence/gates/G03/G03-phase6-guard-report.json) 与
[`G03-phase6-layerguard-report.json`](../evidence/gates/G03/G03-phase6-layerguard-report.json)。G03-6.5/6.6 等待 Plan 01/02
真实 Provider/Consumer Adapter 与兼容测试回交，因此 Phase 6 不虚假标为完成。

## Phase 7 — Waiver、LayerGuard 与 CI 接缝

- [x] **Phase 7 完成**：治理目录成为 LayerGuard 和 CI 的输入，例外可追责、会到期且不能掩盖不可豁免问题。

- [x] G03-7.1 定义 waiver schema：owner、reason、risk、created-at、expires-at、removal condition 和 linked plan item。
- [x] G03-7.2 验证 waiver 默认不超过 90 天或命名里程碑，以较早者为准；续期视为新评审。
- [x] G03-7.3 将无 owner/consumer、内部模型泄漏、C4/未批准 C3 暴露和 identity 复用设为不可豁免；获批 C3 State Transfer 属于受控准入而非 waiver。
- [x] G03-7.4 向 LayerGuard 子计划交付 module ownership、Contract role、Adapter provider allowlist 与 shared primitives allowlist 的机器可读输入。
- [x] G03-7.5 禁止 LayerGuard 配置手工复制一份会漂移的 ownership 数据；若工具不能直接读取目录，建立一致性生成/校验步骤。
- [x] G03-7.6 为 catalog/API/schema/contract tests、LayerGuard 和 owner approval 定义统一 CI 入口与失败报告。
- [x] G03-7.7 证明过期 waiver、未知项目、未知 public type、orphan Active event 和扫描异常都会使严格 CI 失败。

Phase 7 证据：[`layerguard-governance-input.json`](../gates/G03/generated/layerguard-governance-input.json)、
[`G03-phase7-layerguard-handoff-report.json`](../evidence/gates/G03/G03-phase7-layerguard-handoff-report.json)、
[`G03-phase7-report.md`](../evidence/gates/G03/G03-phase7-report.md)、
[`G03-phase7-guard-report.json`](../evidence/gates/G03/G03-phase7-guard-report.json) 与
[`G03-phase7-layerguard-report.json`](../evidence/gates/G03/G03-phase7-layerguard-report.json)。Plan 03 L5.1 负责最终工具直接消费，
本 Phase 交付唯一生成输入与漂移校验，不宣称下游迁移已经完成。

## Phase 8 — 架构与规则文档化

- [ ] **Phase 8 完成**：Contract/Event ownership、版本、生命周期和治理流程形成可维护的中英文图文基线。

- [ ] G03-8.1 创建中文设计文档 `docs/architecture/review/gates/G03/contract-event-governance.zh-CN.md`。
- [ ] G03-8.2 创建对应英文文档 `docs/architecture/review/gates/G03/contract-event-governance.en.md`，保持决策、规则和 identity 一致。
- [ ] G03-8.3 文档解释 Provider Contract、Consumer Port、Integration Adapter、Event owner、Application 和 Composition 的职责边界。
- [ ] G03-8.4 创建当前/目标 public surface inventory、模块能力和数据 ownership 矩阵。
- [ ] G03-8.5 创建 Provider → Consumer 总体架构图以及同步、异步和 mixed dependency 图。
- [ ] G03-8.6 创建 Proposed → Active → Deprecated → Retired 生命周期状态图和 LegacyPendingMigration 迁移图。
- [ ] G03-8.7 创建 Compatible/Conditional/Breaking 判定流程图、V1/V2 并行迁移时序图和变更审批流程图。
- [ ] G03-8.8 文档包含 catalog schema、Change Record、waiver、外部 consumer 和 shared primitive 申请示例。
- [ ] G03-8.9 Mermaid 源文件与可直接查看的 SVG/PNG 一并保存，并完成渲染检查。
- [ ] G03-8.10 将每条治理规则映射到 catalog validator、snapshot、contract test、LayerGuard、CI 或人工审批。
- [ ] G03-8.11 更新架构索引、前置计划、总计划和三个原子计划的反向链接，并完成中英文一致性审查。

## Phase 9 — Gate 关闭与后续计划交接

- [ ] **Phase 9 完成**：Gate 03 已批准关闭，Contracts、Events 和 LayerGuard 实施具有唯一治理输入。

- [ ] G03-9.1 对照 GOV1、GOV2、GOV5 附上 catalog、owner、consumer、兼容、自动化和文档证据。
- [ ] G03-9.2 确认两个同步能力和两个事件均满足 Proposed → Active 准入，或明确记录仍阻塞的具体条件。
- [ ] G03-9.3 确认所有其他现有公共类型都有 LegacyPendingMigration 处置项且未超过到期时间。
- [ ] G03-9.4 向 Contracts 子计划交付 sync surface、DTO 分类、V1 identity、shared primitive allowlist 与兼容基线规则。
- [ ] G03-9.5 向 Event 子计划交付 event inventory、producer/consumer、schema identity、版本策略和 Messaging.Contracts 分层要求。
- [ ] G03-9.6 向 LayerGuard 子计划交付 ownership graph、合法 Adapter 边、catalog/allowlist schema 和 waiver policy。
- [ ] G03-9.7 在 [`00-prerequisites.md`](00-prerequisites.md) 勾选 Gate 3 相关事项，仅在全部实施、验证与文档完成后操作。
- [ ] G03-9.8 由模块 owner、Consumer owner、Platform Messaging 和架构负责人共同批准 Gate 关闭。

## Definition of Done

- [ ] G03-DD01 所有现有 Reader、方法、DTO 和 Event 均已登记、分类并有唯一 owner。
- [ ] G03-DD02 所有 Active Contract/Event 均有真实 Consumer、稳定 identity、版本、生命周期和兼容测试。
- [ ] G03-DD03 无证据公共表面均处于有 owner、有期限、有后续计划的 LegacyPendingMigration，而非伪装成 Active。
- [ ] G03-DD04 `IFX.Platform.Messaging.Contracts` 的职责和 BCL-only allowlist 已冻结，运行时 bus/handler/DI 不泄漏到模块 Contracts。
- [ ] G03-DD05 Catalog、源码、API/schema snapshot 和依赖图可自动对账，非法变化与孤立 Active event 会失败。
- [ ] G03-DD06 Provider/Consumer 审批、Change Record、并行版本、废弃窗口和外部 consumer 复核流程可执行。
- [ ] G03-DD07 LayerGuard/CI 获得唯一 governance source；过期 waiver 和扫描异常不能静默通过。
- [ ] G03-DD08 中英文说明、架构图、流程图、状态图、模板和规则验证映射全部完成并审核。

## 回退与例外原则

- [ ] G03-R01 Catalog/schema 变更应先保持向后兼容；validator 升级失败时回退工具版本，不回退或丢失已登记 ownership 历史。
- [ ] G03-R02 V2 上线失败时保留 V1 路径和 consumer Adapter 切换点，回退不得删除已产生的 V2 消息或隐藏处理责任。
- [ ] G03-R03 Retired identity 和历史 Change Record 永不复用或删除；只允许归档并保持可查。
- [ ] G03-R04 LegacyPendingMigration 或 waiver 到期后默认阻断，不自动延长；续期需要新风险评审和新到期日。
- [ ] G03-R05 紧急兼容中断必须保留影响、审批、发布、回退和事后修复证据，不能成为永久例外。
