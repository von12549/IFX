# IFX 目标 Contracts、Adapters 与 Events 架构

> 文档状态：架构评审目标方案  
> 当前状态：Plan 01/B2、Plan 02/B3 已形成历史实现；[Plan 06](plans/06-contract-adapter-event-boundary.md) 正在迁移公开入口与事件映射位置。
> 用途：记录当前目标职责、架构规则和测试策略。

## 1. 目标与非目标

目标是在保留模块化单体低延迟和单一部署便利性的同时，加强模块编译期独立性、业务职责归属、数据所有权和未来微服务可迁移性。

本方案不要求立即拆分微服务，也不建议在单一 ApiHost 内为了模拟微服务而强制使用 localhost HTTP。进程内接口调用仍是合法且高效的模块 API；关键在于调用只经过稳定 Contracts 和 Adapter。

相关图表：

- [目标总体架构图](diagrams/03-target-contracts-adapters-events-architecture.md)
- [目标同步 Contract 流程](diagrams/04-target-synchronous-contract-flow.md)
- [目标可靠 Integration Event 流程](diagrams/05-target-integration-event-flow.md)
- [目标 DI 装配流程](diagrams/06-target-di-composition-flow.md)

## 2. 核心术语

### 2.1 Contracts

Contracts 是模块对外承诺的稳定协议，不是 Clean Architecture 的新业务层，也不是实现程序集。建议将现有 `<Module>.Abstractions` 的职责收敛并明确为 `<Module>.Contracts`。

Contracts 可以包含：

- 小而内聚的同步查询或命令接口；
- 专门设计的 Request/Response DTO；
- Integration Event schema；
- 必要的公开错误码、枚举和版本信息。

Contracts 不应包含：

- Handler、Repository、Unit of Work 或 DbContext；
- EF Entity、内部 Domain Entity 或内部 Application DTO；
- DI 注册、消息发送实现、HTTP Client；
- 业务规则和数据访问逻辑。

Contracts 本身不会加载实现。实现由拥有该能力的模块提供，并由该模块 Composition 注册到共享 DI 容器。

### 2.2 Consumer-owned Port

消费者 Application 根据自身用例定义所需能力，例如 Transaction 可以定义 `IAccountComplianceSource`。这个 Port 描述 Transaction 需要什么，不描述 CRM 如何提供。

严格模式下，Transaction.Application 不直接引用 CRM.Contracts。这样消费者核心不受提供方类型、传输方式和版本变化直接影响。

### 2.3 Integration Adapter

Integration Adapter 是外层 Adapter，架构角色属于 Infrastructure。初期可以放在：

```text
IFX.Modules.Transaction.Infrastructure/Integrations/Outbound/CRM
```

只有当 Adapter 数量、技术差异或独立部署需求增加时，才需要拆成独立项目，例如 `IFX.Modules.Transaction.Integration.CRM`。即使独立成项目，它也不是新的业务层。

出站 Adapter：

- 实现消费者自己的 Application Port；
- 引用提供方 Contracts；
- 对多模块共用且语义完全一致的调用，可委托 provider-owned Client；具体 Adapter 仍固定 consumer identity 并保留本模块 Port；
- 转换 Request/Response；
- 归一化 NotFound、Denied、Unavailable、Timeout 等技术结果；
- 将来可从进程内实现替换成 HTTP/gRPC Client。

提供方同步入站 Adapter：

- 位于提供方 `Infrastructure/Integrations/Inbound`，实现提供方公开 V1 接口；
- 选择不可变入口 policy，并在调用 Application 前委托 `IFX.Platform.Context.Runtime` 验证受控 consumer、context/source version、scope、可信执行上下文与资源 tenant；
- 使用同一 Runtime 建立隔离的提供方执行 scope，将公共 DTO 转换为 Application 自有用例输入；
- 将取消、业务结果和边界故障映射为稳定的公开语义，不承载业务授权或数据规则。

入站事件 Adapter：

- 引用生产者 Event Contracts；
- 验证 envelope 与版本；
- 执行 Inbox 幂等检查；
- 将外部事件转换为消费者自己的 Application Command；
- 不直接承载消费者业务规则。

### 2.4 Presentation

Presentation 是 HTTP 入站 Adapter，而不是给 ApiHost 使用的业务接口。它负责路由、模型绑定、HTTP 授权元数据和 HTTP 结果转换，然后调用 Application。它不包含业务规则，也不直接访问数据库。

### 2.5 Composition 与 ApiHost

模块负责实现自己的能力，模块 Composition 负责注册这些实现，ApiHost 负责调用每个模块注册入口并构建统一 DI 容器。

```text
实现所有权：能力所属模块
注册所有权：该模块 Composition
全局加载：ApiHost composition root
```

ApiHost 不应直接知道或注册模块的具体业务实现，否则它会成为新的耦合中心。

## 3. 目标编译期依赖规则

### 3.1 Domain

- 只包含领域实体、值对象、领域服务、领域事件和领域不变量。
- 不引用本模块 Contracts、Application、Infrastructure、Presentation 或其他业务模块。
- 不包含 Integration Event；Domain Event 与 Integration Event 必须区分。

