# 子计划 2：可靠 Integration Event 改进

> G04 反向链接：E3/E4/E6 必须重跑 lease、drain、health、backpressure 与 consumer-first conformance；见 [G04 runtime baseline](../gates/G04/deployment-runtime-boundary.zh-CN.md)。

> 状态：B3 核心仓库检查点完成；Phase 3–8 的强化、生产验收与最终 Gate 签字保持开放（2026-09-08）
> 上级计划：[`00-master-plan.md`](00-master-plan.md)
> 前置关系：公共事件 schema 依赖子计划 1 的 Contracts 结构和 [`00-G03-contract-event-governance.md`](00-G03-contract-event-governance.md) 的事件目录、identity、版本/兼容政策；原子保存依赖事务与数据库 Gate。
> G03 交接入口：[治理说明](../gates/G03/contract-event-governance.zh-CN.md)、[catalog](../gates/G03/contract-event-catalog.yaml) 与 [serialization golden snapshot](../gates/G03/snapshots/G03-serialization-golden.json)；完成真实 Envelope/Outbox/Inbox/behavior tests 后回交 Active 准入证据。
> 可执行交接包：[`G03 -> Plan 02 handoff`](../gates/G03/handoffs/plan02-events-handoff.md)，含 owner、20 项 event 处置、Messaging Contracts/runtime 分层、回访条件和回交清单。
> 运行前置：[`00-G04-deployment-runtime-boundary.md`](00-G04-deployment-runtime-boundary.md) 定义 API/Worker roles、instance identity、多实例 lease、health、drain、backpressure 和 consumer-first 发布顺序。
> 上下文与数据前置：[`00-G05-context-sensitive-data-boundary.md`](00-G05-context-sensitive-data-boundary.md) 定义 Event Envelope、Correlation/Causation/Tenant/Trace、字段分类、失败矩阵和 conformance suite。
> 门禁前置：[`03-layerguard-alignment.md`](03-layerguard-alignment.md) 03-A0/03-A1 已完成并保存正式 B1；事件迁移全过程不得新增未登记依赖或通过放宽规则绕过 B1。

## B3 验收切片

B3 已完成事件迁移的仓库可验证范围：两个 provider-owned V1 schema、producer-local
Transactional Outbox、Worker Dispatcher、Holdings Inbound Adapter/Inbox/quarantine、受控诊断与
replay、G01–G05 对称回交，以及 B3 LayerGuard 基线。证据见
[`B3-status.json`](../evidence/plan02/B3-status.json) 和
[`B3-gate-handback.md`](../evidence/plan02/B3-gate-handback.md)。下方未勾选项是完整 Plan 02 的
生产运维关闭条件或增强项，不阻塞仓库 B3，但继续阻止 Plan 02/Gate Final Closure。

## 目标流程

```text
Producer Application
  -> 同一本地事务保存 Aggregate + Outbox
  -> Commit
  -> Outbox Dispatcher
  -> Transport（当前可为进程内，未来可替换 Broker）
  -> Consumer Inbound Integration Adapter
  -> Inbox 去重
  -> Consumer Application Command
  -> 同一本地事务保存 Consumer Data + Inbox
```

目标交付语义为 at-least-once，而不是不可证明的 exactly-once。系统通过 Outbox 避免“数据已提交但消息未发”，通过 Inbox 与幂等业务处理容忍重复，通过重试、死信和回放恢复失败。

## Phase 0 — 事件盘点与语义决策

- [x] **Phase 0 完成**：本 Phase 下全部项目均已完成并附有证据。

