# IFX 当前模块架构说明

> 文档状态：现状基线  
> 源码基线：`308d548`  
> 本文描述当前已经实现的行为，不描述目标方案。

## 1. 总体判断

IFX 当前是 ASP.NET Core 8 模块化单体，不是微服务。所有业务模块由一个 ApiHost 进程加载，但模块通过独立项目、独立 DbContext 和独立 SQL schema 建立边界。

当前业务模块包括 Auth、CRM、Registry、Holdings 和 Transaction。平台能力包括 Messaging、BackgroundJobs 和 Notifications。ApiHost 显式调用各模块的 `Add*Module`，然后通过 `IModuleInstaller` 枚举并映射模块 Endpoint。

相关图表：

- [当前架构图](diagrams/01-current-architecture.md)
- [当前通信流程图](diagrams/02-current-communication-flows.md)

## 2. 必须分别理解的四种边界

### 2.1 编译期边界

业务模块通常由 Domain、Application、Infrastructure、Presentation、Composition 组成；CRM、Registry、Holdings 和 Transaction 另有 Abstractions 项目。

跨模块代码原则上只引用对方 Abstractions，不引用对方 Domain、Application、Infrastructure 或 Presentation。当前主要关系是：

- Transaction.Application 引用 CRM.Abstractions 和 Registry.Abstractions。
- Holdings.Application 引用 Transaction.Abstractions 和 Registry.Abstractions。
- 各模块 Application 引用 Platform.Messaging.Abstractions 发布事件。
- 各模块 Composition 引用本模块各层，供 ApiHost 统一加载。

因此当前已经形成一定程度的编译期模块隔离，但 Application 仍直接知道其他模块的公开契约类型。

### 2.2 数据库边界

Auth、CRM、Registry、Holdings 和 Transaction 各自拥有 DbContext、EF migrations 与 SQL schema。Docker 默认把这些 schema 放在同一个 `IFXDb` 数据库中；Hangfire 使用独立数据库。

共享物理数据库不等于共享数据所有权。模块不应直接查询或写入其他模块的 DbContext 和表，也不应建立跨模块 schema 的业务外键。跨模块引用完整性由应用流程、同步契约查询和事件工作流维持。

### 2.3 事务边界

各模块 DbContext 不是同一个业务事务。即使它们连接同一个 SQL Server 数据库，当前代码也没有把源模块事务和消费模块事务纳入一个原子提交。

同步读取同样不提供跨模块原子性。例如 Transaction 检查 KYC 后，CRM 状态仍可能在 Transaction 提交前变化。这是 check-then-act 竞态，而不是把进程内调用改成 HTTP 就能解决的问题。

### 2.4 部署边界

全部模块目前由单一 ApiHost 部署。模块不能独立扩缩容、独立发布或独立故障隔离。`IModuleInstaller` 是统一装配规范，不是运行时动态插件机制，因为 Program.cs 仍显式注册各模块。

## 3. 当前 Abstractions 的职责

当前模块 Abstractions 同时包含三类内容：

1. 跨模块同步读取接口，例如 `ICrmReader` 和 `IRegistryReader`。
2. 跨模块 DTO，例如 `PartySummaryDto`、`ClassSummaryDto` 和 `HoldingSummaryDto`。
3. Integration Event，例如 `TransactionProcessedEvent` 和 `ClassStatusChangedEvent`。

从意图上看，Abstractions 是模块的公开通信契约，而不是 Clean Architecture 的第五个业务层。它与 Application 内部使用的 Repository、Unit of Work 或外部服务 Port 不属于同一类接口。

## 4. 当前同步通信

Transaction 创建订单或交易时，通过 `ICrmReader` 检查投资账户 KYC，通过 `IRegistryReader` 检查 Fund Class 是否允许申购。

运行路径为：

```text
Transaction.Application
  → CRM/Registry Abstractions interface
  → CRM/Registry Infrastructure Reader
  → provider DbContext
```

这种模式的优点是调用简单、进程内延迟低，而且消费者没有引用提供方内部实现。

当前缺点包括：

- Reader 实现直接使用 DbContext，绕过提供方 Application 的公开用例入口。
- `IsInvestmentAccountKycApprovedAsync` 包含账户关系与 KYC 聚合判断，已经不仅是机械数据读取。
- `ICrmReader` 和 `IRegistryReader` 暴露的方法多于当前真实跨模块需求。
- `IHoldingsReader` 和 `ITransactionReader` 当前没有生产代码中的跨模块消费者，属于提前公开的能力。
- `Task<bool>` 无法区分 NotApproved、NotFound、Denied、Timeout 和 Unavailable。
- `ITransactionReader.GetTransactionByIdAsync`、`GetOrderByIdAsync` 及 `IHoldingsReader.GetHoldingByIdAsync` 没有显式 tenantId，公开使用时可能绕开租户边界。