### 3.2 Application

- 引用自己的 Domain。
- 拥有自有用例、Port 和内部业务事实；不引用本模块公开版本化 `*.Contracts`。
- 定义本模块用例所需的 consumer-owned ports。
- 严格模式下不引用其他业务模块 Contracts。
- 不引用 DbContext、EF Core、HTTP Client 或消息代理实现。

### 3.3 Contracts

- 不引用自己的 Application、Infrastructure 或 Presentation。
- 不引用其他业务模块。
- 尽量只依赖 .NET 基础类型；事件 envelope 如需共享基类，只能依赖极小且稳定的消息契约程序集。
- 不通过共享 Domain 类型建立隐式耦合。

### 3.4 Infrastructure 与 Integration Adapters

- Infrastructure 实现本模块 Application/Domain 定义的技术 Port。
- 提供方 Infrastructure 入站 Adapter 实现自己的公开 Contract；生产方 Outbox 参与者将内部事实映射为公共 V1 事件。
- 出站 Adapter 可以引用提供方 Contracts，但不得引用提供方 Application、Domain 或 Infrastructure。
- 不得读取或写入其他模块的 DbContext、schema 或 Repository。
- 入站消息 Handler 将外部事件转换为本模块 Application Command。
- 同步 Contract Adapter 可引用 `IFX.Platform.Context.Runtime`；只有 Infrastructure/Composition 可以引用 provider-owned `IFX.Modules.IAM.Client`。
- IAM Client 负责版本化 IAM DTO、context 构造和统一拒绝映射，但不能实现或替换消费者 Application Port。

### 3.5 Presentation

- 引用自己的 Application；必要时引用专用 HTTP Models。
- 不直接使用 Repository 或 DbContext。
- 不向其他模块提供可直接调用的 Application 实现。

### 3.6 Composition

- 是汇总本模块 Contracts、Application、Infrastructure、Presentation 和 Adapter 注册的装配项目；Infrastructure 本身也需引用自有 Application 与公开 Contracts 以实现入口。
- 注册公共 Contract 到本模块 Infrastructure Inbound Adapter 的映射，以及该 Adapter 到 Application 用例的映射。
- 注册消费者 Port 到 Integration Adapter 的映射。
- 注册入站 Integration Event Handler。

## 4. 同步跨模块查询

当消费者必须在当前请求中获得较新的提供方事实时，使用同步 Contract。IFX 中 KYC 与 Fund Class availability 当前更适合这种模式。

目标路径：

```text
Transaction.Application
  → Transaction-owned Port
  → Transaction CRM/Registry Adapter
  → IFX.Platform.Context.Runtime 构造 outbound context
  → provider Contracts
  → provider Infrastructure Inbound Adapter
  → IFX.Platform.Context.Runtime 验证并构造 provider child context
  → provider Application UseCase
  → provider Domain/Repository Port
  → provider Infrastructure
```

公开 Contract 应按业务能力拆分，而不是使用不断扩张的通用 Reader。建议方向包括：

- CRM 暴露账户合规事实，不暴露“是否允许创建 Transaction 订单”的决定。
- Registry 暴露 Fund Class 状态或申购可用性事实。
- Transaction 根据这些事实执行自己的订单创建规则。

当前 V1 的 CRM/Registry 成功响应使用布尔业务事实，边界失败通过稳定 Contract 错误码表达；`false` 包含未批准、关闭或不存在的现有语义。若未来需要进一步区分业务拒绝、不存在或携带 evaluated-at/source version，应按 G03 兼容性规则新增字段或 V+1，不能在 Plan 06 中改变 V1。

同步查询仍然存在时间耦合和 check-then-act 竞态。如果业务要求严格保证状态在后续提交时仍有效，应采用有期限且带版本的授权/预留 token、显式 workflow，或者重新评估模块边界。

## 5. Integration Event

Integration Event 表达已提交的跨模块业务事实，例如 `TransactionProcessed`。它不用于请求当前状态，也不应在源事务提交前直接驱动其他模块写入。

目标可靠流程：

1. 生产者在本地事务中同时保存 Aggregate 和 Outbox 记录。
2. 本地事务提交后，Outbox Dispatcher 异步发布版本化事件。
3. 传输层采用至少一次交付语义。
4. 消费者入站 Adapter 使用 Inbox 根据 EventId 与 consumer identity 去重。
5. Adapter 将事件映射为消费者自己的 Application Command。
6. 消费者业务写入与 Inbox processed 记录在同一本地事务中提交。
7. 失败按照策略退避重试，超过限制进入 dead-letter，并提供运维可见性和重放能力。

事件 schema 由生产者拥有，采用过去式事实命名，并保持向后兼容演进。推荐 envelope 至少包含 EventId、OccurredAt、CorrelationId、CausationId、TenantId 和 schema version。

