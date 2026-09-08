# IFX module communication architecture review

# IFX 模块通信架构评审

This directory records the source-verified architecture and its governed migration. Plan 01 synchronous Contracts/Ports/Adapters reached B2; Plan 02 events and later closure milestones remain open.

本目录记录经源码核对的架构及受治理的迁移状态。Plan 01 同步 Contracts/Ports/Adapters 已到达 B2；Plan 02 事件与后续关闭里程碑仍保持开放。

## Baseline / 基线

- Repository source baseline: commit `308d548`
- Architecture style: ASP.NET Core 8 modular monolith
- Deployment: one ApiHost process
- Current persistence: one DbContext, migrations set, and SQL schema per business module
- Target status: synchronous boundary implemented at B2; reliable events remain proposed for B3

- 仓库源码基线：提交 `308d548`
- 架构风格：ASP.NET Core 8 模块化单体
- 部署方式：单一 ApiHost 进程
- 当前持久化：每个业务模块拥有独立 DbContext、迁移集合和 SQL schema
- 目标方案状态：同步边界已在 B2 实施；可靠事件仍待 B3

## Full documents / 完整说明文档

| Scope | 中文 | English |
|---|---|---|
| Current architecture / 当前架构 | [current-architecture.zh-CN.md](current-architecture.zh-CN.md) | [current-architecture.en.md](current-architecture.en.md) |
| Target Contracts/Adapters/Events architecture / 目标架构 | [target-contracts-adapters-events.zh-CN.md](target-contracts-adapters-events.zh-CN.md) | [target-contracts-adapters-events.en.md](target-contracts-adapters-events.en.md) |
| Plan 01 B2 implementation / Plan 01 B2 实施基线 | [Plan 01 中文](plan01-contracts-adapters-boundary.zh-CN.md) | [Plan 01 English](plan01-contracts-adapters-boundary.en.md) |
| G01 transaction boundary / 事务边界 | [G01 中文](gates/G01/transaction-boundary.zh-CN.md) | [G01 English](gates/G01/transaction-boundary.en.md) |
| G02 database boundary / 数据库边界 | [G02 中文](gates/G02/database-boundary.zh-CN.md) | [G02 English](gates/G02/database-boundary.en.md) |
| G03 Contract/Event governance / Contract/Event 治理 | [G03 中文](gates/G03/contract-event-governance.zh-CN.md) | [G03 English](gates/G03/contract-event-governance.en.md) |
| G04 deployment/runtime boundary / 部署与运行边界 | [G04 中文](gates/G04/deployment-runtime-boundary.zh-CN.md) | [G04 English](gates/G04/deployment-runtime-boundary.en.md) |
| G05 context/sensitive-data boundary / 上下文与敏感数据边界 | [G05 中文](gates/G05/context-sensitive-data-boundary.zh-CN.md) | [G05 English](gates/G05/context-sensitive-data-boundary.en.md) |

## Implementation plans / 实施计划

- [Plan overview and review conclusions / 计划概述与审查结论](plans/README.md)
- [Master plan / 总计划](plans/00-master-plan.md)
- [Prerequisite gates / 前置 Gate](plans/00-prerequisites.md)
- [Deferred work / 后续 TODO](plans/TODO.md)

## Diagrams / 图表

