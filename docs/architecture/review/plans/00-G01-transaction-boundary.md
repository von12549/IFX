# Plan 00 / Gate 01：事务边界实施计划

> 状态：Architecture Decisions Approved / 待实施
> 上级前置计划：[`00-prerequisites.md`](00-prerequisites.md)
> 上级总计划：[`00-master-plan.md`](00-master-plan.md)
> 范围：TX1–TX5，以及其所需的命令、结果、异常、并发和事务执行规则
> Gate 关闭条件：本计划全部 Phase、Definition of Done 和文档交付均已完成

## 目标

为每个模块建立一致、可验证的本地事务模型：一个写 Command 只能修改一个模块的数据；TransactionBehavior 是唯一事务政策所有者；Handler 不执行最终持久化；只有成功结果可以提交；业务数据与 Outbox、消费方业务数据与 Inbox 分别在所属模块的同一本地事务中原子保存。

本计划只确定 Outbox/Inbox 与事务的连接点，不实现 Dispatcher、transport、dead letter、replay 或完整 Event schema。这些内容仍由 [`02-reliable-integration-events.md`](02-reliable-integration-events.md) 负责。

## 非目标

- [ ] G01-N01 不引入跨模块 `TransactionScope`、分布式事务或多个 DbContext 的共享 ACID。
- [ ] G01-N02 不在本 Gate 实现 Saga、业务补偿或完整 TOCTOU 解决方案；相关事项继续由 `TX6–TX9` 跟踪。
- [ ] G01-N03 不在本 Gate 拆分独立数据库或决定消息 broker。
- [ ] G01-N04 不通过共享 Messaging DbContext 存储所有模块的 Outbox/Inbox。

## 当前实现基线

| 事实 | 当前证据 | 风险 |
| --- | --- | --- |
| 五个模块各自复制 TransactionBehavior | 各 Behavior 均按 `*Command` 名称开启事务并在正常返回时提交 | 规则漂移；无法识别 `Result.Failure` |
| Handler 自行保存 | 89 个 Command Handler 中有 88 个调用 `SaveChangesAsync` | 持久化责任分散；难以保证统一 Outbox 原子写入 |
| Handler 吞掉异常 | 89 个 Command Handler 均存在通用 `catch (Exception)` | Behavior 通常看不到异常并可能提交失败流程 |
| 事件在提交前发布 | Transaction Handler 在 SaveChanges 后调用 `PublishAsync`，外层 Behavior 随后才 commit | 消费方可能先于生产方提交 |
| InMemory bus 吞掉消费异常 | 总线捕获 Handler 异常后只记录日志 | 生产方无法感知失败，也没有可靠重试依据 |
| 事件消费者直接保存 | Holdings Integration Event Handler 直接调用自己的 UnitOfWork | 没有 Inbox 去重和统一消费事务 |

关键代码基线：

- [ ] G01-B01 保存并引用 Transaction、CRM、Registry、Holdings、Auth 的 TransactionBehavior 快照。
- [ ] G01-B02 保存并引用 `ProcessTransactionCommandHandler` 的 Save → Publish → Result 流程快照。
- [ ] G01-B03 保存并引用 `InMemoryIntegrationEventBus` 的同步调用与吞错行为快照。
- [ ] G01-B04 生成 Command Handler 的 SaveChanges、catch-all 和 PublishAsync 使用清单，作为迁移燃尽表。

## 已确认架构决策