Domain Event 与 Integration Event 不应混用：Domain Event 是模块内部模型的一部分。Application 在业务状态变化时形成内部事实；Infrastructure 在同一本地事务的 Outbox 准备阶段将其映射为公开 V1 Integration Event，提交后由 Dispatcher 投递。

## 6. Event Notification 与本地投影

如果消费者读取频率高、可以接受短暂陈旧状态，并希望避免同步可用性耦合，可以订阅 Event-Carried State Transfer 并维护本地投影。

采用本地投影前必须具备：

- 覆盖状态重建所需的完整事件；
- bootstrap/snapshot/replay 方案；
- 消息顺序或版本冲突处理；
- 幂等消费；
- 缺失检测与周期对账；
- 明确允许的数据陈旧时间。

当前 CRM 事件不足以完整重建账户 KYC，因此不能直接用现有事件替换同步查询。

## 7. 通信方式选择

| 场景 | 推荐方式 | 主要代价 |
|---|---|---|
| 当前命令必须获得较新事实 | 同步 Contract + Adapter | 时间耦合、超时和竞态 |
| 源事务提交后触发下游动作 | Integration Event + Outbox/Inbox | 最终一致性、重试和运维复杂度 |
| 高频读取且允许短暂陈旧 | Event-Carried State Transfer + 本地投影 | 数据复制、重建和对账 |
| 跨模块强原子不变量 | 重新评估边界或显式 reservation/workflow | 更复杂的业务协议 |
| 模块已经独立部署 | HTTP/gRPC 或消息代理 Adapter | 网络可靠性、版本和可观测性 |

不建议使用跨模块 MediatR 请求来隐藏依赖，因为消费者仍然依赖提供方请求类型，而且边界会退化为运行时 Service Locator。也不建议同一 ApiHost 内默认使用 HTTP；接口调用已经是进程内 API。

## 8. DI 与实现加载

Contracts 不引用 Application，也不加载实现。提供方 Infrastructure Inbound Adapter 实现公开 Contract，提供方 Composition 注册 Adapter 与 Application 用例：

```text
A.Contracts interface
  ← implemented by A.Infrastructure Inbound Adapter
  → invokes A.Application UseCase
  ← registered by A.Composition
  ← loaded when ApiHost calls AddModuleA
```

直接桥接 Contract 的消费者 Adapter 引用提供方 Contracts；多个模块共用 IAM V1 调用时，消费者 Infrastructure 改为引用 provider-owned IAM Client。两种方式都由具体 Adapter 实现本模块 Application Port 并固定 consumer identity。运行时共享 DI 容器把 Contract 解析到提供方注册的 Inbound Adapter，再由后者调用 Application 用例。

如果 ApiHost 没有加载必需的提供方模块，应在容器验证或模块依赖验证阶段快速失败，而不是在首次业务请求中产生模糊错误。

## 9. 微服务迁移

目标结构不要求共享 Application 或 Domain 包。拆分服务时：

- 消费者 Application Port 保持不变；
- 进程内 Adapter 替换为 HTTP/gRPC Adapter；
- 提供方 Presentation 暴露网络 API 并调用相同 Application 用例；
- Integration Event schema 成为版本化 wire contract；
- 两个服务分别拥有 DI 容器、数据库和部署生命周期。

可以共享极小的版本化 Contract 包，也可以通过 OpenAPI/Proto 生成客户端。无论选择哪一种，都必须允许向后兼容和独立部署，不能共享 Domain/Application 实现程序集。

## 10. 后续计划建议顺序

本文不是实施计划，但建议后续计划按以下依赖顺序组织：

1. 确认术语、Contracts 所有权与 LayerGuard 规则。
2. 盘点真实消费者，删除或内化未使用的 Reader 方法和 DTO。
3. 修复所有公开 Contract 的 tenant、授权和错误语义。
4. 在提供方 Application 建立自有用例，停止由 Reader 直接承载业务判断；公开入口由 Infrastructure Inbound Adapter 承接。
5. 在 Transaction 等消费者 Application 定义 consumer-owned ports。
6. 在 Infrastructure/Integrations 建立进程内 Adapter，并从消费者 Application 移除外部模块引用。
7. 将外部事件 Handler 移到入站 Integration Adapter，转换为内部 Command。
8. 设计并实现 Outbox、Inbox、幂等、重试、dead-letter、追踪与重放。
9. 对需要本地投影的场景单独设计完整事件和重建机制。
10. 增加架构测试、契约兼容测试和跨模块故障测试。

每一步都应保持系统可构建、可测试，并避免把契约重构与消息可靠性改造一次性合并成不可验证的大变更。

## 11. 需要避免的常见误区

- Contracts 是定义，不是运行时服务，也不负责寻找实现。
- ApiHost 负责汇总 DI，不负责实现模块业务。
- Composition 是装配点，不是每次请求的业务执行步骤。
- Integration Adapter 属于外层，不是新的业务层。
- 进程内调用也是 API，不需要为了模块独立性强制引入 HTTP。
- 同步读取不等于跨模块原子一致性。
- Event 不等于可靠消息；可靠性来自 Outbox、Inbox、幂等、重试和运维机制。

