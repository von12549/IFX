# IFX module communication architecture review

# IFX 模块通信架构评审

This directory records the source-verified current architecture and the proposed Contracts/Adapters/Events target architecture. It is the baseline for later planning; it does not by itself authorize or represent an implementation change.

本目录记录经源码核对的当前架构，以及讨论形成的 Contracts/Adapters/Events 目标架构。它是后续计划的基础和参考，本身不代表已经实施，也不构成代码修改授权。

## Baseline / 基线

- Repository source baseline: commit `308d548`
- Architecture style: ASP.NET Core 8 modular monolith
- Deployment: one ApiHost process
- Current persistence: one DbContext, migrations set, and SQL schema per business module
- Target status: proposed and not implemented

- 仓库源码基线：提交 `308d548`
- 架构风格：ASP.NET Core 8 模块化单体
- 部署方式：单一 ApiHost 进程
- 当前持久化：每个业务模块拥有独立 DbContext、迁移集合和 SQL schema
- 目标方案状态：讨论建议，尚未实现

## Full documents / 完整说明文档

| Scope | 中文 | English |
|---|---|---|
| Current architecture / 当前架构 | [current-architecture.zh-CN.md](current-architecture.zh-CN.md) | [current-architecture.en.md](current-architecture.en.md) |
| Target Contracts/Adapters/Events architecture / 目标架构 | [target-contracts-adapters-events.zh-CN.md](target-contracts-adapters-events.zh-CN.md) | [target-contracts-adapters-events.en.md](target-contracts-adapters-events.en.md) |

## Diagrams / 图表

| No. | Diagram |
|---|---|
| 01 | [Current architecture / 当前架构图](diagrams/01-current-architecture.md) |
| 02 | [Current communication flows / 当前通信流程图](diagrams/02-current-communication-flows.md) |
| 03 | [Target Contracts, Adapters, and Events architecture / 目标架构图](diagrams/03-target-contracts-adapters-events-architecture.md) |
| 04 | [Target synchronous Contract flow / 目标同步 Contract 流程图](diagrams/04-target-synchronous-contract-flow.md) |
| 05 | [Target durable Integration Event flow / 目标可靠事件流程图](diagrams/05-target-integration-event-flow.md) |
| 06 | [Target DI composition flow / 目标 DI 装配流程图](diagrams/06-target-di-composition-flow.md) |

## Recommended reading order / 建议阅读顺序

1. Read the current architecture document and diagrams to establish what the code does today.
2. Read the target architecture document and architecture diagram to understand responsibilities and dependency directions.
3. Use the synchronous flow, event flow, and DI flow as the basis for implementation planning.

1. 先阅读当前架构文档和现状图，确认今天的代码实际如何运行。
2. 再阅读目标架构文档和目标架构图，理解职责与依赖方向。
3. 后续制定实施计划时，以同步流程、事件流程和 DI 流程为依据。

## Diagram conventions / 图例约定

- A solid arrow normally means a compile-time project/type dependency.
- A dashed arrow means implementation, binding, or another explicitly labelled relationship.
- Sequence diagrams show runtime calls and transaction timing.
- Contracts are definitions and have no runtime behavior of their own.

- 实线通常表示编译期项目或类型依赖。
- 虚线表示实现、绑定或图中明确标注的其他关系。
- 时序图表示运行时调用和事务时点。
- Contracts 只是定义，本身没有运行时行为。