- [x] G01-D01 一个事务只属于一个模块、一个模块 DbContext 和一个本地数据库事务。
- [x] G01-D02 TransactionBehavior 统一拥有事务政策和最终 SaveChanges；Handler 不提交事务，也不执行最终 SaveChanges。
- [x] G01-D03 `Result.Success` 才可持久化并 commit；`Result.Failure` 必须 rollback 或丢弃未持久化变更。
- [x] G01-D04 使用显式 `ICommand<TResponse>` marker，不再依赖类型名以 `Command` 结尾。
- [x] G01-D05 Handler 只转换明确的业务异常；unexpected/infrastructure exception 必须传播到事务边界。
- [x] G01-D06 `OperationCanceledException` 保持取消语义，使用独立的 cleanup token rollback 后继续传播。
- [x] G01-D07 默认使用 Deferred Write：Handler 成功后才开启短写事务。
- [x] G01-D08 Inbox Command 在去重检查前开启本地事务，业务变化与 Inbox completion 原子保存。
- [x] G01-D09 强一致读写只能使用显式、受限的特殊 Profile，事务内禁止外部模块或网络调用。
- [x] G01-D10 数据库 transient retry 包裹完整的持久化事务，但不得重跑包含外部副作用的 Handler。
- [x] G01-D11 禁止 Command Handler 通过 MediatR 嵌套发送另一个 Command。
- [x] G01-D12 本地并发默认通过 optimistic concurrency、数据库唯一约束和业务幂等键控制。
- [x] G01-D13 Outbox/Inbox 分别进入所属模块 DbContext，不建立共享消息事务。
- [x] G01-D14 Inbound Integration Adapter 只做协议映射，不拥有消费事务。
- [x] G01-D15 禁止使用 `TransactionScope` 建立跨模块 ambient/distributed transaction。

## 目标流程

### 默认 API Command：Deferred Write

```text
Logging -> Validation -> TransactionBehavior
                            |
                            v
                         Handler
                  read / ports / domain changes
                            |
                  +---------+----------+
                  |                    |
             Result.Failure       Result.Success
                  |                    |
          discard tracked state        v
                  |              execution strategy
                  |                    |
                  |              Begin local tx
                  |                    |
                  |              attach Outbox
                  |                    |
                  |              SaveChanges once
                  |                    |
                  |                 Commit
                  +--------------------+
                            |
                         response
```

### Integration Event Consumer：Inbox Transaction

```text
Transport -> Inbound Adapter -> Inbox Command(EventId)
                                      |
                                Begin local tx
                                      |
                                Inbox lookup
                               /            \
                         duplicate          new
                            |                |
                          no-op       Application Handler
                            |                |
                            |        add Inbox completion
                            |                |
                            +------ SaveChanges once
                                      |
                                    Commit
                                      |
                                     Ack
```

### 失败状态

```text
Business failure       -> Result.Failure -> rollback/discard -> expected response
Domain exception       -> mapped failure -> rollback         -> expected response
Unexpected exception   -> propagate      -> rollback         -> central error mapping
Cancellation           -> propagate      -> cleanup rollback -> cancelled response
Ambiguous commit result-> system error   -> idempotent retry/reconciliation
```

## 目标职责

| 组件 | 应负责 | 不应负责 |
| --- | --- | --- |
| Command Handler | 用例编排、Domain 调用、修改 tracked entity、登记待发布事实、返回 Result | Begin/Commit/Rollback、最终 SaveChanges、直接发布 Integration Event |
| TransactionBehavior | 选择 transaction profile、检查 Result、组织持久化、commit/rollback | 业务规则、外部协议映射 |
| UnitOfWork Port | 表达本模块持久化单元与最终保存能力 | 暴露 EF transaction 类型、跨模块 Repository |
| Transaction Executor | execution strategy、isolation、begin/commit/rollback、cleanup | 理解业务 Result 和 Event payload |
| Inbound Adapter | 外部 Event → 本模块 Inbox Command 映射 | 开启 DbContext 事务、直接更新业务实体 |
| Presentation | 将稳定业务/系统错误映射为 HTTP response | 决定事务提交或回滚 |

## Phase 0 — 建立安全基线与迁移清单

- [ ] **Phase 0 完成**：现状清单、测试基线、迁移顺序和临时保护规则均已准备。

- [ ] G01-0.1 枚举五个模块全部 TransactionBehavior、IUnitOfWork、UnitOfWork 实现和注册位置。
- [ ] G01-0.2 生成全部 Command 的 Result 类型、SaveChanges、catch-all、PublishAsync、raw SQL 与嵌套 Send 使用清单。
- [ ] G01-0.3 标记包含多次 SaveChanges、数据库生成 ID、立即执行写入或外部副作用的特殊 Handler。
- [ ] G01-0.4 建立当前成功、业务失败、异常和取消行为的 characterization tests，防止迁移时误判变化。
- [ ] G01-0.5 确定模块迁移顺序；建议先 Transaction，再 Holdings、Registry、CRM，最后 Auth。
- [ ] G01-0.6 决定 UnitOfWork 与 Transaction Executor 的最终接口拆分，并用 ADR 记录选择及依赖方向。
- [ ] G01-0.7 定义迁移期规则：已迁移 Handler 禁止 SaveChanges/catch-all/direct Publish，未迁移 Handler 进入显式 baseline。