## 5. 当前事件通信

Application Handler 在保存源模块数据后，通过 `IIntegrationEventBus` 发布 Integration Event。当前总线实现是 `InMemoryIntegrationEventBus`，它在同一进程内同步解析所有 Handler 并依次执行。

典型流程是：

```text
Transaction.Application
  → TransactionProcessedEvent
  → InMemoryIntegrationEventBus
  → Holdings.Application EventHandler
  → Holdings DbContext
```

当前实现的重要风险：

- 事件在源模块事务提交前处理。
- Holdings 使用自己的 DbContext 保存，不与 Transaction 共享原子事务。
- 总线捕获消费异常后只记录日志，不重新抛出。
- Transaction 可能成功、Holdings 失败。
- Holdings 也可能先成功，而 Transaction 随后提交失败。
- 没有持久化 Outbox、Inbox、重试计划、死信和幂等消费记录。
- TransactionBehavior 只根据异常回滚，不检查 `Result.IsSuccess`；Handler 捕获异常并返回 Failure 时，管道仍然提交。

## 6. 当前事件能否替代同步读取

不能直接替代。Event Notification 表达“某件事情已经发生”，不能回答“当前状态是什么”。消费者只有在订阅足够完整的事件并维护自己的本地投影后，才可能避免同步查询。

当前 CRM 事件不足以重建投资账户 KYC 状态：Investor KYC 事件没有账户关联，InvestmentAccountCreated 事件没有 Party/Investor 关联，也没有覆盖所有账户链接变化的 Integration Event。Registry 的 Class 状态投影较简单，但当前总线仍缺少可靠投递与重建能力。

## 7. 架构规则漂移

`src/layerguard.json` 的 `X-1` 当前禁止任何 ring 引用自己模块的 `.Abstractions`。实际代码中 CRM、Registry、Holdings 和 Transaction 的 Application 都引用自己的 Abstractions，用于事件或 DTO。

这说明规则和实现尚未统一。该冲突不能只靠删除引用解决；首先需要确定 Abstractions 是公开 Contracts 还是内部层。目标方案建议将其定义为公开 Contracts，并重新制定精确规则，而不是对所有本模块引用一律禁止。

## 8. 当前架构结论

当前模式方向上是健康的：跨模块依赖已经限制在公开契约层，数据库所有权也基本明确。主要问题不是存在 Abstractions，而是：

- 公开契约范围偏大；
- 内部 DTO 和公开 DTO 有混用；
- 提供方业务查询实现在 Infrastructure；
- 消费者 Application 直接依赖提供方契约；
- 消息机制没有可靠性边界；
- 跨模块一致性语义没有显式建模。

这些问题构成目标 Contracts/Adapters/Events 架构的改进起点。

## 9. 源码核对入口

| 主题 | 源码 |
|---|---|
| ApiHost 模块加载与 Endpoint 映射 | [`Program.cs`](../../../src/ApiHost/IFX.ApiHost/Program.cs) |
| Transaction 对 CRM/Registry Contracts 的项目引用 | [`IFX.Modules.Transaction.Application.csproj`](../../../src/Modules/Transaction/IFX.Modules.Transaction.Application/IFX.Modules.Transaction.Application.csproj) |
| 当前同步 KYC/Class 查询 | [`CreateOrderCommandHandler.cs`](../../../src/Modules/Transaction/IFX.Modules.Transaction.Application/Commands/CreateOrder/CreateOrderCommandHandler.cs) |
| CRM Reader 与直接 DbContext 查询 | [`CrmReader.cs`](../../../src/Modules/CRM/IFX.Modules.CRM.Infrastructure/Services/CrmReader.cs) |
| Registry Reader 与直接 DbContext 查询 | [`RegistryReader.cs`](../../../src/Modules/Registry/IFX.Modules.Registry.Infrastructure/Services/RegistryReader.cs) |
| Transaction 保存与事件发布 | [`ProcessTransactionCommandHandler.cs`](../../../src/Modules/Transaction/IFX.Modules.Transaction.Application/Commands/ProcessTransaction/ProcessTransactionCommandHandler.cs) |
| Transaction 管道事务 | [`TransactionBehavior.cs`](../../../src/Modules/Transaction/IFX.Modules.Transaction.Application/Behaviors/TransactionBehavior.cs) |
| 当前同步内存事件总线 | [`InMemoryIntegrationEventBus.cs`](../../../src/Platform/Messaging/IFX.Platform.Messaging.Infrastructure.InMemory/InMemoryIntegrationEventBus.cs) |
| Holdings 事件消费与保存 | [`TransactionProcessedEventHandler.cs`](../../../src/Modules/Holdings/IFX.Modules.Holdings.Application/EventHandlers/TransactionProcessedEventHandler.cs) |
| 当前架构检查规则 | [`layerguard.json`](../../../src/layerguard.json) |
