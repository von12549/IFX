# Plan 00 前置：事务、数据库与运行边界准入条件

> 状态：PRE-READY、03-A1 LG-POLICY-READY 与 Plan 01/B2 已完成；Plan 02/B3 及 Gate 最终关闭保持开放（2026-09-08）
> 后续计划：[`00-master-plan.md`](00-master-plan.md)
> 来源：从 [`TODO.md`](TODO.md) 提取的强依赖或必须提前冻结的事项
> 准入规则：先完成 LayerGuard 03-A0 Core Bootstrap，再实施本文件 Gate 01–05；全部 Gate 达到“前置放行”后执行 03-A1 Policy Binding，随后才进入 Contracts/Events 正式迁移；Gate 的“最终关闭”在真实下游实现验收后完成。

## 前置范围说明

本前置计划只解决会影响 Contracts、Adapters、Events 和 LayerGuard 实施方向的最小边界问题，不要求提前完成数据库拆分、完整 Saga、Microservice 提取或全部运维建设。

其中 TX4/TX5 的“前置完成”是指先确定事务语义、原子单元和验收方式，消除架构歧义；Outbox/Inbox 功能本身仍在 [`02-reliable-integration-events.md`](02-reliable-integration-events.md) 中实现，避免形成循环依赖。

## 里程碑语义

- [x] **LG-BOOTSTRAP**：Gate 01 实施前完成 LayerGuard 03-A0，保存 B0/B0.5 并对不依赖 Gate artifact 的确定性规则阻断新增违规。证据：[`../evidence/03-a0-layerguard-bootstrap.md`](../evidence/03-a0-layerguard-bootstrap.md)。
- [x] **PRE-READY 前置放行**：在 03-A0 保护下完成 Gate 1–5 的批准决策、阻塞修复、ownership、协议接缝和可执行验收要求。证据：[`../evidence/plan00-prerequisite-release.md`](../evidence/plan00-prerequisite-release.md)。
- [x] **LG-POLICY-READY**：PRE-READY 后完成 03-A1，将 Gate 输出绑定到完整目标规则，保存正式 B1 并启用完整“禁止新增违规”门禁。证据：[`../evidence/03-a1-layerguard-policy-binding.md`](../evidence/03-a1-layerguard-policy-binding.md)。
- [ ] **Gate 最终关闭**：对应原子子计划完成真实代码迁移并回交证据后，才勾选各 Gate Plan 的全部 Phase 与 Definition of Done。

同一实现只有一个 owner：例如 Event 子计划 E2/E4 实现真实 Outbox/Inbox，Gate 01 只定义和验证事务接缝；Event E3 实现真实 Dispatcher，Gate 04 只定义 Runtime Role、lease、health 和运行 conformance。

## 前置 Gate 概览

| Gate | 性质 | 阻塞范围 |
| --- | --- | --- |
| [Gate 1：事务边界](00-G01-transaction-boundary.md) | 硬依赖 | Outbox/Inbox 原子性、事件最终验收 |
| [Gate 2：数据库边界](00-G02-database-boundary.md) | 硬依赖 | Outbox/Inbox 表归属、migration 与关系数据库测试 |
| [Gate 3：Contract/Event 治理](00-G03-contract-event-governance.md) | 设计前置 | Contracts surface、event ownership 与版本策略 |
| [Gate 4：部署运行假设](00-G04-deployment-runtime-boundary.md) | 上线前置 | Dispatcher 多实例、部署顺序和 readiness |
| [Gate 5：关联与敏感数据](00-G05-context-sensitive-data-boundary.md) | schema 前置 | Event envelope、Contract context、诊断能力和数据治理 |

## Gate 1 — 事务边界最小集

- [x] **Gate 1 前置放行**：TX1–TX5 的决策、测试要求和责任边界均已批准；TX2/TX3 阻塞缺陷与可独立完成的事务基础已修复，TX4/TX5 的真实 Outbox/Inbox 代码仍由 E2/E4 实施。

实施与最终验收：[`00-G01-transaction-boundary.md`](00-G01-transaction-boundary.md)。架构决策已经确认；前置放行不等于 Gate 最终关闭。

- [x] TX1 形成事务边界 ADR：事务只在单模块 DbContext 内保证 ACID；跨模块流程使用消息、补偿或 Saga，不声明共享原子性。
- [x] TX2 修复并验证 `TransactionBehavior` 提交语义：正常返回的 `Result.Failure` 不得被误认为成功并提交。
- [x] TX3 统一异常、业务失败、取消与 transient failure 的 commit/rollback 规则，并用关系数据库测试覆盖。
- [x] TX4 冻结“业务数据与 Outbox 必须位于同一本地事务、提交前不得直接发布 Integration Event”的规则；实际迁移由 Event 子计划 E2 执行。
- [x] TX5 冻结“消费方业务数据与 Inbox 完成记录必须位于同一本地事务”的规则及失败语义；实际实现由 Event 子计划 E4 执行。
- [x] TX-G1 保存批准的 ADR、事务状态表和成功/失败/取消测试结果，作为 Plan 00 的输入证据。