## Phase 1 — 统一 Command、Result 与错误语义

- [ ] **Phase 1 完成**：事务参与者可由类型系统识别，所有结果与异常都有确定提交语义。

- [ ] G01-1.1 定义 `ICommand<TResponse>`，并让写请求显式实现该 marker。
- [ ] G01-1.2 定义最小 `IResult`/`IOperationResult`，至少稳定暴露 `IsSuccess` 与结构化错误类别。
- [ ] G01-1.3 统一各模块 `Result<T>` 与事务 Behavior 的交互方式，避免反射或模块类型分支。
- [ ] G01-1.4 定义 Validation、business rejection、not found、conflict、forbidden、unexpected failure 和 cancellation 的分类表。
- [ ] G01-1.5 引入明确的 Domain/Application 异常类型；禁止把任意 `InvalidOperationException` 自动视为业务失败。
- [ ] G01-1.6 建立统一异常映射边界，使 unexpected exception 经过 rollback 后由宿主转换为稳定 API 错误。
- [ ] G01-1.7 为 `OperationCanceledException` 建立“不记录为普通错误、不转换为 Result.Failure”的测试。
- [ ] G01-1.8 添加静态规则，禁止通过类名后缀决定事务参与资格。

## Phase 2 — 建立事务执行基础设施

- [ ] **Phase 2 完成**：事务、retry、cleanup 和 isolation 由单一基础设施实现提供。

- [ ] G01-2.1 在 Application 定义窄 Transaction Execution Port，不暴露 `IDbContextTransaction` 或 EF Core 类型。
- [ ] G01-2.2 在各模块 Infrastructure 实现本地事务执行器，且只能操作本模块 DbContext。
- [ ] G01-2.3 让 execution strategy 包裹 Begin → SaveChanges → Commit 的完整持久化单元。
- [ ] G01-2.4 使用独立且有界的 cleanup token 执行 rollback/dispose，避免请求取消阻止清理。
- [ ] G01-2.5 rollback 失败只能作为附加诊断信息，不能覆盖最初异常或取消原因。
- [ ] G01-2.6 明确 commit 结果不确定的错误类型、日志字段和上层响应，不错误声称已 rollback。
- [ ] G01-2.7 默认 isolation 使用 `ReadCommitted`；任何更强 isolation 必须通过显式 Profile。
- [ ] G01-2.8 为重复 Begin、重复 Commit、重复 Rollback、Dispose 和并发使用建立 fail-fast 行为与测试。

## Phase 3 — 实现统一 TransactionBehavior 与事务 Profile

- [ ] **Phase 3 完成**：默认、Inbox 和特殊强一致 Profile 均有唯一且可测试的执行算法。

- [ ] G01-3.1 实现默认 Deferred Write：先执行 Handler，Failure 不保存，Success 才进入持久化事务。
- [ ] G01-3.2 在默认 Profile 中统一登记 Outbox pending records 并执行一次 SaveChanges，再 commit。
- [ ] G01-3.3 实现 Inbox Profile：Begin → 去重 → Handler → Inbox completion → Save once → Commit。
- [ ] G01-3.4 实现显式 Consistent Read/Write Profile，并限制其只能执行本模块数据库操作。
- [ ] G01-3.5 禁止 TransactionBehavior 使用 request 名称、namespace 字符串或 Attribute 猜测事务类型。
- [ ] G01-3.6 定义 pipeline 顺序并测试：Logging → Validation → transaction policy；无效请求不得开启事务。
- [ ] G01-3.7 对 Failure、异常、取消、Save 失败、Commit 失败和 cleanup 失败逐一验证状态转换。
- [ ] G01-3.8 评估将五份复制 Behavior 收敛为共享机制；只共享通用政策，不共享模块 DbContext 或 Repository。

## Phase 4 — 迁移 Command Handler

- [ ] **Phase 4 完成**：所有写 Handler 遵循统一持久化和异常政策，无未登记的旧路径。

