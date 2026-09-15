# Contracts / Adapters / Events 改进计划概述与审查结论

> 状态：下文保留原计划一致性审查；各实施计划以自身进度与证据为准
> 总计划：[`00-master-plan.md`](00-master-plan.md)
> 前置 Gate：[`00-prerequisites.md`](00-prerequisites.md)
> 后续事项：[`TODO.md`](TODO.md)
> 当前阶段后续计划：[`04-module-boundary-evolution.md`](04-module-boundary-evolution.md) — 仓库验证通过，具名审批前 PRE-READY
> 新增独立演进计划：[`05-iam-platform-security-refactor.md`](05-iam-platform-security-refactor.md) — Auth → IAM 与平台认证/授权拆分，Phase 0–7 仓库实施与隔离验证完成；目标数据审计、真实 IdP 与发布验收待执行
> 新增独立演进计划：[`06-contract-adapter-event-boundary.md`](06-contract-adapter-event-boundary.md) — 提供方入站 Adapter、Application 与公开 Contracts 解耦，以及内部事实到 V1 事件的 Infrastructure 映射；Phase 0–6 与 repository verification 完成，G03 closure 保持 PRE-READY
> 已完成独立演进计划：[`07-contract-adapter-common-runtime.md`](07-contract-adapter-common-runtime.md) — 提取同步 Inbound context validation/provider scope、Outbound context factory 与 IAM Contract client，减少安全边界代码重复；repository implementation 与验证已完成
> 配套讨论：[`Platform 能力与租户连接`](../platform-capabilities-and-tenant-connections.zh-CN.md) — 独立讨论记录，不改变既有计划状态

## 一句话理解本次改造

可以把 IFX 看成同一园区内的多家公司：模块仍在同一个园区发布，但每家公司拥有自己的仓库、账本和业务决定；`Contracts` 是对外公布的最小办事表单，消费方 `Port` 是本公司的业务需求，`Adapter` 像负责翻译表单的办事窗口，Integration Event 则是可追踪、可重投的挂号信。Root Composition 只负责把窗口接好，不替任何公司办理业务；LayerGuard 是检查通行证和门禁规则的自动保安。

本次计划的目标不是把模块立即拆成 Microservices，而是先让模块化单体具备真实、可验证的编译期、数据、事务、协议和运行边界，使将来是否拆分成为部署选择，而不是一次被共享实现和隐式耦合绑架的重写。

## 审查范围与结论

原始审查覆盖 `plans` 目录中的总计划、Plan 00 前置计划、Gate 01–05、三个原子迁移子计划和后续 TODO。2026-09-10 又从 TODO 提取 GOV4、DP6、DB8、GOV3，形成不依赖生产平台决策即可启动的子计划 4。审查继续按“职责是否唯一、依赖是否闭合、规则是否一致、完成证据是否可追踪、后续事项是否重复”五个方面进行。

审查后的结论是：计划主体没有缺失；已发现的循环依赖、规则冲突和重复 backlog 已在当前版本中消除。当前仍有 Gate 与子计划交叉引用，但这些是刻意保留的“规则定义 → 真实实现 → 证据回交”关系，不是两套并行实施清单。

### 已修正的问题

