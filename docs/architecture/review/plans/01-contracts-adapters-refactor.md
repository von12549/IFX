# 子计划 1：Abstractions 向 Contracts / Ports / Adapters 演进

> 状态：Draft / 待评审
> 上级计划：[`00-master-plan.md`](00-master-plan.md)
> 相关架构：[`../target-contracts-adapters-events.zh-CN.md`](../target-contracts-adapters-events.zh-CN.md)

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

- [ ] **Phase 0 完成**：本 Phase 下全部项目均已完成并附有证据。

- [ ] C0.1 枚举所有 `*.Abstractions` 项目、公开类型、方法、DTO、事件和项目引用，标记提供方、实际消费方及运行路径。
- [ ] C0.2 将每个公开类型分类为“同步 Contract”“Integration Event”“模块内部 Application 类型”“应删除的未使用表面”。
- [ ] C0.3 核实当前生产同步调用基线：`ICrmReader.IsInvestmentAccountKycApprovedAsync` 与 `IRegistryReader.IsClassOpenForSubscriptionAsync`。
- [ ] C0.4 核实 `IHoldingsReader`、`ITransactionReader` 是否确无生产跨模块消费者；若有隐藏消费者，补入清单并明确迁移策略。
- [ ] C0.5 为每个 Contract 明确 capability-oriented 名称，避免继续扩展通用 `Reader` 成为跨模块 Repository。
- [ ] C0.6 决定项目/namespace 重命名策略、兼容窗口和删除日期，并记录对应 ADR。
- [ ] C0.7 决定错误语义、取消、超时和不可用的表达方式，禁止向 Contract 泄漏 EF、MediatR 或内部异常类型。
- [ ] C0.8 为所有按租户访问的 Contract 明确 TenantId 来源与授权检查位置，不允许仅靠调用方约定过滤。

## Phase 1 — 建立最小 Contracts 项目

- [ ] **Phase 1 完成**：本 Phase 下全部项目均已完成并附有证据。

- [ ] C1.1 为真实被消费的能力建立 `*.Contracts` 项目或兼容命名空间，并保持项目只依赖 BCL/经批准的共享契约原语。
- [ ] C1.2 将同步能力按业务能力组织，例如 CRM compliance 与 Registry subscription availability，而不是按数据库实体暴露 CRUD Reader。
- [ ] C1.3 为请求/响应创建专用 Contract DTO；只包含调用者必须知道的字段，不公开 Domain Entity、Value Object 或持久化模型。
- [ ] C1.4 将 Integration Event schema 放入提供方 Contracts 的独立目录/namespace，并与同步接口明确分区。
- [ ] C1.5 为 Contract 建立版本与兼容策略，包括新增字段、枚举演进、废弃期和破坏性版本的命名规则。
- [ ] C1.6 验证 Contracts 不包含业务实现、Handler、DbContext、Repository、DI、日志、HTTP client 或 broker SDK 引用。
- [ ] C1.7 在迁移期为旧 `Abstractions` 建立最小兼容 shim（仅在确有必要时），并给每个 shim 标注删除条件。

## Phase 2 — 将提供方实现归位到 Application

- [ ] **Phase 2 完成**：本 Phase 下全部项目均已完成并附有证据。

- [ ] C2.1 在 CRM.Application 实现 CRM 拥有的 compliance Contract，把用例规则与授权留在 Application/Domain。
- [ ] C2.2 将当前由 CRM.Infrastructure Reader 直接通过 DbContext 暴露的跨模块能力改为 Application Facade；Infrastructure 仅实现 Application 所需的持久化 Port。
- [ ] C2.3 在 Registry.Application 实现 Registry 拥有的 subscription availability Contract，并保持 Domain 规则由 Registry 自己解释。
- [ ] C2.4 将当前由 Registry.Infrastructure Reader 直接查询 DbContext 的实现迁移为“Application Facade → 本模块 Repository Port → Infrastructure”。
- [ ] C2.5 审查所有 Contract 方法的租户隔离、授权、取消令牌和 not-found/denied/unavailable 语义。
- [ ] C2.6 在各自 Module Composition 中注册 Contract 实现及其本地依赖；ApiHost 只调用模块注册入口。
- [ ] C2.7 添加提供方 Application 单元测试，覆盖允许、拒绝、缺失、跨租户和底层不可用场景。

## Phase 3 — 在消费方建立 Ports 与 Integration Adapters

- [ ] **Phase 3 完成**：本 Phase 下全部项目均已完成并附有证据。

