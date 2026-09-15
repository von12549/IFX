# Plan 06 Phase 0 — 源码与协议基线

> 记录日期：2026-09-15；实施起点 `2e5a12d8ef0ae1c1de869b6e8275c8a8a011ae98`。
> 起点工作树已有本次会话新增的 Plan 06 与 plans/README 索引；无其他源码改动。以下是源码观察，不代表后续阶段或生产 Gate 已完成。

## 权威输入固定值

| 输入 | Git blob hash |
| --- | --- |
| G03 `contract-event-catalog.yaml` | `d16ad9738aa02e1cc99f2ad53e1d288809389a9f` |
| G03 `G03-sync-api-snapshot.json` | `457a501a7a7524f47b8dcda071956e34719cf3cd` |
| G03 `G03-serialization-golden.json` | `1bb65f88676ff736ab9656810677f5e0a31892f6` |
| G05 `context-protocol-v1.json` | `f0f3601a4fd108d13b24521596b2ac8b89c5e085` |
| B4 `B4-report.json` | `a82b7c4e8f5a309b0fb06cc8b2fa30412eb50460` |

G03 catalog 的四个实际 identity 为 `crm.account-compliance.v1`、`registry.class-subscription-availability.v1`、`ifx.transaction.transaction-processed.v1` 与 `ifx.registry.class-status-changed.v1`。Plan 06 不改变其 public API、序列化、字段分类、consumer 或 lifecycle。

## 编译期依赖与真实使用点

CRM、Registry、Transaction、IAM 的 Application 项目当前均直接引用各自的 `*.Contracts.csproj`。CRM 和 Registry Application 中分别有一个公开同步 Contract 实现；IAM `ResourceAuthorizationService` 同时实现本地服务和 `IAM.Contracts.V1` 接口。Registry `DeleteClassCommandHandler` 构造 `ClassStatusChangedV1`；Transaction 的 `ProcessTransactionCommandHandler` 与 `ConfirmOrderCommandHandler` 构造 `TransactionProcessedV1`。本次扫描未发现其他模块 Application 的 `Contracts.V1`/`Contracts.Events` 使用点。CRM/Registry 对 `IFX.Platform.Context.Contracts` 的引用属于 G03/G05 已批准的 context primitive，需与本模块公开版本化 Contracts 分开判断。

## 当前调用、装配与事务

```text
Transaction.Application Port
  -> Transaction.Infrastructure CRM/Registry Adapter（Composition 中各注册一次）
  -> CRM/Registry.Contracts.V1
  -> CRM/Registry.Application Contract 实现（Composition 中各注册一次）
  -> 提供方 Application 数据 Port -> 本模块 Infrastructure EF Adapter

CRM/Registry/Holdings/Transaction 授权出站 Adapter
  -> IAM.Contracts.V1 -> IAM.Application.ResourceAuthorizationService
  （IAM.Infrastructure 将同一 scoped 实例同时注册给本地服务和公开 Contract）

Registry/Transaction Application 直接把 V1 事件加入 ICommittedEventBuffer
  -> 本模块 OutboxParticipant.PrepareAsync 在提交前 Drain
  -> EventEnvelope + 本模块 DbContext.OutboxMessages
  -> 同一本地事务提交业务行与 Outbox
  -> Dispatcher/transport
  -> Holdings.Infrastructure 入站校验、反序列化、Inbox/命令
  -> Holdings.Application
```

`TransactionBehavior` 在成功响应后调用参与者 `PrepareAsync`；失败响应或异常清理 Buffer 并回滚/丢弃变更。计划只改变 Buffer 中的**内部事实类型及提交前映射位置**，不移动持久化时点、不改变本地事务所有者。

## 固定的验证和失败语义

G05 同步检查顺序为 `consumerAllowlist -> version -> scope -> actorSource -> tenantResource`；稳定结果包括 `contract_context_invalid`、`contract_consumer_denied`、`contract_tenant_mismatch`、`contract_timeout`、`contract_cancelled`、`contract_unavailable`。CRM/Registry 当前仅允许 `ifx.transaction.v1`，tenant-only 能力在读取数据前要求 trusted context、tenant scope 与请求 tenant 一致。IAM 当前允许 CRM/Registry/Holdings/Transaction 的 V1 caller，并比对本地可信执行上下文。消费方取消继续传播，超时和边界异常 fail closed。事件入口保持 Envelope/SchemaVersion、producer、tenant、Inbox 幂等和 quarantine 规则。

非目标：不更改公开 V1 形状与错误语义，不引入 V2、网络载体、独立发布、跨模块数据库访问或新的事务/消息存储表，不宣称 Plan 02 目标环境或 Gate Final Closure 已关闭。
