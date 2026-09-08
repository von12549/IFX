# 子计划 1：Abstractions 向 Contracts / Ports / Adapters 演进

> G04 反向链接：API/Worker 继续使用同一业务 release，Contract 迁移不得形成按模块独立部署；见 [G04 runtime baseline](../gates/G04/deployment-runtime-boundary.zh-CN.md)。

> 状态：B2 COMPLETE（2026-09-08）；Plan 02/B3、B4 与 Gate Final Closure 不在本计划关闭范围
> 上级计划：[`00-master-plan.md`](00-master-plan.md)
> 相关架构：[`../target-contracts-adapters-events.zh-CN.md`](../target-contracts-adapters-events.zh-CN.md)
> 治理前置：[`00-G03-contract-event-governance.md`](00-G03-contract-event-governance.md) 提供权威目录、V1 identity、版本/废弃政策和 shared primitives allowlist。
> G03 交接入口：[治理说明](../gates/G03/contract-event-governance.zh-CN.md)、[catalog](../gates/G03/contract-event-catalog.yaml) 与 [public API snapshot](../gates/G03/snapshots/G03-sync-api-snapshot.json)；完成真实 source/Adapter/behavior tests 后回交 Active 准入证据。
> 可执行交接包：[`G03 -> Plan 01 handoff`](../gates/G03/handoffs/plan01-contracts-handoff.md)，含 owner、26 项 Reader/method/DTO 处置、回访条件和回交清单。
> 上下文与数据前置：[`00-G05-context-sensitive-data-boundary.md`](00-G05-context-sensitive-data-boundary.md) 提供 ContractRequestContext、ExecutionScope、tenant/consumer 验证、C0-C4 分类与 conformance suite。
> 门禁前置：[`03-layerguard-alignment.md`](03-layerguard-alignment.md) 03-A0/03-A1 已完成，Gate policy 已绑定，正式 B1 已保存且完整迁移门禁在 CI 禁止新增违规。
> 完成证据：[`B2 status`](../evidence/plan01/B2-status.json)、[`Gate handback`](../evidence/plan01/B2-gate-handback.md)、[中英文实施设计](../plan01-contracts-adapters-boundary.zh-CN.md) 与 [`B2 LayerGuard`](../evidence/layerguard/B2-report.json)。四个事件 `*.Abstractions` 项目只因 Plan 02/B3 保留，不是同步兼容 shim。

## 目标边界

```text
Provider.Application ----implements----> Provider.Contracts
        ^                                      ^
        |                                      |
Provider.Infrastructure                 Consumer.IntegrationAdapter
                                               |
                                        implements
                                               v
                                      Consumer.Application.Port

ApiHost --> Provider.Composition / Consumer.Composition（只负责装配）
```

Contracts 是模块对其他模块承诺的最小公共表面，不是 Application 的替代品，也不是“内部 Presentation”。Application 持有用例、编排、业务授权和 Port；Contracts 只持有跨模块稳定协议。Integration Adapter 属于外层并负责把外部 Contract 翻译为本模块 Application Port。

## 职责判定表

| 内容 | Contracts | Application | Integration Adapter | Composition |
| --- | --- | --- | --- | --- |
| 公共同步能力接口、请求/响应 DTO | 允许 | 实现/使用自身模型 | 调用并转换 | 注册 |
| 业务用例、校验、授权、编排 | 禁止 | 拥有 | 禁止复制 | 禁止 |
| 消费方 Port | 禁止放在提供方 | 消费方拥有 | 实现 | 注册 |
| DbContext、Repository、EF 查询 | 禁止 | 只依赖 Port/Repository 抽象 | 可经提供方 Contract，不直查外部 DB | 禁止 |
| HTTP/gRPC/进程内调用细节 | 禁止 | 禁止 | 拥有 | 选择实现 |
| DI 扩展与实例创建 | 禁止 | 禁止 | 可提供内部注册辅助 | 模块拥有 |

## Phase 0 — 现状盘点与迁移决策

- [x] **Phase 0 完成**：本 Phase 下全部项目均已完成并附有证据。