- [ ] C3.1 在 Transaction.Application 为 KYC 判定定义消费方拥有的 Port，其输入输出只使用 Transaction 自身类型。
- [ ] C3.2 在 Transaction.Infrastructure/Integrations 实现 CRM Adapter，使其引用 CRM.Contracts 并完成错误与 DTO 转换。
- [ ] C3.3 在 Transaction.Application 为 Class subscription 判定定义消费方拥有的 Port。
- [ ] C3.4 在 Transaction.Infrastructure/Integrations 实现 Registry Adapter，使其引用 Registry.Contracts 并完成转换。
- [ ] C3.5 在 Transaction Composition 中将两个 Adapter 注册到各自 Application Port，验证运行时解析唯一且生命周期正确。
- [ ] C3.6 删除 Transaction.Application 对 CRM/Registry Contracts（以及旧 Abstractions）的直接项目引用和 using。
- [ ] C3.7 用项目引用图和 LayerGuard 迁移规则验证：消费方 Application 不认识提供方 Contract，外层 Adapter 是唯一桥接点。
- [ ] C3.8 添加 Adapter 契约测试，覆盖提供方成功、业务拒绝、超时、取消、不可用和协议映射失败。

## Phase 4 — 收窄公共表面并分离内部模型

- [ ] **Phase 4 完成**：本 Phase 下全部项目均已完成并附有证据。

- [ ] C4.1 将 Holdings.Application 对公共 Holdings DTO 的内部复用替换为 Application 自己的命令/查询模型。
- [ ] C4.2 对 `IHoldingsReader` 执行“删除、内部化或收窄”为明确能力接口的决定，并更新注册与测试。
- [ ] C4.3 对 `ITransactionReader` 执行“删除、内部化或收窄”为明确能力接口的决定，并更新注册与测试。
- [ ] C4.4 逐一修复公共 `GetById` 类能力缺失 TenantId/授权上下文的问题；无法安全补齐的接口不得继续公开。
- [ ] C4.5 检查公共 DTO 是否暴露内部状态机、数据库主键策略或导航结构，并用稳定语义替代。
- [ ] C4.6 删除没有真实消费者的 DI 注册、Reader 实现、DTO 映射和测试夹具。
- [ ] C4.7 对最终公共 API surface 生成快照，作为后续兼容性检查基线。

## Phase 5 — 解决 Composition 与启动路径

- [ ] **Phase 5 完成**：本 Phase 下全部项目均已完成并附有证据。

- [ ] C5.1 确认每个模块 Composition 引用本模块 Application、Infrastructure 和 Contracts，但不承载业务实现。
- [ ] C5.2 确认 ApiHost 不直接注册具体业务 Service/Repository/Adapter，只按依赖顺序调用模块 Composition。
- [ ] C5.3 为模块装配建立启动测试：缺失实现、重复实现、错误生命周期和循环依赖应快速失败。
- [ ] C5.4 明确进程内 Adapter 的替换点，证明未来 HTTP/gRPC Adapter 可在不修改消费方 Application 的情况下接入。
- [ ] C5.5 记录模块启动依赖仅代表部署组合关系，不等价于允许任意项目引用或共享数据库访问。

## Phase 6 — 验证、迁移收尾与文档

- [ ] **Phase 6 完成**：本 Phase 下全部项目均已完成并附有证据。

- [ ] C6.1 运行完整 build 与相关模块测试，确认没有因项目/namespace 重命名产生遗漏。
- [ ] C6.2 运行编译期依赖检查，确认 Domain 不引用 Contracts，Application 不引用其他模块 Contracts。
- [ ] C6.3 运行关键业务功能测试，确认 KYC 与 Class 状态判定的业务结果和租户隔离无回归。
- [ ] C6.4 移除过期兼容 shim、旧 `Abstractions` 项目引用和空项目；若暂不能移除，登记有到期日的豁免。
- [ ] C6.5 更新架构图、模块模板、命名规范和“新增跨模块同步调用”的评审清单。
- [ ] C6.6 保存最终项目引用图、公共 surface 快照、测试报告和 LayerGuard 报告作为完成证据。

## 完成标准（Definition of Done）

- [ ] C-D01 `Contracts` 仅包含最小公共协议，不包含业务或基础设施实现。
- [ ] C-D02 提供方 Application 实现自身能力，Composition 注册实现，ApiHost 只装配模块。
- [ ] C-D03 消费方 Application 只依赖自己的 Port；外部 Contract 仅出现在外层 Adapter。
- [ ] C-D04 当前全部真实跨模块同步调用均完成迁移，并通过功能与隔离测试。
- [ ] C-D05 未使用 Reader 已删除或内部化，内部 Application DTO 不再复用公共 DTO。
- [ ] C-D06 未来进程外 Adapter 的替换边界已通过测试或最小 spike 验证。