| 问题 | 修正结果 |
| --- | --- |
| 前置 Gate 要求全部实现完成，但真实 Outbox/Inbox/Dispatcher 又在子计划实现，形成循环依赖 | 明确区分 `PRE-READY 前置放行` 与 `Gate Final Closure 最终关闭` 两个里程碑。 |
| Gate 01 把 Inbox 唯一性写成单独 `EventId` | 统一为 `(ConsumerId, EventId)` 复合身份；业务幂等键仍与消息身份分开。 |
| Gate 03 的公共 primitive allowlist 未包含 Gate 05 的 context primitives | 统一为 BCL 加已批准的 `Context.Contracts` 和 `Messaging.Contracts`；仍禁止业务 SharedKernel 蔓延。 |
| Gate 03 的“敏感数据违规不可豁免”可能否定 Gate 05 已批准的 C3 State Transfer | 改为 C4 和未经批准的 C3 不可豁免；批准的 C3 是受控准入，不是 waiver。 |
| Gate 02 发布流程遗漏 Worker consumer-first 顺序 | 统一为 Migrator/validation → 兼容 Worker consumers → Worker Ready → API producers。 |
| Gate 04 与事件子计划都像是在实现 Dispatcher | Gate 04 只拥有 Runtime Role、lease、health、backpressure 协议和 reference conformance；E3/E6 实现真实 Dispatcher 与 backlog 信号。 |
| Gate 05 与 Gate 03 可能各建一套 catalog validator | Gate 03 只拥有一套权威目录/validator；Gate 05 只贡献 context 与字段分类扩展。 |
| TODO 重复维护 TX8、DP2、DP7、OPS4 和已完成评审的 NEXT1–3 | 从活动 backlog 移除，并保留指向唯一实施计划的追踪表。 |
| 三个子计划对最终架构与规则文档要求不对称 | 每个子计划新增独立文档化 Phase，要求中英文说明、架构图、流程/状态图及规则证据映射。 |
| 新版门禁仍排在 Gate 01–05 后，无法观察 Gate 自身改动 | 拆分 03-A0 Core Bootstrap 与 03-A1 Policy Binding：A0 最先运行并生成 B0.5，Gate 完成后再绑定权威 policy 并生成正式 B1。 |

### 单一职责与证据回交流程

```text
子计划 3-A0：先建立 LayerGuard Core 和 B0.5
           |
           v
Gate 01-05：在 bootstrap 门禁下完成规则与基础并达到 PRE-READY
           |
           v
       子计划 3-A1：绑定 Gate policy 并生成正式 B1
           |
           v
       子计划 1：真实 Contracts / Ports / Adapters 迁移 --> B2
           |
           v
       子计划 2：真实 Outbox / Inbox / Dispatcher / Event 迁移 --> B3
           |
           v
       子计划 3-B：违规清零、严格模式和 B4 对比
           |
           v
              实现与测试证据回交相应 Gate
                             |
                             v
                 Gate Final Closure + 总体验收
```

子计划 4 在 B4 后作为独立后续治理轨道启动，可与生产依赖的 Gate Final Closure 并行；它不回写或
重定义 B1–B4，也不以仓库设计证据替代目标环境验收。

关键的唯一 owner 如下：

| 内容 | 唯一实施 owner | Gate 的职责 |
| --- | --- | --- |
| 真实 Contract、Port、Adapter 与调用迁移 | 子计划 1 | Gate 03/05 提供 ownership、schema、context 和分类规则并验收。 |
| 真实 Outbox/Inbox entity、migration 与事务绑定 | 子计划 2 E2/E4 | Gate 01/02 定义本地原子性、schema ownership 与 conformance。 |
| 真实 Dispatcher、重试、backlog 与运行信号 | 子计划 2 E3/E6 | Gate 04 定义 role、lease、readiness、backpressure 与运行 conformance。 |
| 权威 Contract/Event catalog validator | Gate 03 | Gate 05 贡献 context/字段分类扩展；子计划回写真实 schema 和 consumer。 |
| 编译期边界自动检查与 CI 阻断 | 子计划 3 | Gate 03/05 提供治理输入，但不另建第二个 LayerGuard。 |

## 实施顺序

```text
                                LayerGuard 03-A0
                    core engine + fixtures + B0.5 bootstrap
                                             |
                                             v
G01 Transaction ──────────────┐
G02 Database ─────────────────┤
G03 Contract/Event Governance ┼──> PRE-READY
G04 Deployment/Runtime ───────┤          |
G05 Context/Sensitive Data ───┘          v
                                LayerGuard 03-A1
                      bind Gate policy + formal B1
                                             |
                                             v
                                  Contracts/Adapters --> B2
                                             |
                                             v
                                        Events --> B3
                                             |
                                             v
                                LayerGuard 03-B strict + B4
                                             |
                                             v
                              Gate final closure + overall release
```

