# Plan 02 / B3：可靠 Integration Event 实施基线

> 状态：B3 仓库实现完成；生产告警校准、consumer-first 演练和最终 Gate 签字仍保持开放。英文版见 [plan02-reliable-events.en.md](plan02-reliable-events.en.md)。

## 已实施边界

仓库只准入两个生产方拥有的不可变 V1 事实：Transaction 的 `ifx.transaction.transaction-processed.v1` 与 Registry 的 `ifx.registry.class-status-changed.v1`。两者位于生产方 Contracts，payload 不携带 TenantId；可信租户、EventId、发生时间、Correlation/Causation 和 trace carrier 由 Platform Messaging 在写入 Outbox 时冻结到 Envelope。其余 20 个旧事件声明全部删除并在 G03 目录保留为 Retired 历史身份；CRM KYC 继续使用 Plan 01 的同步 Contract。

Transaction 与 Registry 分别在自己的 DbContext/schema 中拥有 Outbox。G01 的唯一 `TransactionBehavior` 和 `ITransactionParticipant` 在业务事务提交前写入不可变逻辑消息；业务失败或 rollback 不留下可投递记录。可变的 attempt、lease、next-attempt、error 和 delivery 状态与 Envelope/payload 物理分列。

Dispatcher 位于 `IFX.Platform.Messaging.Runtime`，但 ApiHost 只能经 `IFX.Platform.Messaging.Composition` 装配。只有 `worker`/`all` role 启动 Dispatcher；`api` 不启动。每次 claim 使用 SQL Server `UPDLOCK/READPAST/ROWLOCK`、短事务、唯一 owner、租约和 rowversion；发送发生在事务外，完成/失败按原租约条件更新。失败向上传递到指数退避、抖动和有界 dead-letter 状态机。

Holdings 的外部 DTO 解析与验证位于 Infrastructure 的 `Integrations` 边界。Adapter 在调用 Application 前验证 producer、event type/version 和 tenant scope，随后以 EventId 作为 OperationId 建立隔离 ExecutionContext，并映射为 Holdings 自有 command。Application 不引用生产方 Contracts 或 Runtime。`TransactionProfile.Inbox` 在同一 Holdings 事务中完成去重、业务变更和 Inbox 记录；唯一键为 `(ConsumerId, EventId)`。非法 producer/tenant/payload 与业务拒绝进入只保存安全诊断字段的 quarantine。

## 交付语义与恢复

语义是 at-least-once。发送成功但完成标记前崩溃会导致同一 EventId 重投；Inbox 吸收重复。每个业务分区只在较早 Pending 消息不存在时 claim，避免同分区越序；不承诺全局顺序。dead-letter 回放只重置 delivery metadata，保留原 Envelope 和 payload。诊断查询只返回 EventId、类型、租户引用、时间、状态、次数与错误码，不返回 payload。

当前 transport 是进程内实现，它创建消费 scope 且不吞异常；替换 broker 只需实现 Runtime 的 sender 边界。生产运维必须使用 [可靠事件运行手册](runbooks/plan02-reliable-events.md)，先 dry-run 查询再授权回放，禁止换 EventId 绕过 Inbox。

## 数据与安全

事件 payload 最高为 C2；没有 C4、姓名、账号、凭据或自由文本错误。日志只写 module、低基数 event type、EventId 和 attempt，不写 payload。Outbox/Inbox/quarantine 随模块数据库的访问、加密、保留和删除策略治理。trace 只是技术关联信息，不作为租户或授权来源。

## 验证与剩余外部条件

自动化覆盖 provider schema/golden、未知字段兼容、生产者事件、业务与 Outbox 原子性、claim/lease、错误传播、重试/dead-letter/replay identity、Inbox 去重、quarantine、上下文隔离及端到端映射。关系数据库用例已编译并接入标准 Testcontainers fixture；本机 Docker daemon 不可用时只能记录为环境阻塞，不能冒充已执行通过。

B3 LayerGuard 在受治理 Runtime ring 下为 32 matched / 0 new / 0 stale，较 B2 删除 71 个历史 finding。B4 仍负责清零其余 32 个历史 finding。生产容量校准、告警接线、consumer-first 发布演练和各 Gate 最终多人签字不属于仓库内可自证事实，继续保持开放。

图： [已实施架构](diagrams/plan02-reliable-events-architecture.svg)、[正常时序](diagrams/plan02-reliable-events-sequence.svg)、[失败与恢复](diagrams/plan02-reliable-events-recovery.svg)。
