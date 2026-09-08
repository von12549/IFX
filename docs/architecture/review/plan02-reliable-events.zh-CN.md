# Plan 02 / B3：可靠 Integration Event 实施基线

> 状态：B3 仓库实现完成；生产告警校准、consumer-first 演练和最终 Gate 签字仍保持开放。英文版见 [plan02-reliable-events.en.md](plan02-reliable-events.en.md)。

## 已实施边界

仓库只准入两个生产方拥有的不可变 V1 事实：Transaction 的 `ifx.transaction.transaction-processed.v1` 与 Registry 的 `ifx.registry.class-status-changed.v1`。两者位于生产方 Contracts，payload 不携带 TenantId；可信租户、EventId、发生时间、Correlation/Causation 和 trace carrier 由 Platform Messaging 在写入 Outbox 时冻结到 Envelope。其余 20 个旧事件声明全部删除并在 G03 目录保留为 Retired 历史身份；CRM KYC 继续使用 Plan 01 的同步 Contract。

Transaction 与 Registry 分别在自己的 DbContext/schema 中拥有 Outbox。G01 的唯一 `TransactionBehavior` 和 `ITransactionParticipant` 在业务事务提交前写入不可变逻辑消息；业务失败或 rollback 不留下可投递记录。可变的 attempt、lease、next-attempt、error 和 delivery 状态与 Envelope/payload 物理分列。

Dispatcher 位于 `IFX.Platform.Messaging.Runtime`，但 ApiHost 只能经 `IFX.Platform.Messaging.Composition` 装配。只有 `worker`/`all` role 启动 Dispatcher；`api` 不启动。每次 claim 使用 SQL Server `UPDLOCK/READPAST/ROWLOCK`、短事务、唯一 owner、租约和 rowversion；发送发生在事务外，完成/失败按原租约条件更新。失败向上传递到指数退避、抖动和有界 dead-letter 状态机。标准 `System.Diagnostics.Metrics` meter 发布 attempt/success/failure/dead-letter counters 以及 backlog age/count、retry、lease、expired lease 和处理速率 gauges；readiness contributor 按模块应用 G04 warning/critical 阈值。

Holdings 的外部 DTO 解析与验证位于 Infrastructure 的 `Integrations` 边界。Adapter 在调用 Application 前验证 producer、event type/version 和 tenant scope，随后以 EventId 作为 OperationId 建立隔离 ExecutionContext，并映射为 Holdings 自有 command。Application 不引用生产方 Contracts 或 Runtime。`TransactionProfile.Inbox` 在同一 Holdings 事务中完成去重、业务变更和 Inbox 记录；唯一键为 `(ConsumerId, EventId)`。非法 producer/tenant/payload 与业务拒绝进入只保存安全诊断字段的 quarantine。

## 交付语义与恢复

语义是 at-least-once。发送成功但完成标记前崩溃会导致同一 EventId 重投；Inbox 吸收重复。每个业务分区只在较早 Pending 消息不存在时 claim，避免同分区越序；不承诺全局顺序。dead-letter 回放只重置 delivery metadata，保留原 Envelope 和 payload。诊断查询只返回 EventId、类型、租户引用、时间、状态、次数与错误码，不返回 payload。

当前 transport 是进程内实现，它创建消费 scope 且不吞异常；替换 broker 只需实现 Runtime 的 sender 边界。平台作用域管理端点提供只含 metadata 的 Outbox/Inbox 查询、回放预演和正式回放；三种动作使用独立 permission，回放批次上限为 100，必须写 operator audit，并先通过配置化 handler 版本门禁。生产运维必须使用 [可靠事件运行手册](runbooks/plan02-reliable-events.md)，禁止换 EventId 绕过 Inbox。

## 投影与数据生命周期

Class 状态在 Holdings 中是安全保护投影：Registry 的 `ClassStatusChangedV1` 是增量权威事实，Holdings 写路径只读取本地冻结状态，避免在本地事务中进行跨模块 TOCTOU 查询。上线 bootstrap 先取得 Registry 有界快照及 checkpoint，再按 EventId/发生顺序补放 checkpoint 后事件；中断后从最后完成的 Inbox marker 继续。重建写入新版本投影，完成数量与抽样 reconciliation 后原子切换读取版本，旧版本延迟删除。投影落后或健康状态 critical 时，涉及 Closed/Liquidating class 的风险写入 fail safe 拒绝，查询可返回带 freshness 的降级结果。

consumer 建立的下游命令/事件保留原 CorrelationId，并以入站 EventId 作为 OperationId 和下一跳 CausationId；Inbox 唯一键终止重复链，禁止事件类型互相无条件回发。Outbox payload 只保留 C0–C2 最小事实，诊断和审计不返回 payload。payload、delivery metadata、Inbox 与 quarantine 服从各模块保留/删除和 legal-hold 流程；删除业务主体数据时必须同步评估可重放窗口，过期后删除 payload 或整行，但保留的审计字段不得反向重建敏感业务数据。生产加密、访问组、保留 job 与删除证明仍是部署验收项。

## 数据与安全

事件 payload 最高为 C2；没有 C4、姓名、账号、凭据或自由文本错误。日志只写 module、低基数 event type、EventId 和 attempt，不写 payload。Outbox/Inbox/quarantine 随模块数据库的访问、加密、保留和删除策略治理。trace 只是技术关联信息，不作为租户或授权来源。

## 验证与剩余外部条件

自动化覆盖 provider schema/golden、未知字段兼容、生产者事件、业务与 Outbox 原子性、并发 claim/分区顺序、三个崩溃窗口、错误传播、重试/dead-letter/replay identity、Inbox 普通与并发去重、quarantine、上下文清理/下游 causation、受权诊断与端到端映射。关系数据库用例使用标准 SQL Server Testcontainers fixture。

B3 LayerGuard 在受治理 Runtime ring 下为 32 matched / 0 new / 0 stale，较 B2 删除 71 个历史 finding。B4 仍负责清零其余 32 个历史 finding。生产容量校准、告警接线、consumer-first 发布演练和各 Gate 最终多人签字不属于仓库内可自证事实，继续保持开放。

图： [已实施架构](diagrams/plan02-reliable-events-architecture.svg)、[正常时序](diagrams/plan02-reliable-events-sequence.svg)、[失败与恢复](diagrams/plan02-reliable-events-recovery.svg)。