- [x] C0.1 从 Gate 03 权威目录导入全部 `*.Abstractions` 项目、公开类型、方法、DTO、事件、提供方、实际消费方及运行路径，并与当前源码对账。
- [x] C0.2 执行 Gate 03 已批准的分类，将每个公开类型迁移为“同步 Contract”“Integration Event”“模块内部 Application 类型”或“应删除的未使用表面”；分类变化须先更新目录并评审。
- [x] C0.3 核实当前生产同步调用基线：`ICrmReader.IsInvestmentAccountKycApprovedAsync` 与 `IRegistryReader.IsClassOpenForSubscriptionAsync`。
- [x] C0.4 核实 `IHoldingsReader`、`ITransactionReader` 是否确无生产跨模块消费者；若有隐藏消费者，补入清单并明确迁移策略。
- [x] C0.5 为每个 Contract 明确 capability-oriented 名称，避免继续扩展通用 `Reader` 成为跨模块 Repository。
- [x] C0.6 决定项目/namespace 重命名策略、兼容窗口和删除日期，并记录对应 ADR。
- [x] C0.7 决定错误语义、取消、超时和不可用的表达方式，禁止向 Contract 泄漏 EF、MediatR 或内部异常类型。
- [x] C0.8 为所有按租户访问的 Contract 明确 TenantId 来源与授权检查位置，不允许仅靠调用方约定过滤。
- [x] C0.9 从 Gate 05 字段目录导入每个公开字段的分类、purpose、approved consumers 和 log/retention policy；未分类字段不得迁移为 Active Contract。

## Phase 1 — 建立最小 Contracts 项目

- [x] **Phase 1 完成**：本 Phase 下全部项目均已完成并附有证据。

- [x] C1.1 为真实被消费的能力建立 `*.Contracts` 项目或兼容命名空间；默认只依赖 BCL，同步 metadata 和 Event schema 分别只能依赖 Gate 03/05 批准的 `Context.Contracts` 与 `Messaging.Contracts` 原语。
- [x] C1.2 将同步能力按业务能力组织，例如 CRM compliance 与 Registry subscription availability，而不是按数据库实体暴露 CRUD Reader。
- [x] C1.3 为请求/响应创建专用 Contract DTO；只包含调用者必须知道的字段，不公开 Domain Entity、Value Object 或持久化模型。
- [x] C1.4 将 Integration Event schema 放入提供方 Contracts 的独立目录/namespace，并与同步接口明确分区。
- [x] C1.5 落实 Gate 03 的 V1 identity、Compatible/Conditional/Breaking 分类、并行 V+1、unknown fallback 与默认废弃窗口。
- [x] C1.6 验证 Contracts 不包含业务实现、Handler、DbContext、Repository、DI、日志、HTTP client 或 broker SDK 引用。
- [x] C1.7 在迁移期为旧 `Abstractions` 建立最小兼容 shim（仅在确有必要时），并给每个 shim 标注删除条件。
- [x] C1.8 使用 Gate 05 BCL-only ContractRequestContext；业务 request/response 与调用 metadata 分离，不携带 ClaimsPrincipal、JWT/token、角色全集或 transport 类型。
- [x] C1.9 对 Contract schema 执行字段分类、Secret denylist、序列化 golden 和 context conformance tests。

## Phase 2 — 将提供方实现归位到 Application

- [x] **Phase 2 完成**：本 Phase 下全部项目均已完成并附有证据。

- [x] C2.1 在 CRM.Application 实现 CRM 拥有的 compliance Contract，把用例规则与授权留在 Application/Domain。
- [x] C2.2 将当前由 CRM.Infrastructure Reader 直接通过 DbContext 暴露的跨模块能力改为 Application Facade；Infrastructure 仅实现 Application 所需的持久化 Port。
- [x] C2.3 在 Registry.Application 实现 Registry 拥有的 subscription availability Contract，并保持 Domain 规则由 Registry 自己解释。
- [x] C2.4 将当前由 Registry.Infrastructure Reader 直接查询 DbContext 的实现迁移为“Application Facade → 本模块 Repository Port → Infrastructure”。
- [x] C2.5 审查所有 Contract 方法的租户隔离、授权、取消令牌和 not-found/denied/unavailable 语义。
- [x] C2.6 在各自 Module Composition 中注册 Contract 实现及其本地依赖；ApiHost 只调用模块注册入口。
- [x] C2.7 添加提供方 Application 单元测试，覆盖允许、拒绝、缺失、跨租户和底层不可用场景。
- [x] C2.8 Provider Inbound Adapter 在 Application 前验证 consumer、context version、Tenant/Platform scope 和资源 tenant 一致性；ActorReference 不作为独立授权证明。

