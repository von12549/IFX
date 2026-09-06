# Plan 00 前置：事务、数据库与运行边界准入条件

> 状态：Draft / 待评审
> 后续计划：[`00-master-plan.md`](00-master-plan.md)
> 来源：从 [`TODO.md`](TODO.md) 提取的强依赖或必须提前冻结的事项
> 准入规则：本文件全部 Gate 完成前，可以继续调研和原型验证，但不进入 Plan 00 的正式架构迁移实施。

## 前置范围说明

本前置计划只解决会影响 Contracts、Adapters、Events 和 LayerGuard 实施方向的最小边界问题，不要求提前完成数据库拆分、完整 Saga、Microservice 提取或全部运维建设。

其中 TX4/TX5 的“前置完成”是指先确定事务语义、原子单元和验收方式，消除架构歧义；Outbox/Inbox 功能本身仍在 [`02-reliable-integration-events.md`](02-reliable-integration-events.md) 中实现，避免形成循环依赖。

## 前置 Gate 概览

| Gate | 性质 | 阻塞范围 |
| --- | --- | --- |
| [Gate 1：事务边界](00-G01-transaction-boundary.md) | 硬依赖 | Outbox/Inbox 原子性、事件最终验收 |
| [Gate 2：数据库边界](00-G02-database-boundary.md) | 硬依赖 | Outbox/Inbox 表归属、migration 与关系数据库测试 |
| [Gate 3：Contract/Event 治理](00-G03-contract-event-governance.md) | 设计前置 | Contracts surface、event ownership 与版本策略 |
| [Gate 4：部署运行假设](00-G04-deployment-runtime-boundary.md) | 上线前置 | Dispatcher 多实例、部署顺序和 readiness |
| Gate 5：关联与敏感数据 | schema 前置 | Event envelope、诊断能力和数据治理 |

## Gate 1 — 事务边界最小集

- [ ] **Gate 1 完成**：TX1–TX5 的决策、测试要求和责任边界均已批准；需要先修复的现存事务缺陷已完成。

实施计划：[`00-G01-transaction-boundary.md`](00-G01-transaction-boundary.md)。架构决策已经确认；只有计划中的实现、测试和文档交付全部完成后才能勾选本 Gate。

- [ ] TX1 形成事务边界 ADR：事务只在单模块 DbContext 内保证 ACID；跨模块流程使用消息、补偿或 Saga，不声明共享原子性。
- [ ] TX2 修复并验证 `TransactionBehavior` 提交语义：正常返回的 `Result.Failure` 不得被误认为成功并提交。
- [ ] TX3 统一异常、业务失败、取消与 transient failure 的 commit/rollback 规则，并用关系数据库测试覆盖。
- [ ] TX4 冻结“业务数据与 Outbox 必须位于同一本地事务、提交前不得直接发布 Integration Event”的规则；实际迁移由 Event 子计划 E2 执行。
- [ ] TX5 冻结“消费方业务数据与 Inbox 完成记录必须位于同一本地事务”的规则及失败语义；实际实现由 Event 子计划 E4 执行。
- [ ] TX-G1 保存批准的 ADR、事务状态表和成功/失败/取消测试结果，作为 Plan 00 的输入证据。

## Gate 2 — 数据库边界最小集

- [ ] **Gate 2 完成**：Outbox/Inbox 的模块 ownership、schema、migration 和验证路径已确定且可执行。

实施计划：[`00-G02-database-boundary.md`](00-G02-database-boundary.md)。架构决策已经确认；只有 history 切换、独立 Migrator、关系数据库测试和文档交付全部完成后才能勾选本 Gate。

- [ ] DB1 形成数据库边界 ADR：近期保持同一 `IFXDb` 实例，但每模块独立 DbContext、schema 和 migration ownership，禁止跨模块 DbContext/表访问。
- [ ] DB2 修复 Auth migration 标识不一致，并兼容已存在的 legacy/错误 squash history 状态。
- [ ] DB3 决定并落实每模块 migrations history table 策略，例如 `auth.__EFMigrationsHistory`，避免共享 `dbo.__EFMigrationsHistory` 造成耦合或碰撞。
- [ ] DB4 为每个 DbContext 增加并测试 `HasDefaultSchema` 防护，确保模块新实体不会落入错误 schema。
- [ ] DB9 确定生产 migration 的执行主体、互斥、失败与回滚流程；若从 ApiHost 启动迁出，准备受控 deployment job。
- [ ] DB10 修正容器启动依赖：SQL Server healthy → init completed → Migrator completed → ApiHost。
- [ ] DB11 建立关系数据库 migration 测试：fresh install、逐版本 upgrade、legacy stamp、多个 DbContext 共库和重复执行。
- [ ] DB-G1 明确生产方 Outbox 与消费方 Inbox 分别归属各自模块 DbContext/schema，不创建共享 Messaging DbContext。
- [ ] DB-G2 保存 schema ownership 表、migration 测试报告和部署流程，作为 Event 子计划 E2/E4 的输入证据。

