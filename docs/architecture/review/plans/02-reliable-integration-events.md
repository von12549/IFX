# 子计划 2：可靠 Integration Event 改进

> 状态：Draft / 待评审
> 上级计划：[`00-master-plan.md`](00-master-plan.md)
> 前置关系：公共事件 schema 依赖子计划 1 的 Contracts 结构和 [`00-G03-contract-event-governance.md`](00-G03-contract-event-governance.md) 的事件目录、identity、版本/兼容政策；原子保存依赖事务与数据库 Gate。
> 运行前置：[`00-G04-deployment-runtime-boundary.md`](00-G04-deployment-runtime-boundary.md) 定义 API/Worker roles、instance identity、多实例 lease、health、drain、backpressure 和 consumer-first 发布顺序。

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

- [ ] **Phase 0 完成**：本 Phase 下全部项目均已完成并附有证据。

- [ ] E0.1 从 Gate 03 权威目录导入所有事件类型、发布点、处理器、模块所有者、触发事务和实际消费者，并与源码对账；新增或重分类先更新目录。
- [ ] E0.2 将现有事件分类为 Domain Event、Integration Event、进程内通知或错误地用于状态传输的消息。
- [ ] E0.3 为每个 Integration Event 明确“已发生的事实”、生产方、消费方、交付要求和可接受延迟。
- [ ] E0.4 识别当前 Transaction 在 `SaveChanges` 后、`TransactionBehavior` 提交前调用 `PublishAsync` 的崩溃与可见性窗口。
- [ ] E0.5 识别当前 `InMemoryIntegrationEventBus` 顺序调用且吞掉 handler 异常造成的不可重试、假成功问题。
- [ ] E0.6 明确事件顺序要求：默认只保证同聚合/同分区内的必要顺序，不声明全局顺序。
- [ ] E0.7 明确保留期、重复容忍、敏感字段、事件大小和 schema 兼容政策。
- [ ] E0.8 验证前置计划 Gate 1 的事务语义已经批准；未通过时不得进入 Outbox/Inbox 实现。

## Phase 1 — 定义事件契约与 Envelope

- [ ] **Phase 1 完成**：本 Phase 下全部项目均已完成并附有证据。

- [ ] E1.1 将生产方拥有且已通过 Gate 03 准入的 Integration Event schema 放入生产方 Contracts，并与 Domain Event 类型完全分离。
- [ ] E1.2 采用过去时、业务事实命名，禁止把“请执行某操作”的命令伪装为事件。
- [ ] E1.3 定义统一 envelope，至少包含 EventId、EventType、SchemaVersion、OccurredAt、TenantId、CorrelationId 与 CausationId。
- [ ] E1.4 定义 trace、actor/source 与 content type 等可选元数据的传播规则，避免把认证凭据写入事件。
- [ ] E1.5 确保 payload 不引用 Domain Entity、EF 类型、内部枚举实现或消费方模型。
- [ ] E1.6 为向后兼容、并行版本、未知字段和废弃窗口建立可自动验证的规则。
- [ ] E1.7 评审 CRM 当前事件是否足以构建账户 KYC 投影；若不足，设计最小事实事件或明确继续使用同步 Contract。
- [ ] E1.8 为关键事件保存序列化 golden files，作为 schema 回归基线。
- [ ] E1.9 建立 BCL-only `IFX.Platform.Messaging.Contracts` schema primitives；bus、handler、dispatcher、DI、serializer 和 broker 端口/实现不得进入模块 Contracts 依赖。

## Phase 2 — 生产方 Transactional Outbox

- [ ] **Phase 2 完成**：本 Phase 下全部项目均已完成并附有证据。

- [ ] E2.1 为每个事件生产模块设计自己 schema 内的 Outbox 表、EF 映射和 migration，不建立跨模块表依赖。
- [ ] E2.2 定义 Outbox 状态、尝试次数、下一次尝试时间、锁租约、创建/发布时间和最后错误字段。
- [ ] E2.3 在 Application/Domain 完成业务结果后生成 Integration Event snapshot，不把可变实体交给异步发布器。
- [ ] E2.4 在同一 DbContext、本地数据库事务内原子写入业务变更与 Outbox 记录。
- [ ] E2.5 移除业务 handler 中提交前直接 `PublishAsync` 的路径，确保 rollback 时没有可投递 Outbox。
- [ ] E2.6 验证前置计划 TX2/TX3 的 commit/rollback 语义在 Outbox 写入路径中仍然成立，防止失败结果及其 Outbox 被提交。
- [ ] E2.7 处理序列化失败，使业务事务明确失败并产生可诊断错误，而不是提交一半状态。
- [ ] E2.8 添加数据库级测试，证明业务数据与 Outbox 在成功时同时存在、失败时同时不存在。

## Phase 3 — 提交后 Dispatcher 与可替换 Transport

- [ ] **Phase 3 完成**：本 Phase 下全部项目均已完成并附有证据。

- [ ] E3.1 按 Gate 04 实现 Outbox Dispatcher：只读取已提交记录，使用短事务有界 claim、唯一 LeaseOwner/LeaseUntil/concurrency token、事务外发送与条件完成。
- [ ] E3.2 在 `worker`/`all` role 启动 Dispatcher，按 Gate 04 定义多 Worker 实例竞争、critical loop failure 和优雅 drain；`api` role 不启动 Dispatcher。
- [ ] E3.3 把 transport 抽象限制在投递职责；当前可适配进程内总线，未来可替换消息 broker 而不改 Application。
- [ ] E3.4 修复总线错误语义：handler/transport 失败不得被吞掉，必须反馈给重试状态机。
- [ ] E3.5 实现指数退避、最大尝试次数、抖动与可配置超时，避免热循环和级联故障。
- [ ] E3.6 明确 Outbox 的 delivered、retrying、dead-lettered 状态转换和并发更新策略。
- [ ] E3.7 增加 backlog、oldest age、success/failure rate、retry count 与 dead-letter count 指标及结构化日志。
- [ ] E3.8 验证进程在“发送前、发送后标记前、标记后”三个时点崩溃时均不会丢失已提交事件。
- [ ] E3.9 实现 per-module backlog/lease/last-success Health Contributor 和 warning/critical backpressure 接缝。