- [x] E0.1 从 Gate 03 权威目录导入所有事件类型、发布点、处理器、模块所有者、触发事务和实际消费者，并与源码对账；新增或重分类先更新目录。
- [x] E0.2 将现有事件分类为 Domain Event、Integration Event、进程内通知或错误地用于状态传输的消息。
- [x] E0.3 为每个 Integration Event 明确“已发生的事实”、生产方、消费方、交付要求和可接受延迟。
- [x] E0.4 识别当前 Transaction 在 `SaveChanges` 后、`TransactionBehavior` 提交前调用 `PublishAsync` 的崩溃与可见性窗口。
- [x] E0.5 识别当前 `InMemoryIntegrationEventBus` 顺序调用且吞掉 handler 异常造成的不可重试、假成功问题。
- [x] E0.6 明确事件顺序要求：默认只保证同聚合/同分区内的必要顺序，不声明全局顺序。
- [x] E0.7 明确保留期、重复容忍、敏感字段、事件大小和 schema 兼容政策。
- [x] E0.8 验证前置计划 Gate 1 的事务语义已经批准；未通过时不得进入 Outbox/Inbox 实现。
- [x] E0.9 从 Gate 05 导入每个 Event/Envelope 字段的分类、purpose、consumer、retention、replay 和日志规则，并标记需删除的 Name、AccountNumber、自由文本和重复 TenantId。
- [x] E0.10 从 Gate 02 导入模块 schema/DbContext/connection/history ownership 矩阵、独立 Migrator 顺序及 `G02SqlServerAssertions`；Outbox/Inbox migration 必须只修改所属模块 schema，并进入同一 manifest、fresh/upgrade 和零 pending 验收。

## Phase 1 — 定义事件契约与 Envelope

- [x] **Phase 1 完成**：本 Phase 下全部项目均已完成并附有证据。

- [x] E1.1 将生产方拥有且已通过 Gate 03 准入的 Integration Event schema 放入生产方 Contracts，并与 Domain Event 类型完全分离。
- [x] E1.2 采用过去时、业务事实命名，禁止把“请执行某操作”的命令伪装为事件。
- [x] E1.3 复用 Gate 05 统一 Envelope：EventId、EventType、SchemaVersion、OccurredAt、Producer、TenantScope、CorrelationId、CausationId、ContentType 与可选 W3C trace carrier。
- [x] E1.4 Actor/Source 使用最小引用且由可信 runtime 注入；禁止认证凭据、ClaimsPrincipal、角色列表和调用方自报授权进入事件。
- [x] E1.5 确保 payload 不引用 Domain Entity、EF 类型、内部枚举实现或消费方模型。
- [x] E1.6 为向后兼容、并行版本、未知字段和废弃窗口建立可自动验证的规则。
- [x] E1.7 评审 CRM 当前事件是否足以构建账户 KYC 投影；若不足，设计最小事实事件或明确继续使用同步 Contract。
- [x] E1.8 为关键事件保存序列化 golden files，作为 schema 回归基线。
- [x] E1.9 建立 BCL-only `IFX.Platform.Messaging.Contracts` schema primitives；bus、handler、dispatcher、DI、serializer 和 broker 端口/实现不得进入模块 Contracts 依赖。
- [x] E1.10 对每个字段执行 C0-C4 分类和最小化；C4 禁止，C3 仅允许获批 State Transfer Event，Notification Event 默认不携带 Restricted 数据。
- [x] E1.11 运行 Gate 05 schema/security conformance suite，并验证 payload TenantId 仅在其本身为业务事实时重复且与 Envelope 一致。

## Phase 2 — 生产方 Transactional Outbox

- [x] **Phase 2 完成**：本 Phase 下全部项目均已完成并附有证据。

- [x] E2.1 为每个事件生产模块设计自己 schema 内的 Outbox 表、EF 映射和 migration，不建立跨模块表依赖。
- [x] E2.2 定义 Outbox 状态、尝试次数、下一次尝试时间、锁租约、创建/发布时间和最后错误字段。
- [x] E2.3 在 Application/Domain 完成业务结果后生成 Integration Event snapshot，不把可变实体交给异步发布器。
- [x] E2.4 在同一 DbContext、本地数据库事务内原子写入业务变更与 Outbox 记录。
- [x] E2.5 移除业务 handler 中提交前直接 `PublishAsync` 的路径，确保 rollback 时没有可投递 Outbox。
- [x] E2.6 验证前置计划 TX2/TX3 的 commit/rollback 语义在 Outbox 写入路径中仍然成立，防止失败结果及其 Outbox 被提交。
- [x] E2.7 处理序列化失败，使业务事务明确失败并产生可诊断错误，而不是提交一半状态。
- [x] E2.8 添加数据库级测试，证明业务数据与 Outbox 在成功时同时存在、失败时同时不存在。
- [x] E2.9 在 Outbox 写入时冻结 Gate 05 Envelope/trace snapshot，物理区分 immutable logical message 与 mutable delivery attempt/lease/error metadata。