- [ ] G01-4.1 按模块迁移 Command 类型到显式 `ICommand<TResponse>`。
- [ ] G01-4.2 从普通 Handler 移除最终 `SaveChangesAsync`，由 Behavior 统一保存。
- [ ] G01-4.3 从 Handler 移除通用 `catch (Exception)`；仅保留有明确业务语义的转换。
- [ ] G01-4.4 确保 `OperationCanceledException` 和 unexpected exception 可以穿透 Handler。
- [ ] G01-4.5 移除 Handler 中直接 `PublishAsync`；临时过渡路径必须有到期日并且不会提交前通知消费者。
- [ ] G01-4.6 修复或重构立即写入、raw SQL、多次 SaveChanges 和数据库生成 ID 的特殊 Handler。
- [ ] G01-4.7 禁止 Command Handler 嵌套发送 Command；共享逻辑提取为 Domain/Application Service。
- [ ] G01-4.8 每迁移一个模块即运行该模块全部行为与功能测试，并更新迁移燃尽表。

## Phase 5 — 并发、唯一约束与幂等

- [ ] **Phase 5 完成**：本地竞争和 commit 不确定性不会产生静默覆盖或重复业务结果。

- [ ] G01-5.1 识别高竞争 Aggregate，并为 Transaction、Order、Holding、Fund/FundClass 等确定 concurrency token 策略。
- [ ] G01-5.2 在 Infrastructure 将数据库 concurrency failure 转换为稳定、非 EF 泄漏的 conflict exception。
- [ ] G01-5.3 将 conflict 映射为明确的应用/API 结果，例如 HTTP 409，并定义客户端重试条件。
- [ ] G01-5.4 为 tenant-scoped business key 建立数据库复合唯一约束，Application 预检查只负责友好提示。
- [ ] G01-5.5 为可由客户端或基础设施重试的写 Command 定义 idempotency key、保存位置和保留期。
- [ ] G01-5.6 为 Event Consumer 强制使用 EventId 作为 Inbox 幂等键和数据库唯一约束。
- [ ] G01-5.7 添加并发写、重复请求、重复事件和 commit 结果不确定的测试。

## Phase 6 — 固定 Outbox / Inbox 事务接缝

- [ ] **Phase 6 完成**：Event 子计划获得稳定、无循环依赖的本地事务接入点。

- [ ] G01-6.1 定义 Application 可使用的事件登记 Port；它只能登记事实，不能直接调用 transport。
- [ ] G01-6.2 证明业务实体与 Outbox pending record 由同一个模块 DbContext、同一次 SaveChanges 保存。
- [ ] G01-6.3 定义 Inbound Adapter 到 Inbox Command 的 metadata 传递，包括 EventId、TenantId、CorrelationId 和 CausationId。
- [ ] G01-6.4 证明 Inbox 去重、消费方业务变化与 Inbox completion 位于同一个模块本地事务。
- [ ] G01-6.5 明确 commit 后 transport ack 的责任边界；事务层不实现 transport retry。
- [ ] G01-6.6 添加保护规则，禁止共享 Outbox/Inbox DbContext 和跨模块 transaction enlistment。
- [ ] G01-6.7 将 Dispatcher、dead letter、replay、schema version 等非事务事项交接到 Event 子计划，并建立双向链接。

## Phase 7 — 关系数据库测试与渐进发布

- [ ] **Phase 7 完成**：所有关键事务状态、故障窗口和迁移兼容性均有自动化证据。

- [ ] G01-7.1 为 TransactionBehavior 建立 success/failure/exception/cancellation 状态矩阵测试。
- [ ] G01-7.2 使用真实关系数据库验证 rollback、commit、savepoint、unique constraint 和 optimistic concurrency。
- [ ] G01-7.3 验证 retry 不会重新执行 Handler 或重复外部副作用。
- [ ] G01-7.4 验证生产方业务数据与 Outbox 同生同灭，消费方业务数据与 Inbox 同生同灭。
- [ ] G01-7.5 执行并发 Inbox、重复 EventId、进程中止和 commit response 丢失的故障注入测试。
- [ ] G01-7.6 采用逐模块切换；每次切换前后保存 build、test 和运行指标基线。
- [ ] G01-7.7 删除全部迁移期 waiver、旧 TransactionBehavior 和 Handler 自行持久化路径。
- [ ] G01-7.8 运行完整 solution build、tests 与 LayerGuard，确认没有跨模块事务依赖。

## Phase 8 — 架构与规则文档化