## Phase 3 — 在消费方建立 Ports 与 Integration Adapters

- [x] **Phase 3 完成**：本 Phase 下全部项目均已完成并附有证据。

- [x] C3.1 在 Transaction.Application 为 KYC 判定定义消费方拥有的 Port，其输入输出只使用 Transaction 自身类型。
- [x] C3.2 在 Transaction.Infrastructure/Integrations 实现 CRM Adapter，使其引用 CRM.Contracts 并完成错误与 DTO 转换。
- [x] C3.3 在 Transaction.Application 为 Class subscription 判定定义消费方拥有的 Port。
- [x] C3.4 在 Transaction.Infrastructure/Integrations 实现 Registry Adapter，使其引用 Registry.Contracts 并完成转换。
- [x] C3.5 在 Transaction Composition 中将两个 Adapter 注册到各自 Application Port，验证运行时解析唯一且生命周期正确。
- [x] C3.6 删除 Transaction.Application 对 CRM/Registry Contracts（以及旧 Abstractions）的直接项目引用和 using。
- [x] C3.7 用项目引用图和 LayerGuard 迁移规则验证：消费方 Application 不认识提供方 Contract，外层 Adapter 是唯一桥接点。
- [x] C3.8 添加 Adapter 契约测试，覆盖提供方成功、业务拒绝、超时、取消、不可用和协议映射失败。
- [x] C3.9 Consumer Adapter 从可信 ExecutionContext 创建新 RequestId、继承 CorrelationId、设置 CausationId，并禁止调用方业务代码任意伪造 Source/Actor/Tenant。
- [x] C3.10 运行 Gate 05 Contract conformance suite，覆盖 missing/invalid context、未登记 consumer、tenant mismatch、嵌套调用和并行 scope 隔离。

## Phase 4 — 收窄公共表面并分离内部模型

- [x] **Phase 4 完成**：本 Phase 下全部项目均已完成并附有证据。

- [x] C4.1 将 Holdings.Application 对公共 Holdings DTO 的内部复用替换为 Application 自己的命令/查询模型。
- [x] C4.2 对 `IHoldingsReader` 执行“删除、内部化或收窄”为明确能力接口的决定，并更新注册与测试。
- [x] C4.3 对 `ITransactionReader` 执行“删除、内部化或收窄”为明确能力接口的决定，并更新注册与测试。
- [x] C4.4 逐一修复公共 `GetById` 类能力缺失 TenantId/授权上下文的问题；无法安全补齐的接口不得继续公开。
- [x] C4.5 检查公共 DTO 是否暴露内部状态机、数据库主键策略或导航结构，并用稳定语义替代。
- [x] C4.6 删除没有真实消费者的 DI 注册、Reader 实现、DTO 映射和测试夹具。
- [x] C4.7 对最终公共 API surface 生成快照并与 Gate 03 catalog/Change Record 关联，作为正式 V1 兼容性检查基线。
- [x] C4.8 按 Gate 05 capability-purpose 原则移除 `InvestorSummaryDto` 等过宽模型中的非必要姓名、KYC、税务或账户字段；C3 例外必须链接批准记录。

## Phase 5 — 解决 Composition 与启动路径

- [x] **Phase 5 完成**：本 Phase 下全部项目均已完成并附有证据。

- [x] C5.1 确认每个模块 Composition 引用本模块 Application、Infrastructure 和 Contracts，但不承载业务实现。
- [x] C5.2 确认 ApiHost 不直接注册具体业务 Service/Repository/Adapter，只按依赖顺序调用模块 Composition。
- [x] C5.3 为模块装配建立启动测试：缺失实现、重复实现、错误生命周期和循环依赖应快速失败。
- [x] C5.4 明确进程内 Adapter 的替换点，证明未来 HTTP/gRPC Adapter 可在不修改消费方 Application 的情况下接入。
- [x] C5.5 记录模块启动依赖仅代表部署组合关系，不等价于允许任意项目引用或共享数据库访问。
- [x] C5.6 Root Composition 注册唯一 execution-context runtime；模块 Composition 只注册 Adapter/Provider，不从 Auth.Infrastructure 或 HttpContext 获取隐式全局上下文。