## Gate 2 — 数据库边界最小集

- [x] **Gate 2 前置放行**：模块 DbContext/schema/history、Migrator 和未来 Outbox/Inbox ownership 已确定且可执行；真实消息表 migration 由 E2/E4 创建并回交测试证据。

实施与最终验收：[`00-G02-database-boundary.md`](00-G02-database-boundary.md)。架构决策已经确认；前置放行不要求提前创建尚未设计的消息表。

- [x] DB1 形成数据库边界 ADR：近期保持同一 `IFXDb` 实例，但每模块独立 DbContext、schema 和 migration ownership，禁止跨模块 DbContext/表访问。
- [x] DB2 修复 Auth migration 标识不一致，并兼容已存在的 legacy/错误 squash history 状态。
- [x] DB3 决定并落实每模块 migrations history table 策略，例如 `auth.__EFMigrationsHistory`，避免共享 `dbo.__EFMigrationsHistory` 造成耦合或碰撞。
- [x] DB4 为每个 DbContext 增加并测试 `HasDefaultSchema` 防护，确保模块新实体不会落入错误 schema。
- [x] DB9 确定生产 migration 的执行主体、互斥、失败与回滚流程；若从 ApiHost 启动迁出，准备受控 deployment job。
- [x] DB10 修正容器启动依赖：SQL Server healthy → init completed → Migrator completed → ApiHost。
- [x] DB11 建立关系数据库 migration 测试：fresh install、逐版本 upgrade、legacy stamp、多个 DbContext 共库和重复执行。
- [x] DB-G1 明确生产方 Outbox 与消费方 Inbox 分别归属各自模块 DbContext/schema，不创建共享 Messaging DbContext。
- [x] DB-G2 保存 schema ownership 表、migration 测试报告和部署流程，作为 Event 子计划 E2/E4 的输入证据。

Gate 2 前置证据：[`../gates/G02/ADR-G02-001-module-database-ownership.md`](../gates/G02/ADR-G02-001-module-database-ownership.md)、
[`../gates/G02/database-boundary.zh-CN.md`](../gates/G02/database-boundary.zh-CN.md) 和
[`../evidence/gates/G02/G02-closeout.md`](../evidence/gates/G02/G02-closeout.md)。前置放行已完成；
Gate 最终关闭仍等待 Plan 02 E2/E4、G04 生产编排回交和最终三方签字。

## Gate 3 — Contract / Event Ownership 治理

- [x] **Gate 3 前置放行**：现有和目标公共能力/事件均已盘点，Active candidate 有唯一 owner、真实消费者及可执行兼容策略，迁移项有期限。

实施与最终验收：[`00-G03-contract-event-governance.md`](00-G03-contract-event-governance.md)。目录和准入规则先放行，真实 V1 schema/consumer 迁移后再最终关闭。
G03 图文治理基线见[中文](../gates/G03/contract-event-governance.zh-CN.md)与
[English](../gates/G03/contract-event-governance.en.md)；治理输入已获前置放行，Active promotion 与 Gate 最终关闭仍等待下游证据。

- [x] GOV1 为每个模块建立业务能力、数据 ownership、同步 Contracts、发布事件和消费事件目录。
- [x] GOV2 建立 Contract/Event owner 与变更评审机制；新增公共表面必须有真实消费者、版本策略和废弃方式。
- [x] GOV5 为共享 primitives 建立最小 allowlist，防止 Contracts 依赖新的通用 SharedKernel 或泄漏内部模型。
- [x] GOV-G1 对 CRM KYC、Registry subscription availability 与 `TransactionProcessed` 明确 provider、consumer、同步/异步选择和新鲜度要求。
- [x] GOV-G2 保存并自动验证批准后的能力/事件目录，作为 Contracts 分类、Event schema 和 LayerGuard allowlist 的唯一治理输入。

## Gate 4 — 部署与运行假设

- [x] **Gate 4 前置放行**：单体部署假设、API/Worker Runtime Role、Dispatcher lease protocol、migration 顺序和 health/backpressure contract 已冻结并可做 conformance 验证。

实施与最终验收：[`00-G04-deployment-runtime-boundary.md`](00-G04-deployment-runtime-boundary.md)。Runtime 基础先放行；真实 Dispatcher 和 backlog 信号由 E3/E6 实现后回交最终证据。
中英文实现基线见[中文](../gates/G04/deployment-runtime-boundary.zh-CN.md)与
[English](../gates/G04/deployment-runtime-boundary.en.md)。当前审计状态为 PRE-READY；下方未勾选项保留到对应真实信号与生产演练交回。

