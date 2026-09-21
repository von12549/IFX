# G01 模块本地事务边界

> 状态：G01 主体与 Plan 02/B3 真实 Outbox/Inbox 仓库回交已实施；最终三方签字保持开放。
> 对应英文版：[transaction-boundary.en.md](transaction-boundary.en.md)
> 决策记录：[ADR-G01-001](ADR-G01-001-transaction-executor-split.md)

## 1. 目标与当前变化

G01 将五个模块原有的 15 个 Pipeline Behavior 收敛为宿主中唯一的 Logging → Validation → Transaction Pipeline。89 个写请求均通过 `ICommand<TResponse, TOwner>` 显式声明事务 owner；共享 `TransactionBehavior` 按 owner 只解析一个 keyed executor。Handler 不再执行最终 `SaveChangesAsync`、通用 catch-all、transport `PublishAsync` 或嵌套 Command。

| 迁移前 | 当前目标实现 |
| --- | --- |
| 以 `*Command` 名称猜测写请求 | `ICommand<TResponse, TOwner>` 类型协议 |
| 每模块重复注册三种 Behavior | ApiHost 各注册一次，顺序固定 |
| Handler 保存并在提交前发布 | Behavior 成功后保存，提交后才交给过渡 dispatcher |
| 任意正常返回均提交 | 仅 `IOperationResult.IsSuccess == true` 可提交 |
| Handler 捕获所有异常 | 仅明确业务异常可转换；其余异常穿透 |
| UnitOfWork 暴露事务控制 | EF 事务仅存在于模块 Infrastructure executor |

目标依赖关系见 [架构图源文件](diagrams/target-architecture.mmd) 与 [SVG](diagrams/target-architecture.svg)。

## 2. Ownership 与三个 Profile

- `DeferredWrite`（默认）：先运行 Handler；失败时清除跟踪状态和待发布事实；成功后由 execution strategy 包裹 Begin → participant prepare → Save once → Commit。Handler 不会因数据库 transient retry 被重复执行。
- `Inbox`：事务在去重检查和 Handler 前开启；participant 接缝用于将 completion 与业务变更纳入同一次保存。真实 `(ConsumerId, EventId)` Inbox entity、唯一约束和 adapter 由 E4 接入。
- `ConsistentReadWrite`：仅用于必须在同一本地事务内读写的少数用例。事务内禁止网络调用、其他模块调用和第二个 DbContext。

每个 `TOwner` 在对应模块 Infrastructure 只注册一个 keyed `ITransactionExecutor`。零个或多个候选均在进入 Handler 前抛出 `TransactionOwnerResolutionException`。禁止 `TransactionScope`、跨模块 enlistment 和共享消息 DbContext。

默认流程见 [Mermaid](diagrams/deferred-write.mmd) / [SVG](diagrams/deferred-write.svg)；Inbox 流程见 [Mermaid](diagrams/inbox-consumer.mmd) / [SVG](diagrams/inbox-consumer.svg)。

## 3. Result、异常与取消语义

| 输入/失败 | 事务动作 | API 语义 |
| --- | --- | --- |
| Validation failure | 不进入 Handler，不解析 executor | 结构化字段错误 400 |
| `Result.Failure` | 不保存，discard tracked state | 稳定的业务响应 |
| `ForbiddenException` | rollback/discard，异常穿透 | 403 |
| optimistic concurrency | rollback，转换为 `ConcurrencyConflictException` | 安全 409，可在重新加载后重试 |
| unexpected exception | rollback/discard，异常穿透 | 不泄漏内部细节的 500 |
| cancellation | 使用独立 5 秒 cleanup token rollback，原取消继续传播 | 不记录为普通错误 |
| commit outcome unknown | 不声称 rollback，要求按幂等身份 reconciliation | 安全 503，不可盲目重试 |

rollback cleanup 的失败只记录为附加诊断，不覆盖原异常。状态转换见 [Mermaid](diagrams/failure-states.mmd) / [SVG](diagrams/failure-states.svg)。

## 4. 并发、唯一约束与幂等