## Phase 4 — 消费方 Inbound Adapter、Inbox 与幂等

- [ ] **Phase 4 完成**：本 Phase 下全部项目均已完成并附有证据。

- [ ] E4.1 将当前直接位于 Holdings.Application 的外部事件 handler 迁移至 Holdings 外层 Inbound Integration Adapter。
- [ ] E4.2 让 Adapter 引用生产方 Contracts，并把外部 event DTO 映射为 Holdings.Application 自有 command。
- [ ] E4.3 确认 Holdings.Application 不再引用生产方 Contracts 或 transport SDK。
- [ ] E4.4 为每个消费模块设计自己 schema 内的 Inbox 表、唯一 EventId 约束、处理状态和诊断字段。
- [ ] E4.5 在同一本地事务内完成 Inbox 去重判定、消费方业务变更与 Inbox 完成记录。
- [ ] E4.6 为无法天然幂等的副作用设计幂等键、状态机或下游幂等协议，不仅依赖内存锁。
- [ ] E4.7 明确业务拒绝、暂时故障、永久无效 schema 与未知事件类型各自的 ack/retry/dead-letter 行为。
- [ ] E4.8 添加重复、并发重复、乱序、跨租户和处理器崩溃测试。

## Phase 5 — 事件内容与投影策略改进

- [ ] **Phase 5 完成**：本 Phase 下全部项目均已完成并附有证据。

- [ ] E5.1 评审 `TransactionProcessed` 的事实语义、字段最小性、版本和重放安全性，并发布稳定 v1。
- [ ] E5.2 为 Class 状态变化决定使用同步查询、事件投影或二者组合，并明确新鲜度与 TOCTOU 风险。
- [ ] E5.3 为 KYC 状态变化决定是否建立消费方本地投影；若建立，补齐能重建投影的事实事件和初始快照流程。
- [ ] E5.4 定义投影 bootstrap、断点续传、重建、版本切换与最终一致状态下的业务降级策略。
- [ ] E5.5 为会触发后续命令的事件处理定义 correlation/causation 链，避免循环发布无法诊断。
- [ ] E5.6 明确事件数据删除、隐私与审计保留策略，不让 payload 成为不可治理的数据副本。

## Phase 6 — 失败恢复、回放与运维

- [ ] **Phase 6 完成**：本 Phase 下全部项目均已完成并附有证据。

- [ ] E6.1 提供按 EventId、时间区间、事件类型和租户查询 Outbox/Inbox 状态的受控诊断能力。
- [ ] E6.2 提供 dead-letter 审核和单条/批量重试流程，并要求权限、审计与 dry-run。
- [ ] E6.3 定义重复回放的安全门槛，回放前验证目标 handler 版本与幂等保证。
- [ ] E6.4 建立生产方与消费方 reconciliation 作业或手册，用于发现永久遗漏和投影漂移。
- [ ] E6.5 设置 backlog age、连续失败、dead-letter 增长和 dispatcher 停止的告警阈值。
- [ ] E6.6 编写故障手册，覆盖数据库不可用、transport 不可用、毒消息、schema 不兼容和积压恢复。

## Phase 7 — 测试、渐进发布与旧路径移除

- [ ] **Phase 7 完成**：本 Phase 下全部项目均已完成并附有证据。

- [ ] E7.1 添加 Outbox/Inbox repository、dispatcher、Adapter 与 handler 单元/组件测试。
- [ ] E7.2 添加包含真实关系数据库的集成测试，覆盖事务 rollback、唯一约束和并发 claim。
- [ ] E7.3 添加端到端测试，证明源提交最终导致消费方状态变化，并能容忍重复与短暂故障。
- [ ] E7.4 执行故障注入测试，覆盖进程终止、连接中断、超时、部分批次和重启恢复。
- [ ] E7.5 执行 Gate 04 consumer-first 顺序：先部署兼容旧/新 schema 的 Worker consumers，再部署 API producers；定义去重、观测窗口和唯一权威路径。
- [ ] E7.6 在指标达到验收门槛后关闭旧的同步直发/直接 handler 路径，并删除无用注册。
- [ ] E7.7 将实际 schema、版本、发布/消费责任人、兼容状态和 retire 证据回写 Gate 03 权威目录，并更新运维 runbook。

## 完成标准（Definition of Done）

- [ ] E-D01 源业务数据与 Outbox 原子提交，rollback 不产生可投递事件。
- [ ] E-D02 Dispatcher 只发布已提交事件，失败可重试且不会吞错。
- [ ] E-D03 消费方通过 Inbound Adapter 转为内部 command，Application 不依赖外部 Contracts/transport。
- [ ] E-D04 Inbox 与业务变更在消费方本地事务内完成，重复消息不产生重复业务效果。
- [ ] E-D05 事件 schema 可版本化、可兼容、可追踪且不泄漏内部模型。
- [ ] E-D06 崩溃窗口、毒消息、回放、积压与告警均有自动化测试或演练证据。