## Phase 3 — 提交后 Dispatcher 与可替换 Transport

- [ ] **Phase 3 完成**：本 Phase 下全部项目均已完成并附有证据。

- [x] E3.1 按 Gate 04 实现 Outbox Dispatcher：只读取已提交记录，使用短事务有界 claim、唯一 LeaseOwner/LeaseUntil/concurrency token、事务外发送与条件完成。
- [x] E3.2 在 `worker`/`all` role 启动 Dispatcher，按 Gate 04 定义多 Worker 实例竞争、critical loop failure 和优雅 drain；`api` role 不启动 Dispatcher。
- [x] E3.3 把 transport 抽象限制在投递职责；当前可适配进程内总线，未来可替换消息 broker 而不改 Application。
- [x] E3.4 修复总线错误语义：handler/transport 失败不得被吞掉，必须反馈给重试状态机。
- [x] E3.5 实现指数退避、最大尝试次数、抖动与可配置超时，避免热循环和级联故障。
- [x] E3.6 明确 Outbox 的 delivered、retrying、dead-lettered 状态转换和并发更新策略。
- [ ] E3.7 增加 backlog、oldest age、success/failure rate、retry count 与 dead-letter count 指标及结构化日志。（部分完成：snapshot 与安全结构化日志已有；正式 rate metrics/exporter 未接入。）
- [ ] E3.8 验证进程在“发送前、发送后标记前、标记后”三个时点崩溃时均不会丢失已提交事件。（部分完成：lease expiry/reclaim 已验证；完整三窗口矩阵待补。）
- [ ] E3.9 实现 per-module backlog/lease/last-success Health Contributor 和 warning/critical backpressure 接缝。（部分完成：observe/backpressure policy 已有；Health Contributor/endpoint 未注册。）
- [x] E3.10 Dispatcher 逐字段复制冻结 Envelope 到 transport carrier，不重新生成 EventId/Correlation/Causation/Tenant/OccurredAt；日志和指标不得输出 payload 或原始高基数敏感值。

## Phase 4 — 消费方 Inbound Adapter、Inbox 与幂等

- [ ] **Phase 4 完成**：本 Phase 下全部项目均已完成并附有证据。

- [x] E4.1 将当前直接位于 Holdings.Application 的外部事件 handler 迁移至 Holdings 外层 Inbound Integration Adapter。
- [x] E4.2 让 Adapter 引用生产方 Contracts，并把外部 event DTO 映射为 Holdings.Application 自有 command。
- [x] E4.3 确认 Holdings.Application 不再引用生产方 Contracts 或 transport SDK。
- [x] E4.4 为每个消费模块设计自己 schema 内的 Inbox 表、`(ConsumerId, EventId)` 复合唯一约束、处理状态和受分类规则保护的诊断字段。
- [x] E4.5 在同一本地事务内完成 Inbox 去重判定、消费方业务变更与 Inbox 完成记录。
- [x] E4.6 当前两个 Holdings consumer 只产生同一数据库事务内的业务变更，没有外部非事务副作用；因此 B3 记为 N/A。未来引入通知、支付或远程调用时必须重新打开并设计下游幂等协议。
- [x] E4.7 明确业务拒绝、暂时故障、永久无效 schema 与未知事件类型各自的 ack/retry/dead-letter 行为。
- [ ] E4.8 添加重复、并发重复、乱序、跨租户和处理器崩溃测试。（部分完成：重复和跨租户路径已有；真实 Holdings 并发重复、乱序和 handler crash 待补。）
- [ ] E4.9 Inbound Adapter 在 Inbox/Application 前验证 producer、type/version、EventId、TenantScope、Correlation/Causation；非法业务上下文进入 quarantine，非法 trace 只创建新 span。（部分完成：producer/schema/tenant 验证已有；非法 trace 重启 span 的真实 Adapter 测试待补。）
- [ ] E4.10 使用 EventId 作为 consumer OperationId 建立隔离 ExecutionContext；下游 Event 保留 CorrelationId 并以入站 EventId 为 CausationId，finally 清理 scope。（部分完成：EventId → OperationId 已实现；scope cleanup 与下游 event causation 测试待补。）

## Phase 5 — 事件内容与投影策略改进

