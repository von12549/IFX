# Target synchronous Contract flow / 目标同步 Contract 流程

> Status: proposed, not implemented.
>
> 状态：目标方案，尚未实现。

The example assumes Transaction needs current CRM and Registry facts before deciding whether to create an order.

以下以 Transaction 在创建订单前需要读取 CRM 和 Registry 当前事实为例。

```mermaid
sequenceDiagram
    autonumber
    actor Client
    participant TP as Transaction.Presentation
    participant TA as Transaction.Application
    participant Port as Transaction-owned Port
    participant Adapter as Transaction Integration Adapter
    participant Contract as CRM.Contracts
    participant Facade as CRM.Application Facade
    participant Domain as CRM Domain
    participant Repo as CRM Repository Port
    participant DbAdapter as CRM.Infrastructure Repository
    participant DB as CRM Database

    Client->>TP: Submit order
    TP->>TA: Send Transaction command
    TA->>Port: Get account compliance snapshot
    Port->>Adapter: DI dispatches to adapter
    Adapter->>Contract: Call provider public contract
    Contract->>Facade: DI dispatches to Application implementation
    Facade->>Repo: Load CRM-owned state
    Repo->>DbAdapter: DI dispatches to repository adapter
    DbAdapter->>DB: Query CRM schema
    DB-->>DbAdapter: state
    DbAdapter-->>Facade: CRM domain data
    Facade->>Domain: Evaluate CRM-owned compliance meaning
    Domain-->>Facade: compliance fact
    Facade-->>Adapter: typed contract result
    Adapter-->>TA: Transaction-owned snapshot/result
    TA->>TA: Apply Transaction-owned order policy
    TA-->>TP: success or expected business failure
    TP-->>Client: HTTP response
```

## Result semantics / 返回语义

The public synchronous result should not collapse every outcome into a Boolean. It should distinguish at least:

公开同步结果不应把全部结果压缩成 Boolean，至少应区分：

```text
Approved / NotApproved
NotFound
Denied
Unavailable or Timeout
InvalidRequest
```

Useful metadata may include a reason code, evaluated-at time, and source version. The provider reports its fact; the consumer applies its own business decision.

可选元数据包括原因码、评估时间和源数据版本。提供方报告事实，消费者据此执行自己的业务决策。

## Consistency note / 一致性说明

This is still not a distributed transaction. CRM state can change after the read and before Transaction commits. If that race violates a hard invariant, use an explicit reservation/authorization token with version checking, a coordinated workflow, or reconsider the module boundary.

该流程仍不是分布式事务。CRM 状态可能在读取后、Transaction 提交前发生变化。如果该竞态会破坏强业务不变量，应采用带版本检查的 reservation/authorization token、显式协调工作流，或者重新评估模块边界。