## Gate 3 — Contract / Event Ownership 治理

- [ ] **Gate 3 完成**：每项公共能力和事件都有唯一 owner、真实消费者及可执行的兼容策略。

实施计划：[`00-G03-contract-event-governance.md`](00-G03-contract-event-governance.md)。架构决策已经确认；只有目录、owner/consumer、兼容基线、自动化门禁和中英文图文交付全部完成后才能勾选本 Gate。

- [ ] GOV1 为每个模块建立业务能力、数据 ownership、同步 Contracts、发布事件和消费事件目录。
- [ ] GOV2 建立 Contract/Event owner 与变更评审机制；新增公共表面必须有真实消费者、版本策略和废弃方式。
- [ ] GOV5 为共享 primitives 建立最小 allowlist，防止 Contracts 依赖新的通用 SharedKernel 或泄漏内部模型。
- [ ] GOV-G1 对 CRM KYC、Registry subscription availability 与 `TransactionProcessed` 明确 provider、consumer、同步/异步选择和新鲜度要求。
- [ ] GOV-G2 保存并自动验证批准后的能力/事件目录，作为 Contracts 分类、Event schema 和 LayerGuard allowlist 的唯一治理输入。

## Gate 4 — 部署与运行假设

- [ ] **Gate 4 完成**：单体部署假设、Dispatcher 多实例行为、migration 顺序和健康信号已冻结。

实施计划：[`00-G04-deployment-runtime-boundary.md`](00-G04-deployment-runtime-boundary.md)。架构决策已经确认；只有 Deployment Unit/Module/Release Manifest、Runtime Role、多实例 lease、探针、部署演练和中英文图文交付全部完成后才能勾选本 Gate。

- [ ] DP1 形成部署边界 ADR：五个业务模块共同构成一个 ApiHost 业务发布边界；Frontend、数据库、OPA、Migrator 和独立基础设施可有自己的部署生命周期，编译期/数据边界或多容器不代表业务微服务化。
- [ ] DP3 明确模块和后台服务的启动顺序、依赖失败、部分不可用、优雅关闭及多实例 Dispatcher 的并发领取策略。
- [ ] DP4 定义 database migration/seed、ApiHost 实例和 Dispatcher 的部署编排顺序，禁止未完成 schema 升级的实例开始分发消息。
- [ ] DP5 定义模块与消息通道的 health/readiness 信号，包括 dispatcher 状态、Outbox backlog age 和必要依赖可用性。
- [ ] DP-G1 保存当前/目标 Deployment Unit Catalog、单实例/多实例运行图、API/Worker roles、部署顺序和失败矩阵，作为 Dispatcher 设计与生产上线依据。

## Gate 5 — 关联信息与敏感数据规则

- [ ] **Gate 5 完成**：公共同步调用和事件 schema 所需的追踪、租户及敏感数据规则已冻结。

- [ ] OPS1 统一 CorrelationId、CausationId、TenantId 和 trace 在同步 Contract、Outbox、transport 与 Inbox 间的传播规则。
- [ ] OPS3 建立 Contract/Event/日志敏感字段分级与脱敏规则，禁止凭据和非必要个人数据进入公共 payload。
- [ ] OPS-G1 将已批准字段规则映射到 Event Envelope 与 Contract request context，并建立最小 schema 测试。

## 最终准入验收

- [ ] PRE-D01 Gate 1–5 全部完成，且所有输出均有链接、负责人和批准记录。
- [ ] PRE-D02 没有通过共享 DbContext、共享事务或共享内部模型来规避边界问题。
- [ ] PRE-D03 Event 子计划中 TX4/TX5 对应的实现仍由 E2/E4 跟踪，没有因前置决策被错误标记为已实现。
- [ ] PRE-D04 Plan 00 的架构假设、计划顺序和 LayerGuard 目标矩阵已根据前置决策更新。
- [ ] PRE-D05 构建、事务测试和 migration 测试基线已保存，可以开始 Plan 00 Phase 0。
- [ ] PRE-D06 每个 Gate 的架构与规则设计均已形成设计解释、架构图、流程图和必要状态图，并完成技术审查。