- [ ] **Phase 8 完成**：最终实现、架构规则、图示和运行说明均已形成可维护的中英文文档基线。

- [ ] G01-8.1 创建中文设计文档 `docs/architecture/review/gates/G01/transaction-boundary.zh-CN.md`。
- [ ] G01-8.2 创建对应英文文档 `docs/architecture/review/gates/G01/transaction-boundary.en.md`，内容和决策编号与中文版本一致。
- [ ] G01-8.3 文档解释事务 ownership、三个 Profile、Result/exception/cancellation 语义、并发与幂等策略。
- [ ] G01-8.4 创建目标架构图，展示 Application、TransactionBehavior、UnitOfWork、Transaction Executor、DbContext 与 Outbox/Inbox 的依赖关系。
- [ ] G01-8.5 创建默认 Deferred Write Command 流程图，覆盖 Success 与 Failure 分支。
- [ ] G01-8.6 创建 Inbox Consumer 原子事务流程图，覆盖 duplicate、success、failure 与 ack 时点。
- [ ] G01-8.7 创建事务失败状态图，覆盖异常、取消、retry、ambiguous commit 和 cleanup failure。
- [ ] G01-8.8 将图表源文件以 Mermaid 保存，并生成可在仓库直接查看的 SVG/PNG 渲染文件。
- [ ] G01-8.9 在文档中加入当前架构与目标架构对照、常见错误、禁止模式和代码示例。
- [ ] G01-8.10 将所有架构规则映射到测试、LayerGuard 规则或人工审查项，避免只有文字没有执行机制。
- [ ] G01-8.11 更新总架构索引和相关计划链接，确保设计文档可发现且不会成为孤立文件。
- [ ] G01-8.12 完成文档技术审查、图表渲染检查和中英文一致性检查。

## Phase 9 — Gate 关闭与 Plan 00 交接

- [ ] **Phase 9 完成**：Gate 01 已由负责人批准关闭，并满足 Plan 00 准入要求。

- [ ] G01-9.1 对照 TX1–TX5 逐项附上 ADR、代码、测试和文档证据。
- [ ] G01-9.2 在 [`00-prerequisites.md`](00-prerequisites.md) 勾选 Gate 1 及 TX1–TX5，仅在实施和文档全部完成后操作。
- [ ] G01-9.3 确认 Event 子计划 E2/E4 使用本 Gate 定义的事务接缝，没有复制另一套事务政策。
- [ ] G01-9.4 将未阻塞 Plan 00 的 TOCTOU、Saga、补偿和高级事务需求保留在 TODO，并明确后续 owner。
- [ ] G01-9.5 记录最终偏差、临时 waiver、到期日和删除条件；无 owner 的 waiver 不允许关闭 Gate。
- [ ] G01-9.6 由架构负责人、Application 负责人和 Infrastructure 负责人共同确认 Gate 关闭。

## Definition of Done

- [ ] G01-DD01 所有写请求通过显式 Command marker 进入正确事务 Profile。
- [ ] G01-DD02 Handler 不负责最终 SaveChanges、事务控制或 Integration Event transport 发布。
- [ ] G01-DD03 Failure、异常、取消和 commit 不确定性均有明确、经过测试的处理语义。
- [ ] G01-DD04 默认事务只覆盖本地持久化阶段，特殊强一致事务显式且不包含外部调用。
- [ ] G01-DD05 Outbox/Inbox 分别与所属模块业务数据原子保存，不存在共享或跨模块事务。
- [ ] G01-DD06 optimistic concurrency、唯一约束和幂等策略覆盖已识别的高风险写入。
- [ ] G01-DD07 关系数据库、故障注入、完整 build/test 和架构检查全部通过。
- [ ] G01-DD08 中英文设计说明、架构图、流程图、状态图和规则到自动化检查的映射均已完成并审核。

## 回退原则

- [ ] G01-R01 按模块迁移并保持单一权威事务路径，不允许新旧 Behavior 对同一 Command 同时生效。
- [ ] G01-R02 回退只能恢复到已验证的模块级旧路径，不能恢复提交前跨模块通知而不记录风险。
- [ ] G01-R03 数据库 concurrency/idempotency schema 变化必须先验证向前/向后兼容和部署顺序。
- [ ] G01-R04 任何回退都要记录原因、影响、数据 reconciliation 方式和再次上线条件。