03-A0 必须在 Gate 01 前完成，用 B0.5 观察 Gate 自身改动并阻止通用确定性规则的新增违规；由于此时尚无完整 catalog、allowlist 和 Runtime Role artifact，B0.5 不作为正式改善基准。Gate 01–05 前置放行后，03-A1 绑定权威 policy 并生成正式 B1；子计划 1/2 后分别保存 B2/B3，严格模式最后生成 B4。B1 与 B4 必须使用相同目标规则语义，旧 LayerGuard 的 B0 只作为旧工具能力参考。

## 主体 1：事务边界（Gate 01）

计划：[`00-G01-transaction-boundary.md`](00-G01-transaction-boundary.md)

1. **本次要修改的问题**：统一 Command 的 commit/rollback 语义、消除 Handler 自行最终保存、明确并发与重试边界，并为 Outbox/Inbox 建立模块本地原子事务接缝。
2. **为什么要修改**：当前 `Result.Failure`、异常、取消和 transient failure 缺少单一事务政策；大多数 Handler 自行 `SaveChangesAsync`，会使业务数据与事件记录无法可靠同生同灭。
3. **当前如何做**：TransactionBehavior 与 Handler 都参与持久化，部分事件在提交前直接发布；消费处理器直接保存本模块数据，没有统一 Inbox 去重事务。
4. **修改后是什么样**：TransactionBehavior 成为事务政策 owner；默认 Command、Inbox Command 和少量批准的特殊 Profile 都有明确算法；一个写命令只写一个模块，业务数据与本模块 Outbox、消费数据与本模块 Inbox 分别原子提交，跨模块不宣称共享 ACID。

本 Gate 不实现 transport、Dispatcher、dead-letter 或完整 Event schema；真实消息持久化由事件子计划完成并回交证据。

## 主体 2：数据库边界（Gate 02）

计划：[`00-G02-database-boundary.md`](00-G02-database-boundary.md)

1. **本次要修改的问题**：固定每模块 DbContext/schema/migration ownership，分离 migration history，补齐默认 schema 防护，并把 migration 从普通 ApiHost 启动副作用迁到受控 Migrator 流程。
2. **为什么要修改**：共享物理数据库不应等于共享表 ownership；共享 history、缺失默认 schema、标识不一致或多实例启动 migration 会放大碰撞、误写和并发部署风险。
3. **当前如何做**：业务模块已经有独立 DbContext、migration 集合和多数显式 schema，但仍共享物理数据库和默认 history；部分 schema 防护及 Auth 历史兼容不完整，migration 与宿主启动耦合。
4. **修改后是什么样**：每个模块只迁移和访问自己的 schema，拥有独立 history；Outbox/Inbox 跟随所属模块 DbContext，不引入共享 Messaging DbContext；生产发布先运行单一 Migrator，再验证 Worker/API readiness，并用真实关系数据库覆盖 fresh install、upgrade、legacy 和重复执行。

本 Gate 不要求立即拆成独立数据库实例；credential 强隔离、RLS、租户生命周期清理和未来物理拆库仍属于后续计划。

## 主体 3：Contract / Event 治理（Gate 03）

计划：[`00-G03-contract-event-governance.md`](00-G03-contract-event-governance.md)