## Phase 6 — 验证与迁移收尾

- [x] **Phase 6 完成**：本 Phase 下全部项目均已完成并附有证据。

- [x] C6.1 运行完整 build 与相关模块测试，确认没有因项目/namespace 重命名产生遗漏。
- [x] C6.2 运行编译期依赖检查，确认 Domain 不引用 Contracts，Application 不引用其他模块 Contracts。
- [x] C6.3 运行关键业务功能测试，确认 KYC 与 Class 状态判定的业务结果和租户隔离无回归。
- [x] C6.4 移除过期兼容 shim、旧 `Abstractions` 项目引用和空项目；若暂不能移除，登记有到期日的豁免。
- [x] C6.5 更新架构图、模块模板、命名规范和“新增跨模块同步调用”的评审清单。
- [x] C6.6 保存最终项目引用图、公共 surface 快照、测试报告和 LayerGuard 报告作为完成证据。
- [x] C6.7 将实际迁移结果、Active/Deprecated/Retired 状态、Adapter 位置和遗留清零证据回写 Gate 03 权威目录。
- [x] C6.8 更新 Gate 05 字段目录、Contract schema 快照、context/error reason codes 和敏感数据例外状态。
- [x] C6.9 汇总最终 Contract context、tenant、字段分类、Adapter 和验证结果，作为 Phase 7 文档输入。

## Phase 7 — 架构与规则文档化

- [x] **Phase 7 完成**：本 Phase 下全部项目均已完成并附有证据。

- [x] C7.1 编写完整中文设计说明，解释 Contracts、Application Ports、Adapters、Composition 与 Presentation 的职责和边界。
- [x] C7.2 编写与中文内容一致的英文设计说明，并建立双向链接。
- [x] C7.3 保存改造前后编译期依赖架构图，标明提供方 ownership、消费方 Port、Adapter 和 Root Composition。
- [x] C7.4 保存同步 Contract 正常、拒绝、异常、context 传播及错误映射流程图。
- [x] C7.5 保存 DI 装配和进程内 Adapter 被 HTTP/gRPC Adapter 替换的流程图。
- [x] C7.6 保存现状到目标的项目/类型映射、公共 surface 变化和职责判定表。
- [x] C7.7 保存 Mermaid 源文件及可审阅的 SVG/PNG 渲染结果，并执行链接和视觉检查。
- [x] C7.8 将每项规则映射到测试、LayerGuard rule、Gate 证据或有到期日的 waiver，并更新架构索引。

## 完成标准（Definition of Done）

- [x] C-D01 `Contracts` 仅包含最小公共协议，不包含业务或基础设施实现。
- [x] C-D02 提供方 Application 实现自身能力，Composition 注册实现，ApiHost 只装配模块。
- [x] C-D03 消费方 Application 只依赖自己的 Port；外部 Contract 仅出现在外层 Adapter。
- [x] C-D04 当前全部真实跨模块同步调用均完成迁移，并通过功能与隔离测试。
- [x] C-D05 未使用 Reader 已删除或内部化，内部 Application DTO 不再复用公共 DTO。
- [x] C-D06 未来进程外 Adapter 的替换边界已通过测试或最小 spike 验证。
- [x] C-D07 所有同步调用使用已验证 ContractRequestContext，Correlation/Causation/Tenant scope 在嵌套和异常场景语义一致。
- [x] C-D08 所有 Active Contract 字段有 C0-C4 分类和 purpose，C4 零暴露，C3 只有批准例外。
- [x] C-D09 中英文说明、架构图、流程图、映射表和规则证据完整且与实现一致。
## G05 反向链接

同步 Contract 必须消费 G05 的最小 `ContractRequestContext`、可信 ExecutionContext、tenant/consumer validation、C0-C4 准入与安全错误规则；回交条件见 [G05 双语设计](../gates/G05/context-sensitive-data-boundary.zh-CN.md) 和 [Plan 01 handoff](../gates/G05/handoffs/plan01-contract-context-handoff.md)。