| No. | Diagram |
|---|---|
| 01 | [Current architecture / 当前架构图](diagrams/01-current-architecture.md) |
| 02 | [Current communication flows / 当前通信流程图](diagrams/02-current-communication-flows.md) |
| 03 | [Target Contracts, Adapters, and Events architecture / 目标架构图](diagrams/03-target-contracts-adapters-events-architecture.md) |
| 04 | [Target synchronous Contract flow / 目标同步 Contract 流程图](diagrams/04-target-synchronous-contract-flow.md) |
| 05 | [Target durable Integration Event flow / 目标可靠事件流程图](diagrams/05-target-integration-event-flow.md) |
| 06 | [Target DI composition flow / 目标 DI 装配流程图](diagrams/06-target-di-composition-flow.md) |
| 07 | [G02 database architecture / 数据库架构图](gates/G02/diagrams/database-architecture.svg) |
| 08 | [G02 history bootstrap state / History Bootstrap 状态机](gates/G02/diagrams/history-bootstrap.svg) |
| 09 | [G02 production migration flow / 生产迁移流程](gates/G02/diagrams/production-migration-flow.svg) |
| 10 | [G02 failure recovery / 失败恢复状态图](gates/G02/diagrams/failure-recovery.svg) |
| 11 | [G02 Expand/Contract sequence / Expand/Contract 时序图](gates/G02/diagrams/expand-contract.svg) |
| 12 | [G03 provider/consumer overview / Provider/Consumer 总体图](gates/G03/diagrams/provider-consumer.svg) |
| 13 | [G03 lifecycle and legacy migration / 生命周期与 legacy 迁移](gates/G03/diagrams/lifecycle-migration.svg) |
| 14 | [G03 compatibility decision / 兼容判定](gates/G03/diagrams/compatibility-decision.svg) |
| 15 | [G03 V1/V2 migration / V1/V2 迁移时序](gates/G03/diagrams/v1-v2-migration.svg) |
| B2 | [Plan 01 implemented contract boundary / Plan 01 已实施同步边界](diagrams/plan01-contract-boundary.svg) |
| 16 | [G03 change approval / 变更审批](gates/G03/diagrams/change-approval.svg) |
| 17 | [G04 deployment boundary / 部署边界](gates/G04/diagrams/deployment-boundary.svg) |
| 18 | [G04 runtime topology / 运行拓扑](gates/G04/diagrams/runtime-topology.svg) |
| 19 | [G04 startup, health, drain / 启动、健康与排空](gates/G04/diagrams/startup-health-drain.svg) |
| 20 | [G04 dispatcher and backpressure / Dispatcher 与背压](gates/G04/diagrams/dispatcher-backpressure.svg) |
| 21 | [G04 consumer-first release / Consumer-first 发布](gates/G04/diagrams/consumer-first-release.svg) |
| 22 | [G04 failure and rollback / 失败与回退](gates/G04/diagrams/failure-rollback.svg) |
| 23 | [G05 current context boundary / 当前上下文边界](gates/G05/diagrams/current-context-boundary.svg) |
| 24 | [G05 target context boundary / 目标上下文边界](gates/G05/diagrams/target-context-boundary.svg) |
| 25 | [G05 HTTP and Contract flow / HTTP 与 Contract 流程](gates/G05/diagrams/http-contract-flow.svg) |
| 26 | [G05 Event context flow / Event 上下文流程](gates/G05/diagrams/event-context-flow.svg) |
| 27 | [G05 tenant trust decision / Tenant 信任判定](gates/G05/diagrams/tenant-trust-decision.svg) |
| 28 | [G05 failure and replay state / 失败与重放状态](gates/G05/diagrams/failure-replay-state.svg) |

## Recommended reading order / 建议阅读顺序

1. Read the current architecture document and diagrams to establish what the code does today.
2. Read the target architecture document and architecture diagram to understand responsibilities and dependency directions.
3. Read the plan overview and master plan, then use the synchronous flow, event flow, and DI flow during implementation.

1. 先阅读当前架构文档和现状图，确认今天的代码实际如何运行。
2. 再阅读目标架构文档和目标架构图，理解职责与依赖方向。
3. 阅读计划概述和总计划，实施时以同步流程、事件流程和 DI 流程为依据。

## Diagram conventions / 图例约定

- A solid arrow normally means a compile-time project/type dependency.
- A dashed arrow means implementation, binding, or another explicitly labelled relationship.
- Sequence diagrams show runtime calls and transaction timing.
- Contracts are definitions and have no runtime behavior of their own.

- 实线通常表示编译期项目或类型依赖。
- 虚线表示实现、绑定或图中明确标注的其他关系。
- 时序图表示运行时调用和事务时点。
- Contracts 只是定义，本身没有运行时行为。