1. **本次要修改的问题**：建立能力、数据、Contract 和 Event 的唯一权威目录，明确 owner、真实 consumer、同步/异步选择、版本兼容、弃用和公共 primitive allowlist。
2. **为什么要修改**：没有可执行治理时，`Abstractions` 容易变成公共查询仓库；未使用接口和事件会长期暴露，内部 DTO 与共享库也会悄然扩散到模块边界。
3. **当前如何做**：公共接口面较宽，已盘点的多个 Reader/方法和 Event 中只有少部分有真实生产 consumer；ownership、兼容窗口、退役证据和 schema/source reconciliation 不是统一门禁。
4. **修改后是什么样**：每个 Active Contract/Event 都有唯一 owner、真实 consumer、purpose、版本和生命周期；公共类型只能使用 BCL 与批准的 Context/Messaging primitives；目录与源码、schema 快照、依赖图和 LayerGuard 自动对账。

Gate 03 拥有唯一 catalog/validator；Gate 05 只向它增加 context 与字段分类维度，避免双目录漂移。

## 主体 4：部署与运行边界（Gate 04）

计划：[`00-G04-deployment-runtime-boundary.md`](00-G04-deployment-runtime-boundary.md)

1. **本次要修改的问题**：把实际部署单元、API/Worker Runtime Roles、多实例 lease、启动/关闭、readiness、backpressure 和 consumer-first 发布顺序变成显式规则。
2. **为什么要修改**：编译期模块、容器和部署边界是不同概念；如果 ApiHost 扩容会隐式复制 Hangfire/Dispatcher，或 migration、consumer 与 producer 没有顺序，系统可能重复执行、读取不兼容 schema 或错误报告 Ready。
3. **当前如何做**：五个业务模块由一个 ApiHost 组合和发布；后台工作、migration 与 HTTP 宿主的职责边界不充分，现有 health 范围也不能代表各模块 schema、Dispatcher 和 backlog 的真实状态。
4. **修改后是什么样**：五个业务模块仍使用同一 release/image，可用 `api`、`worker` 和本地 `all` 角色独立扩容；Migrator 是受控步骤；多 Worker 通过短事务 claim/lease 实现 at-least-once；role-specific liveness/readiness、drain、backpressure 和回退均可验证。

需要特别注意：Runtime Role 可独立扩容不等于业务模块可独立发布。Frontend、数据库、OPA、Migrator 等 Platform/Infrastructure unit 可以有独立生命周期，也不会自动把五个业务模块变成 Microservices。

## 主体 5：关联上下文与敏感数据（Gate 05）

计划：[`00-G05-context-sensitive-data-boundary.md`](00-G05-context-sensitive-data-boundary.md)

1. **本次要修改的问题**：分离 Correlation、Operation、Causation、Event、Trace 和 Tenant 的语义；定义可信入口、显式 ExecutionContext、Contract/Event carrier，以及 C0-C4 字段分类和日志/trace 防泄漏规则。
2. **为什么要修改**：追踪标识不能代替授权、租户 scope 或幂等身份；隐式全局上下文、默认租户和包含个人/凭据数据的公共 payload 会造成跨租户和长期数据副本风险。
3. **当前如何做**：HTTP `TraceIdentifier`、`HttpContext`/CurrentUser 和事件最小 metadata 分散承担不同语义，存在 invalid tenant fallback、上下文丢失或混用的可能；公共 Contract/Event、错误、日志和 trace 还没有统一字段目录。
4. **修改后是什么样**：可信 Adapter 在 HTTP/job/Contract/Event 入口建立隔离 ExecutionContext；同步与异步 carrier 只携带必要 BCL-only primitives；retry/replay 保持逻辑身份；所有公共字段登记 purpose 和 C0-C4 分类，C4 零暴露，C3 只有受控、可追责且会到期的 State Transfer。

CorrelationId 只用于关联观察，EventId 只标识事件，二者都不能替代租户授权或业务幂等键。

## 主体 6：Contracts / Ports / Adapters 重构（子计划 1）

计划：[`01-contracts-adapters-refactor.md`](01-contracts-adapters-refactor.md)

