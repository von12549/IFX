# 后续架构讨论 TODO

> 状态：Backlog
> 目的：记录本轮 Contracts / Adapters / Events / LayerGuard 计划之外，讨论中已经识别但尚未形成完整实施计划的事项。
> 使用方式：每一项进入实施前应补充现状证据、目标决策、独立计划、负责人和验收标准。
> 已提取前置项：TX1–TX5、DB1/DB3/DB4/DB9/DB11、GOV1/GOV2/GOV5、DP1/DP3/DP4/DP5、OPS1/OPS3 已移动至 [`00-prerequisites.md`](00-prerequisites.md)，不在本 TODO 重复维护。

## Topic 1 — 数据库边界：独立 DbContext、migration 与 schema

- [ ] **Topic 1 完成**：全部事项已转为正式计划或有证据地完成。

- [ ] DB2 修复 Auth migration 标识不一致：`EFMigrator.cs` 使用 `20260317145706_InitialCreate`，实际 migration 为 `20260327075710_InitialCreate`。
- [ ] DB5 评估生产环境每模块独立数据库 role/credential 与 schema 权限；当前共享高权限连接不构成强隔离。
- [ ] DB6 明确“不建立跨模块数据库 FK”的完整生命周期协议，尤其是 Tenant 删除/停用后其他模块数据的处理。
- [ ] DB7 设计 `TenantDeleted`/`TenantDeactivated` 等事实事件、软删除/保留策略和孤儿数据 reconciliation。
- [ ] DB8 建立 tenant-aware Repository/Contract 规范，并评估 global query filter 或数据库 RLS 的适用性与旁路风险。
- [ ] DB10 修正容器启动依赖：ApiHost 不仅等待 SQL Server health，还要等待初始化/migration job 成功。
- [ ] DB12 定义模块拆分为独立数据库时的数据复制、报表、备份恢复与迁移策略。

## Topic 2 — 事务边界：模块本地事务与跨模块一致性

- [ ] **Topic 2 完成**：全部事项已转为正式计划或有证据地完成。

- [ ] TX6 评估 KYC 与 Class 状态“先查后写”的 TOCTOU 风险，按业务需要采用 reservation、version token、有效期或最终补偿。
- [ ] TX7 为需要跨模块完成的业务流程定义状态机、超时、补偿、人工干预和审计，不引入分布式数据库事务。
- [ ] TX8 规定各模块事务 ownership、嵌套事务、重试策略和 idempotency key 的使用方式。
- [ ] TX9 添加故障注入测试，覆盖提交前/后崩溃、重复命令、补偿失败和恢复。

## Topic 3 — 部署边界：单一 ApiHost 的模块化单体

- [ ] **Topic 3 完成**：全部事项已转为正式计划或有证据地完成。

- [ ] DP2 建立模块 manifest，记录 Composition 入口、依赖模块、schema、migration、事件与健康检查。
- [ ] DP6 定义未来 Microservice 提取门槛：团队 ownership、扩缩容、发布频率、故障隔离、数据 ownership 与合规需求。
- [ ] DP7 为进程内 Contract Adapter 预留 HTTP/gRPC/消息 Adapter 替换点，但不提前引入网络复杂度。
- [ ] DP8 设计拆分时的认证、服务发现、超时、重试、熔断、可观测性与 schema/version rollout。
- [ ] DP9 评估共享库与共享 Contracts package 的发布治理，避免服务拆分后形成 lockstep deployment。

## Topic 4 — 模块边界与公共能力治理

- [ ] **Topic 4 完成**：全部事项已转为正式计划或有证据地完成。

- [ ] GOV3 为跨模块报表和查询选择专用 read model/projection，禁止通过跨 DbContext join 绕过模块边界。
- [ ] GOV4 审核模块粒度与依赖方向，识别高耦合循环是否意味着边界划分错误。
- [ ] GOV6 建立租户生命周期、数据保留、隐私删除和审计责任矩阵。

## Topic 5 — 可观测性与运行治理

- [ ] **Topic 5 完成**：全部事项已转为正式计划或有证据地完成。

- [ ] OPS2 建立模块级 SLI/SLO：同步 Contract 延迟/错误率、Outbox backlog、消费延迟、重试与 dead-letter。
- [ ] OPS4 建立架构依赖图、Contract 目录、事件目录和 waiver 的持续更新机制。
- [ ] OPS5 制定模块边界事故 runbook 和定期演练，包括消息积压、schema 不兼容、migration 失败及跨租户风险。

## Topic 6 — 下一轮评审与计划化

- [ ] **Topic 6 完成**：全部事项已转为正式计划或有证据地完成。

- [ ] NEXT1 优先开展数据库边界评审，输出“现状问题、目标状态、migration strategy、验收测试”完整计划。
- [ ] NEXT2 随后开展事务边界评审，先解决 Result/exception commit 语义和 Outbox/Inbox 原子性前置项。
- [ ] NEXT3 完成部署边界评审，明确模块化单体的运行约束与 Microservice 提取标准。
- [ ] NEXT4 将已批准事项从本 TODO 移入独立计划，并在此保留反向链接与完成日期。