Transaction、Order、Holding、Fund/FundClass 属于高竞争 aggregate。基础设施统一把 EF optimistic concurrency failure 转换为非 EF 的 409 conflict。tenant-scoped business key 必须最终由数据库复合唯一约束保证；Application 预检查只改善提示。

可由客户端或基础设施重试的 Command 必须实现 `IIdempotentCommand<TResponse, TOwner>` 并携带稳定 key。规范身份为 `(TenantId, CommandType, IdempotencyKey)`，记录保存在 owning module 自己 schema 的 `IdempotencyRecords`，必须与业务变化同一事务保存；最短保留期为七天，若客户端最大重试/reconciliation 窗口更长则采用更长期限。commit outcome unknown 必须先按该身份查询或 reconciliation，禁止盲目重跑。Consumer 使用 `(ConsumerId, EventId)` 作为 Inbox 唯一身份，但 EventId 不能代替消费方业务幂等键。G01 reference fixture 验证这些约束；真实 Inbox schema、migration 与清理由 E4 完成。

## 5. Outbox/Inbox 接缝与临时路径

`ITransactionParticipant.PrepareAsync` 是业务数据与 pending/completion record 在同一 `SaveChanges` 中持久化的稳定接缝。`ICommittedEventBuffer` 只登记事实，不提供 transport API；当前 InMemory 实现仅在本地 commit 后分发并传播消费者错误，消除了“提交前通知”。

此 buffer 是过渡实现，owner 为 Plan 02 E2，最迟 2026-12-31 或 E2 上线时删除（以先发生者为准）。它不提供崩溃恢复，不能作为可靠 Outbox 的替代。E2 必须将模块本地 Outbox entity/migration 接入 participant；E4 必须把 metadata、Inbox 去重与 completion 接入 `Inbox` Profile，并重跑同一 conformance suite。transport ack 只能发生在消费事务提交之后。

## 6. 正确用法与禁止模式

```csharp
public sealed record CreateThingCommand(Guid TenantId)
    : ICommand<Result<ThingDto>, RegistryTransactionOwner>;

public async Task<Result<ThingDto>> Handle(CreateThingCommand command, CancellationToken ct)
{
    var thing = Thing.Create(command.TenantId);
    _unitOfWork.Things.Add(thing);
    _eventBuffer.Add(new ThingCreatedIntegrationEvent(thing.Id));
    return Result<ThingDto>.Success(Map(thing));
}
```

禁止在 Command Handler 中调用 `SaveChangesAsync`、Begin/Commit/Rollback、`PublishAsync`、MediatR `.Send`、raw SQL 或 `catch (Exception)`；禁止靠类名/namespace/Attribute 推断事务 owner；禁止共享 Outbox/Inbox DbContext。

## 7. 规则到证据映射

| 规则 | 自动化证据 |
| --- | --- |
| Command marker、无最终保存/吞错/直发/嵌套 Send | `scripts/Invoke-G01TransactionBoundaryGuard.ps1` |
| success/failure/exception/cancellation、Profiles、retry 不重跑 Handler、commit 后 dispatch | `IFX.BuildingBlocks.Application.Tests` |
| 关系数据库 commit/rollback/savepoint/concurrency、Inbox/幂等唯一约束和 commit-response-lost reconciliation | `IFX.BuildingBlocks.EntityFrameworkCore.Tests` |
| Behavior 唯一注册、顺序、五模块 executor 实际隔离调用 | `ApplicationPipelineCompositionTests`（真实 ApiHost） |
| 结构化 400、403、安全 409/500、取消不记错 | `ExceptionHandlingMiddlewareTests`、`ExceptionHandlingHttpEndToEndTests` |
| 跨层和跨模块引用 | `docs/guards/V3_ifx/commands/Invoke-IFXGuardrails.ps1 -Mode Architecture` |
| 真实 Outbox/Inbox 原子性、唯一约束、崩溃窗口 | Plan 02 E2/E4 已在 B3 回交；最终签字开放 |

迁移基线与燃尽数字在 [G01-baseline.md](../../evidence/gates/G01/G01-baseline.md)，关闭证据索引在 [G01-closeout.md](../../evidence/gates/G01/G01-closeout.md)，最新机器可读守卫报告在 [G01-guard-report.json](../../evidence/gates/G01/G01-guard-report.json)。