1. **本次要修改的问题**：把提供方 `Abstractions` 收窄为真正的 `Contracts`，把消费需求定义为消费方 Application Port，并把跨模块调用转换放进消费方外层 Integration Adapter。
2. **为什么要修改**：当前消费方 Application 直接引用提供方 Abstractions，会让提供方公共 DTO/接口进入消费方用例层；基础设施 Reader 也可能绕过提供方 Application 直接读取数据，削弱模块独立性和未来远程替换能力。
3. **当前如何做**：提供方通过 Abstractions 暴露 Reader/DTO，消费方 Application 直接依赖这些类型；Root DI 能装载实现，但协议、消费需求和数据访问职责没有被清晰分开。
4. **修改后是什么样**：提供方拥有最小 Contract 并由自身 Application 实现；消费方 Application 只依赖自己的 Port；消费方 Adapter 引用“本模块 Port + 提供方 Contract”并转换模型；模块 Composition 注册实现，ApiHost 只调用 Composition。进程内实现未来可换成 HTTP/gRPC Adapter 而不修改消费方 Application。

`Contracts` 不是“内部 Presentation”：两者都是边界协议，但 Presentation 是 HTTP 入站 Adapter，可处理路由、认证和协议映射；Contracts 是无运行行为的模块能力/事实定义。`Integration` 也不是新的业务 layer，而是 Infrastructure/外层中的适配器角色。

## 主体 7：可靠 Integration Events（子计划 2）

计划：[`02-reliable-integration-events.md`](02-reliable-integration-events.md)

1. **本次要修改的问题**：分离 Domain Event 与 Integration Event，建立版本化 Envelope、Transactional Outbox、提交后 Dispatcher、可替换 Transport、Inbound Adapter、Inbox 幂等、失败恢复和回放。
2. **为什么要修改**：提交前或纯内存直发可能在数据库回滚后仍通知消费者，也可能在提交后进程崩溃时永久丢失；简单重试又会带来重复业务效果。
3. **当前如何做**：事件主要在进程内发布，异常处理可能吞掉 handler failure；没有持久 Outbox/Inbox、稳定重试、dead-letter、replay 和端到端可观测性。
4. **修改后是什么样**：生产方在本地事务写业务数据和 Outbox；Dispatcher 只读取已提交记录并按 at-least-once 发送；消费方先由 Adapter 验证/转换，再在自己的本地事务写业务数据和 `(ConsumerId, EventId)` Inbox completion；失败可诊断、重试、隔离、回放和 reconciliation。

Event 解决的是跨边界事实传播和可靠最终送达，不提供跨模块 ACID。需要多步骤业务一致性的 Saga/补偿状态机仍在后续事务计划中。

## 主体 8：LayerGuard 对齐（子计划 3）

计划：[`03-layerguard-alignment.md`](03-layerguard-alignment.md)

1. **本次要修改的问题**：让 LayerGuard 能识别 own/foreign Contracts、Integration Adapter 的最小许可、声明位置、传递依赖、框架泄漏和 waiver 生命周期，并接入 CI。
2. **为什么要修改**：仅靠文档不能阻止依赖回流；过于宽泛的 `sameModule`/ring 规则也无法表达“消费方 Application 禁止 foreign Contracts、只有指定 Adapter 可以引用”的目标边界。
3. **当前如何做**：现有规则主要按四层 ring 和同模块关系检查，对新 Contracts/Adapters 模型、catalog reconciliation、Context primitives 和 CI 阶段化阻断支持不足。
4. **修改后是什么样**：03-A0 在 Gate 01 前建立项目发现、ownership/role 分析、可配置规则、正反 fixture 和 B0.5；03-A1 在 Gate 前置放行后绑定权威 policy 并保存正式 B1；随后用 B2/B3 跟踪迁移，最终以 B4 清零未豁免违规并开启严格模式。

LayerGuard 只检查静态依赖、声明和框架泄漏；字段值、敏感数据、运行时传播与 schema 兼容由 Gate 03/05 的 catalog/schema/security/conformance tests 负责，任何一侧的绿色结果都不能掩盖另一侧失败。