- [x] DP1 形成部署边界 ADR：五个业务模块共同构成一个 ApiHost 业务发布边界；Frontend、数据库、OPA、Migrator 和独立基础设施可有自己的部署生命周期，编译期/数据边界或多容器不代表业务微服务化。
- [x] DP3 明确模块和后台服务的启动顺序、依赖失败、部分不可用、优雅关闭及多实例 Dispatcher 的并发领取策略。
- [x] DP4 定义 database migration/seed、ApiHost 实例和 Dispatcher 的部署编排顺序，禁止未完成 schema 升级的实例开始分发消息。
- [x] DP5 定义模块与消息通道的 health/readiness 信号，包括 dispatcher 状态、Outbox backlog age 和必要依赖可用性。
- [x] DP-G1 保存当前/目标 Deployment Unit Catalog、单实例/多实例运行图、API/Worker roles、部署顺序和失败矩阵，作为 Dispatcher 设计与生产上线依据。

G04 仓库内可实现基线已完成，因此 Gate 4 获得前置放行；[`PRE-READY closeout`](../evidence/gates/G04/G04-phase12-handoff.md)
中的 E3/E4/E6、G05 runtime hand-back、L5.1/L5.2、生产演练与五方批准只约束 Gate 最终关闭，不反向阻塞 03-A1。

## Gate 5 — 关联信息与敏感数据规则

- [x] **Gate 5 前置放行**：公共同步调用和事件 schema 所需的追踪、租户、失败及敏感数据规则已冻结，最小 primitives/catalog extension/conformance 要求可供子计划使用。

实施与最终验收：[`00-G05-context-sensitive-data-boundary.md`](00-G05-context-sensitive-data-boundary.md)。三组架构决策已经确认；真实 Contract/Event carrier 由子计划实施并回交证据。
G05 双语设计与可渲染流程基线见[中文](../gates/G05/context-sensitive-data-boundary.zh-CN.md)与
[English](../gates/G05/context-sensitive-data-boundary.en.md)；当前为 PRE-READY，不提前代表真实载体或生产批准。

- [x] OPS1 统一 CorrelationId、OperationId、CausationId、EventId、显式 Tenant/Platform scope 和 W3C trace 在 HTTP、同步 Contract、Outbox、transport 与 Inbox 间的传播及失败规则。
- [x] OPS3 建立 C0-C4 Contract/Event/日志/trace/审计字段分级、目的限制与双层脱敏规则，禁止凭据和非必要个人数据进入公共 payload。
- [x] OPS-G1 将已批准规则映射到 BCL-only ContractRequestContext、Event Envelope、可信 ExecutionContext 和字段目录，并建立 schema/security/conformance tests。
- [x] OPS-G2 对 invalid/missing context、tenant mismatch、producer/schema failure、retry/replay、parallel scope 和 Compatibility Adapter 建立失败矩阵与测试。
- [x] OPS-G3 保存中英文设计说明、上下文/信任边界架构图、HTTP/Contract/Event 流程图、数据准入矩阵和规则到门禁映射。

## PRE-READY 前置放行验收

- [x] PRE-D01 LayerGuard 03-A0 已在 Gate 01 前完成，B0/B0.5、工具版本、bootstrap 规则和执行结果可追踪。
- [x] PRE-D02 没有通过共享 DbContext、共享事务或共享内部模型来规避边界问题。
- [x] PRE-D03 Event 子计划中 TX4/TX5 对应的实现仍由 E2/E4 跟踪，没有因前置决策被错误标记为已实现。
- [x] PRE-D04 Plan 00 的架构假设、计划顺序和 LayerGuard 目标矩阵已根据前置决策更新。
- [x] PRE-D05 Gate 1–5 均达到前置放行，且输出有链接、负责人、批准记录和明确的下游实现 owner。
- [x] PRE-D06 每个 Gate 的架构与规则设计均已形成设计解释、架构图、流程图和必要状态图，并完成技术审查。
- [x] PRE-D07 构建、事务、migration 与 B0.5 测试基线已保存；尚未完成的 Gate 最终验收项均有唯一回交路径。

## LG-POLICY-READY 验收

- [x] LG-D01 03-A1 已直接绑定 Gate 03 catalog/allowlist、Gate 04 Runtime Role 和 Gate 05 context policy，并生成正式 B1。
- [x] LG-D02 完整目标规则已进入 CI；历史 baseline 可受控暂存，但新增违规、未知项目、扫描异常和过期 waiver 必须失败。
- [x] LG-D03 LG-D01/LG-D02 已完成，Plan 01/02 的真实 Contracts/Events 迁移现可开始。