- [ ] **Phase 5 完成**：本 Phase 下全部项目均已完成并附有证据。

- [x] E5.1 评审 `TransactionProcessed` 的事实语义、字段最小性、版本和重放安全性，并发布稳定 v1。
- [ ] E5.2 为 Class 状态变化决定使用同步查询、事件投影或二者组合，并明确新鲜度与 TOCTOU 风险。
- [x] E5.3 决定本里程碑不建立 KYC 本地投影，继续使用 Plan 01 的同步 `AccountCompliance` Contract；若未来改变该决定，必须新开 projection/bootstrap 设计。
- [ ] E5.4 定义投影 bootstrap、断点续传、重建、版本切换与最终一致状态下的业务降级策略。
- [ ] E5.5 为会触发后续命令的事件处理定义 correlation/causation 链，避免循环发布无法诊断。
- [ ] E5.6 明确事件数据删除、隐私与审计保留策略，不让 payload 成为不可治理的数据副本。
- [ ] E5.7 将 Outbox、Inbox、broker、dead-letter、replay 和诊断存储按 payload 最高分类配置访问、加密、保留和删除；C3 State Transfer 例外可追责且会到期。

## Phase 6 — 失败恢复、回放与运维

- [ ] **Phase 6 完成**：本 Phase 下全部项目均已完成并附有证据。

- [ ] E6.1 提供按 EventId、时间区间、事件类型和租户查询 Outbox/Inbox 状态的受控诊断能力。
- [ ] E6.2 提供 dead-letter 审核和单条/批量重试流程，并要求权限、审计与 dry-run。
- [ ] E6.3 定义重复回放的安全门槛，回放前验证目标 handler 版本与幂等保证。
- [x] E6.4 建立生产方与消费方 reconciliation 作业或手册，用于发现永久遗漏和投影漂移。
- [ ] E6.5 设置 backlog age、连续失败、dead-letter 增长和 dispatcher 停止的告警阈值。
- [x] E6.6 编写故障手册，覆盖数据库不可用、transport 不可用、毒消息、schema 不兼容和积压恢复。
- [ ] E6.7 replay 保留原 EventId/Envelope；已完成 Inbox 继续去重，强制重处理使用有权限和审计的 ReprocessingRequest，不换 ID 绕过幂等。
- [x] E6.8 B3 没有启用 Compatibility Adapter；记为 N/A。Dispatcher 不补写上下文；未来引入兼容适配器时必须先登记 owner、来源、provenance、指标和到期日。

## Phase 7 — 测试、渐进发布与旧路径移除

- [ ] **Phase 7 完成**：本 Phase 下全部项目均已完成并附有证据。

- [x] E7.1 添加 Outbox/Inbox repository、dispatcher、Adapter 与 handler 单元/组件测试。
- [ ] E7.2 添加包含真实关系数据库的集成测试，覆盖事务 rollback、唯一约束和并发 claim。
- [ ] E7.3 添加端到端测试，证明源提交最终导致消费方状态变化，并能容忍重复与短暂故障。
- [ ] E7.4 执行故障注入测试，覆盖进程终止、连接中断、超时、部分批次和重启恢复。
- [ ] E7.5 执行 Gate 04 consumer-first 顺序：先部署兼容旧/新 schema 的 Worker consumers，再部署 API producers；定义去重、观测窗口和唯一权威路径。
- [ ] E7.6 在指标达到验收门槛后关闭旧的同步直发/直接 handler 路径，并删除无用注册。
- [x] E7.7 将实际 schema、版本、发布/消费责任人、兼容状态和 retire 证据回写 Gate 03 权威目录，并更新运维 runbook。
- [ ] E7.8 运行 Gate 05 的 HTTP/producer → Outbox → transport → Inbox → downstream Event 传播、retry/replay immutability、parallel tenant isolation 和敏感 sentinel 测试。

## Phase 8 — 架构与规则文档化

- [ ] **Phase 8 完成**：本 Phase 下全部项目均已完成并附有证据。