B4 仓库内严格收口已于 2026-09-09 完成：116 → 103 → 32 → 0 finding，空 baseline 已进入默认本地/CI 路径。参见[中文规则](../layerguard-strict-boundaries.zh-CN.md)、[English rules](../layerguard-strict-boundaries.en.md) 与 [B4 证据](../evidence/03-b-layerguard-strict-closure.md)。架构负责人 L7.7 批准仍保持开放，不由代码证据代签。

## 主体 9：模块边界演进与查询治理（子计划 4）

计划：[`04-module-boundary-evolution.md`](04-module-boundary-evolution.md)

该计划承接当前不依赖生产平台即可执行的 GOV4、DP6、DB8、GOV3：仓库实现、统一门禁、双语设计与全套测试已通过，具名职能审批前保持 PRE-READY。它没有实际拆分服务、启用生产 RLS 或臆造报表需求；相应生产和业务依赖仍留在 TODO。设计见[中文](../module-boundary-evolution.zh-CN.md) / [English](../module-boundary-evolution.en.md)，证据见 [Plan 04 index](../evidence/plan04/README.md)。

## 仍留在后续计划中的相关工作

以下事项与本轮方向相关，但不是实施 Contracts/Adapters/Events/LayerGuard 的必要前置，因此保留在 [`TODO.md`](TODO.md) 中，进入实施前需要另行评审和计划化：

| 领域 | 后续工作 |
| --- | --- |
| 数据库 | 每模块生产 credential/schema 权限；Tenant 删除/停用生命周期与 reconciliation；未来物理拆库、复制、报表和恢复。DB8 已转入子计划 4。 |
| 跨模块事务 | KYC/Class 先查后写的 TOCTOU 控制；Saga/补偿状态机、超时、人工干预和审计；针对补偿流程的故障注入。 |
| Microservice 提取 | 拆分后的认证、发现、超时、重试、熔断和 observability；独立 Contracts package/version cadence，避免 lockstep deployment。DP6 已转入子计划 4。 |
| 模块治理 | 租户生命周期、保留、隐私删除和审计责任矩阵。GOV3/GOV4 已转入子计划 4。 |
| 运行治理 | 在本轮指标契约之上设置 SLI/SLO、error budget 和责任人；建立跨 Gate 的定期 game day。 |

这些后续事项不得通过跨 DbContext join、共享事务、共享内部 Domain 类型、默认租户或放宽 LayerGuard 来临时绕过。

## 执行时最容易误解的五点

1. **同一个 ApiHost 不等于没有模块边界**：发布边界暂时共享，但编译期、数据、事务和协议 ownership 必须独立。
2. **独立 API/Worker role 不等于 Microservices**：只要五个业务模块仍锁定同一 release，它们仍是一个业务发布边界。
3. **Contracts 不负责“加载实现”**：它只有类型定义；提供方 Infrastructure Inbound Adapter 实现公开接口，Application 实现自有用例，模块 Composition 在 Root DI 注册，消费方 Outbound Adapter 通过注入调用。
4. **Event 不等于跨模块事务**：Outbox/Inbox保证各自本地原子性和最终送达；跨模块业务一致性依赖状态机、补偿或 Saga。
5. **可追踪不等于可信**：Correlation/Trace 用于诊断，Tenant/Actor 必须由可信入口验证，EventId 也不能替代业务幂等键。

## 本轮计划完成的判断标准

本轮不是以“项目改名”或“事件能发送”为完成，而是同时满足以下结果：代码依赖与目标图一致；真实跨模块同步调用只经过消费方 Port/Adapter；事件提交后可靠投递且消费幂等；模块数据与事务 ownership 可验证；API/Worker/Migrator 运行规则可演练；Context 和敏感数据规则贯穿同步/异步链路；LayerGuard 在 CI 阻断未豁免违规；各 Gate 与子计划均交付中英文设计说明、架构图、流程/状态图和可追踪验证证据。