- [x] E8.1 编写完整中文设计说明，解释 Event ownership、Envelope、Outbox、Dispatcher、Transport、Inbox、Inbound Adapter 与 Consumer 的职责。
- [x] E8.2 编写与中文内容一致的英文设计说明，并建立双向链接。
- [ ] E8.3 保存改造前后事件架构图，标明模块、数据库、运行角色、事务边界和可替换 Transport。
- [x] E8.4 保存 Producer → Outbox → Dispatcher → Transport → Inbox → Consumer 的正常时序图。
- [ ] E8.5 保存失败、重试、dead-letter、replay、reconciliation 和 consumer-first rollout 的状态/流程图。
- [x] E8.6 说明 Gate 01/02 的本地事务与数据库边界，以及 Gate 05 context/敏感数据规则如何约束事件通道。
- [x] E8.7 保存 Mermaid 源文件及可审阅的 SVG/PNG 渲染结果，并执行链接和视觉检查。
- [ ] E8.8 将事件规则映射到 schema、测试、指标、告警、runbook、Gate 证据或有到期日的 waiver，并更新架构索引。
- [ ] E8.9 在 E2/E4 完成后执行 G01 对称回交：将真实模块 Outbox/Inbox entity、migration、关系数据库 conformance 与故障测试报告链接到 [`G01-closeout.md`](../evidence/gates/G01/G01-closeout.md)，确认复用 G01 的 `ITransactionParticipant`、`TransactionProfile.Inbox` 和唯一事务政策且未复制另一套 Behavior/Executor 协议；据此回写 [`00-G01-transaction-boundary.md`](00-G01-transaction-boundary.md) 的 G01-9.3、G01-DD05 和状态，并发起 Architecture/Application/Infrastructure 三方最终签字。上述回交未完成时不得关闭 Plan 02 或 G01。
- [ ] E8.10 在 E2/E4 完成后执行 G02 对称回交：把每个真实 Outbox/Inbox entity、EF mapping、module-owned migration、schema-local history、fresh/upgrade/rollback/重复运行和数据库 metadata 报告链接到 [`G02-closeout.md`](../evidence/gates/G02/G02-closeout.md)，运行 `G02SqlServerAssertions` 并确认没有共享 Messaging DbContext、跨 schema FK/DDL/访问或新的 runtime migration 路径；据此回写 [`00-G02-database-boundary.md`](00-G02-database-boundary.md) 的 Phase 10、G02-DD06 和状态，并发起 Architecture/Database/Operations 三方最终签字。上述回交未完成时不得关闭 Plan 02 或 G02。

## 完成标准（Definition of Done）

- [x] E-D01 源业务数据与 Outbox 原子提交，rollback 不产生可投递事件。
- [x] E-D02 Dispatcher 只发布已提交事件，失败可重试且不会吞错。
- [x] E-D03 消费方通过 Inbound Adapter 转为内部 command，Application 不依赖外部 Contracts/transport。
- [x] E-D04 Inbox 与业务变更在消费方本地事务内完成，重复消息不产生重复业务效果。
- [x] E-D05 事件 schema 可版本化、可兼容、可追踪且不泄漏内部模型。
- [ ] E-D06 崩溃窗口、毒消息、回放、积压与告警均有自动化测试或演练证据。
- [ ] E-D07 Event Envelope、transport 和 Consumer ExecutionContext 的 Correlation/Causation/Tenant/Trace 语义与 Gate 05 一致，retry/replay 不改变逻辑身份。
- [ ] E-D08 Event、Outbox/Inbox、dead-letter、日志和 trace 满足字段分类；C4 零暴露，C3 仅有批准且受控的状态传输。
- [ ] E-D09 中英文说明、架构图、正常/失败流程图和规则证据完整且与实现一致。
- [ ] E-D10 E2/E4 的真实实现证据已按 E8.9 回交 G01，G01-9.3 与 G01-DD05 已有可审计链接，并已进入三方最终签字流程。
- [ ] E-D11 E2/E4 的真实数据库实现证据已按 E8.10 回交 G02，G02 Phase 10 与 G02-DD06 已有可审计链接，并已进入三方最终签字流程。
## G05 反向链接

真实 Outbox/Inbox/Dispatcher、quarantine/dead-letter/replay 必须实现 G05 Event Envelope、pre-Inbox 验证、失败矩阵、敏感诊断与兼容到期规则；回交条件见 [G05 双语设计](../gates/G05/context-sensitive-data-boundary.zh-CN.md) 和 [Plan 02 handoff](../gates/G05/handoffs/plan02-event-context-handoff.md)。
