# 子计划 6：提供方入站 Adapter 与版本化事件映射边界

> 状态：Phase 0–6 实施与 repository verification 完成；SQL Server、LayerGuard、G03 Phase 9、G05 Phase 9 及全解方案 1251/1251 测试通过。G03 closure 按权威审计保持 `pre-ready`，不在本计划中宣称生产验收。证据：[P06 实施回交](../evidence/plan06/P06-implementation-handback.md)。
> 编写日期：2026-09-15；源码观察基线：`2e5a12d`。
> 来源：关于 C2.8、Provider Inbound Adapter、Application/Contracts 依赖及 V1 事件映射的架构讨论。
> 定位：Plan 01/B2 与 Plan 02/B3 后的独立结构演进；保留现有公共 V1 协议、模块化单体发布、G01/G02 事务边界及 G03/G05 治理语义。
> 上游基线：[Plan 01](01-contracts-adapters-refactor.md) · [Plan 02](02-reliable-integration-events.md) · [G03 catalog](../gates/G03/contract-event-catalog.yaml) · [G05 context](../gates/G05/context-sensitive-data-boundary.zh-CN.md) · [严格边界规则](../layerguard-strict-boundaries.zh-CN.md)。
> 进度规则：只有对应实现、行为验证与证据完成后才勾选项目；Phase 中全部项目完成后才勾选 Phase。

## 1. 目标与范围

使模块 Application 不再依赖本模块对外的版本化 `*.Contracts` 程序集。提供方 Infrastructure 入站 Adapter 实现公开同步 Contract，处理可信入口、协议版本和请求转换，再调用提供方 Application 自有用例。消费方 Infrastructure 出站 Adapter 继续实现消费方 Application Port。业务用例决定已发生的事实；生产方 Infrastructure 在同一本地事务内将内部事实映射成公开 V1 Integration Event、封装 Envelope 并写入 Outbox。消费方 Infrastructure 继续验证和转换入站事件，再调用本模块 Application。

| 位置 | 拥有的职责 | 不承担的职责 |
| --- | --- | --- |
| Provider `Contracts` | V1 公共接口、请求/响应、事件 schema、identity 与稳定错误语义 | 业务实现、DI、持久化、入口身份验证、传输和 Outbox |
| Provider `Application` | 自有用例接口与内部模型、业务授权、资源 tenant 不变量、内部业务事实、持久化 Port | V1 wire DTO、schema/version 选择、外部传输与 Envelope 封装 |
| Provider `Infrastructure.Integrations.Inbound` | 实现公开同步 Contract；校验可信 consumer、context version、scope 与协议形状；建立隔离上下文并转换结果 | 仅凭请求自报 actor/provenance 授权、替代 Application 的业务判断 |
| Consumer `Infrastructure.Integrations.Outbound` | 实现消费方 Port；从可信执行上下文生成请求；调用 provider Contract 并映射失败 | 在消费方 Application 引入 foreign Contract 或复制提供方规则 |
| Producer `Infrastructure.Messaging` | 内部事实到公开 V1 的映射、Envelope/Outbox、同事务持久化 | 提交后临时补造事件或改变业务事实含义 |
| Consumer `Infrastructure.Messaging/Integrations.Inbound` | 事件版本、producer、tenant、payload 校验；Inbox/隔离；转换为本模块命令 | 让 Application 反序列化外部 V1 payload |
| `Composition` | 唯一且生命周期正确的接口、用例、Adapter 与事务参与者注册 | 业务逻辑或协议版本决策 |

本计划是结构迁移，不借机改变 KYC、认购开放、IAM 授权、Transaction/Registry 事件事实、现有 V1 字段与错误码，也不引入 HTTP/gRPC、独立模块部署或新业务能力。`IFX.Platform.Context.Contracts` 等已批准的 BCL-only context primitive 可按 G03/G05 规则继续被 Application 使用；“解除依赖”专指模块 Application 对其**本模块公开版本化 Contracts** 的项目引用。

## 2. 已核对的现状与迁移映射

本节“当前源码”是实施起点 `2e5a12d` 的历史快照；已删除或移动的路径保留为迁移定位记录，实施后位置见第 3 节与 [实施回交](../evidence/plan06/P06-implementation-handback.md)。

| 当前源码或装配 | 观察 | 目标动作 |
| --- | --- | --- |
| CRM Application `Contracts/AccountComplianceContract.cs`（已删除） | Application 直接实现 `IAccountComplianceContract`，并在查询前校验 consumer/context/tenant | 拆出 Application 自有用例；CRM Infrastructure 入站 Adapter 实现原公开接口、执行入口校验并委托用例 |
| Registry Application `Contracts/ClassSubscriptionAvailabilityContract.cs`（已删除） | 与 CRM 相同的 Application 公开 Contract 实现 | 按相同边界拆分，保持关闭/不存在/拒绝/不可用语义 |
| [IAM `ResourceAuthorizationService`](../../../../src/Modules/IAM/IFX.Modules.IAM.Application/Access/ResourceAuthorizationService.cs) | 同时实现本地 Application 服务与 `IAM.Contracts.V1` 授权接口 | 保留 IAM.Access 用例及本地权限语义；由 IAM Infrastructure 入站 Adapter 实现公开接口，不重写 Plan 05 的政策所有权 |
| Transaction CRM/Registry 出站 Adapter（原 `Infrastructure/Integrations/CRM|Registry`，已移动） | 已实现消费方 Port 并调用 V1 Contract | 保持行为，明确 Outbound 目录/命名及当前装配；不复制新的 provider 校验 |
| [Registry `DeleteClassCommandHandler`](../../../../src/Modules/Registry/IFX.Modules.Registry.Application/FundClasses/Commands/DeleteClass/DeleteClassCommandHandler.cs) | Application 直接构造 `ClassStatusChangedV1` | 产生 Registry 内部不可变事实；Registry Infrastructure Outbox 参与者映射为原 V1 |
| [Transaction `ProcessTransactionCommandHandler`](../../../../src/Modules/Transaction/IFX.Modules.Transaction.Application/Commands/ProcessTransaction/ProcessTransactionCommandHandler.cs) 与 `ConfirmOrderCommandHandler` | Application 直接构造 `TransactionProcessedV1` | 两条真实生产路径改用同一种内部事实；Transaction Infrastructure 映射为原 V1 |
| [Registry Outbox 参与者](../../../../src/Modules/Registry/IFX.Modules.Registry.Infrastructure/Messaging/RegistryOutboxParticipant.cs) 与 Transaction 对应实现 | 目前要求 Buffer 中已经是公开 V1 payload | 在 `PrepareAsync` 中验证内部事实并映射 V1，仍与业务变更原子提交 |
| [Holdings 事件入站处理器](../../../../src/Modules/Holdings/IFX.Modules.Holdings.Infrastructure/Messaging/HoldingsInboundIntegrationEventHandler.cs) | 已在 Infrastructure 校验/反序列化 V1 并转换为 Application 命令 | 保留该边界，补足与新的 producer 映射的兼容、幂等及隔离验证 |

Phase 0 须重新扫描全部模块 Application 的 `*.Contracts` 引用、公开接口实现和版本化事件生产点；上表不是允许忽略新发现路径的穷举清单。现有 `Contracts.V1`、G03 identity 与序列化 golden 作为迁移基线，不因实现位置变化创建 V2。

## 3. 目标目录、依赖与运行调用链

```text
src/Modules/CRM/
  IFX.Modules.CRM.Contracts/V1/IAccountComplianceContract.cs
  IFX.Modules.CRM.Application/AccountCompliance/
    IAccountComplianceUseCase.cs
    AccountComplianceUseCase.cs
  IFX.Modules.CRM.Application/Ports/IAccountComplianceDataPort.cs
  IFX.Modules.CRM.Infrastructure/Integrations/Inbound/AccountComplianceInboundAdapter.cs
  IFX.Modules.CRM.Infrastructure/Integrations/Outbound/Persistence/AccountComplianceDataAdapter.cs

src/Modules/Registry/
  IFX.Modules.Registry.Contracts/V1/IClassSubscriptionAvailabilityContract.cs
  IFX.Modules.Registry.Contracts/Events/V1/ClassStatusChangedV1.cs
  IFX.Modules.Registry.Application/ClassSubscriptionAvailability/...
  IFX.Modules.Registry.Application/Events/ClassStatusChanged.cs
  IFX.Modules.Registry.Infrastructure/Integrations/Inbound/ClassSubscriptionAvailabilityInboundAdapter.cs
  IFX.Modules.Registry.Infrastructure/Messaging/ClassStatusChangedV1Mapper.cs

src/Modules/Transaction/
  IFX.Modules.Transaction.Application/Ports/IAccountCompliancePort.cs
  IFX.Modules.Transaction.Application/Ports/IClassSubscriptionAvailabilityPort.cs
  IFX.Modules.Transaction.Application/Events/TransactionProcessed.cs
  IFX.Modules.Transaction.Contracts/Events/V1/TransactionProcessedV1.cs
  IFX.Modules.Transaction.Infrastructure/Integrations/Outbound/CRM/AccountComplianceAdapter.cs
  IFX.Modules.Transaction.Infrastructure/Integrations/Outbound/Registry/ClassSubscriptionAvailabilityAdapter.cs
  IFX.Modules.Transaction.Infrastructure/Messaging/TransactionProcessedV1Mapper.cs

src/Modules/IAM/
  IFX.Modules.IAM.Contracts/V1/Authorization/IResourceAuthorizationContract.cs
  IFX.Modules.IAM.Application/Access/...                 # 本地授权用例
  IFX.Modules.IAM.Infrastructure/Integrations/Inbound/ResourceAuthorizationInboundAdapter.cs
  IFX.Modules.IAM.Infrastructure/Integrations/Outbound/Authentication/...
  IFX.Modules.IAM.Infrastructure/Integrations/Outbound/Authorization/PolicyEvaluationAdapter.cs
```

目录只是责任归属示例；实施时保持现有模块/namespace 规范，`Application/Ports` 放 Application 拥有的接口，`Application/Contracts` 不再放公开 Contract 实现。业务 Domain Event 可位于 Domain；由用例形成的内部集成事实可位于 Application，但二者均不携带 `V1`、Envelope 或 broker 类型。

```text
同步：Transaction.Application Port
    → Transaction.Infrastructure Outbound Adapter
    → CRM/Registry.Contracts.V1
    → CRM/Registry.Infrastructure Inbound Adapter（入口验证、版本与 DTO 映射）
    → Provider.Application 自有用例（资源 tenant、授权与业务规则）
    → Provider.Application 数据 Port
    → Provider.Infrastructure 数据 Adapter

异步：Registry/Transaction.Application 内部事实
    → 本模块 Infrastructure V1 mapper + Envelope + Outbox（业务提交前，同一本地事务）
    → Dispatcher/transport
    → Holdings.Infrastructure 入站校验 + Inbox + V1→命令映射
    → Holdings.Application 业务处理
```

编译期方向为 `Provider.Infrastructure → Provider.Application`、`Provider.Infrastructure → Provider.Contracts` 和 `Consumer.Infrastructure → Consumer.Application Port / G03 登记的 Provider.Contracts`；不得引入 `Application → 本模块版本化 Contracts`、`Consumer.Application → foreign Contracts` 或 `Consumer → foreign Infrastructure`。公开 V1 事件类型继续留在 provider-owned `Contracts`，让 Holdings 等消费者只依赖稳定公共 schema。

### 3.1 版本与信任边界

- `Contracts.V1`/事件 `SchemaVersion` 是公共能力和 payload 版本；`ContractRequestContext.Version` 是上下文协议版本；`SourceVersion` 是消费方身份版本；`EventEnvelope.EnvelopeVersion` 是消息封装版本。四者不得混用，也不通过修改单个数字实现 V1→V2 自动协商。
- 同步入站 Adapter 在调用 Application 用例前，按 G05 顺序验证注册 consumer、context version、scope、可信来源/actor 形状、请求与资源 tenant。对当前 CRM/Registry tenant-only 能力，`PlatformScope` 虽是合法上下文值，仍不得通过资源 tenant 检查。
- `SourceSystem`、`ActorId` 和 `Provenance == "trusted"` 等请求字段不是独立身份凭证。进程内 caller 身份必须绑定受控装配/运行源策略；未来引入 HTTP/gRPC 时须先验证传输身份并构造可信上下文，不能把外部自报字段直接升级为 trusted。
- Application 仍检查本模块业务授权、资源 tenant 与不变量；数据查询仍使用显式 tenant predicate。把协议检查前移不能成为绕过业务校验的理由。
- 不兼容协议变更按 G03 并行新增 V+1，producer/provider 双版并存，consumer 在自身 Adapter 切换，观察与退役条件满足后才移除旧版；本计划只移动现有 V1 实现位置。

## Phase 0 — 冻结基线与逐路径清单

- [x] **Phase 0 完成**：真实源码、装配、协议和事件生产/消费路径均有可复核基线。证据：[P06-S0](../evidence/plan06/P06-S0-baseline.md)。
- [x] P06-0.1 记录实施时 Git commit、工作树状态、相关 LayerGuard/G03/G05 报告及 V1 public API/serialization golden hash；与本文件观察基线的差异逐项说明。
- [x] P06-0.2 列出全部模块 Application 对本模块 `*.Contracts` 的项目、namespace、类型引用，区分同步公开接口、V1 集成事件与已批准的 Platform context primitives。
- [x] P06-0.3 对 CRM、Registry、IAM 同步入口和 Transaction/Registry 事件生产者、Holdings 消费者画出真实 DI、调用、事务与失败路径，确认每个 provider capability 只有一个运行实现。
- [x] P06-0.4 从 G03 catalog 与 G05 conformance 导入现有 identity、字段分类、版本、consumer allowlist、scope、稳定错误码、取消/超时与 tenant 规则；迁移前后逐项对账。
- [x] P06-0.5 固定非目标：不改变业务结果、V1 wire schema/序列化、Outbox/Inbox 表结构、发布方式、服务边界或未完成 Gate 的状态。

## Phase 1 — 建立 Application 自有用例与内部事实

- [x] **Phase 1 完成**：Application 用例和内部事实不依赖本模块公开 V1 类型，原有业务判断仍在 Application。
- [x] P06-1.1 为 CRM compliance、Registry subscription availability 定义 Application 自有用例接口、输入/结果与实现；保留 tenant 资源约束、业务判定、取消与提供方数据 Port。
- [x] P06-1.2 拆分 IAM `ResourceAuthorizationService` 的本地服务与公开 V1 入口，保持 IAM.Access 的当前用户、政策组合、scope/tenant 与拒绝语义；不得把 IAM 数据或政策规则搬入 Infrastructure。
- [x] P06-1.3 为 Registry `ClassStatusChanged`、Transaction `TransactionProcessed` 定义不可变内部事实，覆盖全部真实生产路径；内部事实使用业务字段和语义，不包含 V1 identity、Envelope/transport metadata 或外部序列化属性。
- [x] P06-1.4 明确内部事实由 Application 在正确业务状态变化时产生，取消/失败/rollback 时不产生可提交的消息；不要把事件“是否发生”的判断挪到 Outbox mapper。
- [x] P06-1.5 为用例与内部事实添加业务测试，证明允许、拒绝、缺失、跨租户及关键状态变化与迁移前一致。

## Phase 2 — 提供方同步 Inbound Adapter

- [x] **Phase 2 完成**：公开同步 Contract 由提供方外层 Adapter 实现，入口校验在调用 Application 前执行。
- [x] P06-2.1 在 CRM/Registry Infrastructure 实现 V1 入站 Adapter，先按 G05 顺序验证，再构造隔离的 provider child execution scope、转换请求并调用自有 Application 用例。
- [x] P06-2.2 在 IAM Infrastructure 实现授权 V1 入站 Adapter，保留当前 consumer allowlist、当前执行上下文匹配、user/tenant/scope 约束与稳定拒绝结果。
- [x] P06-2.3 保持 Contract 异常/响应、取消、超时、不可用和 business-false 的现有对外语义；边界异常不泄漏内部类型或敏感字段。
- [x] P06-2.4 更新 CRM、Registry、IAM Composition：公开接口各有唯一 Inbound Adapter；Application 用例各有唯一实现；生命周期与并行/嵌套 execution scope 安全。
- [x] P06-2.5 删除 Application 中直接实现公开 V1 接口的旧 façade 与相关 using；检查不存在可绕过入口验证的意外公开 DI 路径，同时保留 Application 自身的 tenant/业务校验。

## Phase 3 — 消费方 Outbound Adapter 与同步兼容性

- [x] **Phase 3 完成**：Transaction 的 Application Port 与业务调用方式不变，出站适配及 provider 入站适配协同工作。
- [x] P06-3.1 将 Transaction→CRM/Registry 出站 Adapter 明确归入 `Integrations/Outbound`；保留从可信 ExecutionContext 创建新 RequestId、继承 CorrelationId、设置 CausationId 与 source `ifx.transaction.v1` 的行为。
- [x] P06-3.2 核对 CRM/Registry/Holdings/Transaction→IAM 授权出站 Adapter 与新的 IAM 入站实现，确保 consumer identity、context version、actor 和 tenant 匹配规则不漂移。
- [x] P06-3.3 覆盖直接进程内载体的成功、业务拒绝、未知 consumer、伪造/synthesized provenance、tenant mismatch、超时、不可用和调用方取消，并在 context 构造/反序列化边界验证错误 version、缺失 scope；未批准请求不得到达 Application 数据 Port。
- [x] P06-3.4 验证消费方 Application 不引用 foreign Contract，提供方 Application 不引用其本模块公开 V1 Contract；不通过复制 DTO 或引用 foreign Infrastructure 绕过依赖检查。

## Phase 4 — 版本化事件仅在 Infrastructure 映射

- [x] **Phase 4 完成**：Application 不构造公开 V1 事件；现有事件事实、wire payload 与可靠投递语义保持一致。
- [x] P06-4.1 在 Registry/Transaction Infrastructure 为每个内部事实建立显式、穷尽的 V1 mapper；未登记内部事实和不支持版本 fail closed，不静默丢弃或猜测默认类型。
- [x] P06-4.2 在本模块 Outbox 参与者的 `PrepareAsync` 中完成内部事实→V1→Envelope 映射，并与业务写入同一 DbContext/本地事务提交；失败时业务与 Outbox 一起回滚。
- [x] P06-4.3 保持 EventType、SchemaVersion、字段名/类型、序列化 golden、producer、scope、tenant、correlation、causation、EventId 与现有失败/重试语义；不因重试或回放重建新业务事实。
- [x] P06-4.4 保持 Holdings Infrastructure 对两个 V1 事件的 producer/version/tenant/payload 验证、Inbox 幂等、quarantine 与 V1→Application 命令映射；验证重复、乱序及 poison 路径。
- [x] P06-4.5 运行数据库级成功/rollback/故障注入测试，证明业务行与 Outbox 原子提交、Inbox 与消费效果原子提交；不得将映射推迟到业务 commit 之后。Plan 06 定向 SQL 测试 8/8、全量数据库边界测试 122/122。

## Phase 5 — 编译期、装配与协议门禁

- [x] **Phase 5 完成**：结构和行为均由可重复测试与权威门禁验证，未改变公开 V1 协议。
- [x] P06-5.1 移除 CRM、Registry、Transaction、IAM Application 对各自 `*.Contracts.csproj` 的直接项目引用；如发现仍需保留的使用点，记录原因并移至合法外层边界，不以空壳引用宣称解耦。
- [x] P06-5.2 执行 LayerGuard 与项目引用图检查：Domain 零 Contract 依赖，Application 零模块公开 V1 依赖，Adapter 只依赖自有 Application 与 G03 登记的 Contracts，模块间无 Infrastructure 引用或同步环。Plan 06 LayerGuard baseline 为零 entry、报告为 0 new/0 stale。
- [x] P06-5.3 执行 G03 source reconciliation、public API snapshot、serialization golden 与字段分类校验；V1 identity、签名、schema 和已批准 consumer 不得发生无 Change Record 漂移。G03 Phase 9 通过，重建快照与权威快照无 diff。
- [x] P06-5.4 执行 G05 Contract context 与 Event Envelope conformance，验证 validation 顺序、稳定 reason code、可信来源、tenant、嵌套/并行 scope 及敏感字段不进入日志。G05 Phase 9 与全量 verification 通过。
- [x] P06-5.5 运行相关模块单元、DI/集成、真实数据库 Outbox/Inbox 与全解方案 build/test；只在检查通过且差异解释完整后生成本计划证据。`IFX.sln` 0 error，全量 1251/1251 tests passed。

## Phase 6 — 文档、治理与回交

- [x] **Phase 6 完成**：目录、架构图、历史计划与权威 Gate 对实际源码保持一致。
- [x] P06-6.1 更新 Plan 01 的 C2.1/C2.2/C2.8、目标图和实现说明，明确 B2 是历史基线，Plan 06 迁移后由 Provider Infrastructure Inbound Adapter 实现公开接口、Application 实现自有用例；不改写历史 B2 证据。
- [x] P06-6.2 更新 Plan 02 的事件生产调用链、内部事实→V1 mapper 与 Outbox 原子性说明；不把未完成的生产环境/Gate 关闭项标记完成。
- [x] P06-6.3 更新总计划、计划索引、双语目标设计及目录示例；将旧“Provider Application 直接实现公开 Contract”的规则改为有时间边界的历史记录或新目标说明。
- [x] P06-6.4 向 G03/G05 回交新的真实实现位置、source reconciliation、context/事件行为测试和依赖图；G03/G05 repository gates 已通过，G03 closure 仍按权威审计保持 `pre-ready`，未越权更新 lifecycle。
- [x] P06-6.5 保存迁移前后调用链、项目依赖图、V1 snapshot diff、测试报告、LayerGuard 结果和已知限制，供独立审查。证据：[实施回交](../evidence/plan06/P06-implementation-handback.md)；LayerGuard 当前为启动前绑定不一致，非通过报告。

## 完成标准（Definition of Done）

- [x] P06-D01 公开同步接口及版本化事件 schema 仍由提供方 Contracts 拥有，公共 V1 identity、字段、错误和序列化行为保持兼容。
- [x] P06-D02 CRM、Registry、IAM 公开同步接口由各自 Infrastructure Inbound Adapter 实现；版本/来源检查先于 Application 用例，业务授权和资源 tenant 不变量仍由 Application 守住。
- [x] P06-D03 Transaction 等消费方 Application 只调用自有 Port；出站 Adapter 是 foreign Contract 的唯一桥接点。
- [x] P06-D04 Registry/Transaction Application 只产生内部事实，不知道 V1/V2；Infrastructure 在同一本地事务内映射 V1 并写入 Outbox，Holdings 入站消费保持幂等和隔离。
- [x] P06-D05 受影响模块 Application 对本模块公开 `*.Contracts` 的项目依赖为零；已批准 Platform context primitive 依赖单独记录，不被误报。
- [x] P06-D06 入口身份不由请求自报字段独立证明；未知 consumer/version、跨租户、伪造来源和不可信 context 均 fail closed，且不泄漏敏感数据。
- [x] P06-D07 DI、编译期依赖、G03/G05、功能、事务/数据库和回归测试通过，实际证据可重建；历史 B2/B3 和未关闭 Gate 状态保持真实。
- [x] P06-D08 计划、架构文档、图、目录约定、权威目录与实际源码一致，并完成源码、模块行为与架构门禁复核。

## 安全与回退原则

- [x] P06-R01 采用“新增 Application 用例和 Inbound Adapter → 切换 DI → 删除旧 façade”的可回退顺序；任一阶段失败时恢复上一条已验证装配，不允许保留两个公开接口实现导致不确定解析。
- [x] P06-R02 事件迁移采用“新增内部事实与 mapper → golden/数据库对比 → 切换生产点 → 删除 Application V1 引用”的顺序；不能通过提交后发布或跳过 Outbox 作为回退。
- [x] P06-R03 若上下文或版本拒绝造成兼容问题，先对照 G03/G05 已批准的 consumer/version 矩阵修复；不得放宽 tenant、trusted provenance 或 producer 校验制造绿色结果。
- [x] P06-R04 实施期间保留现有 V1 Contract 接口、事件 schema、历史消息和回放能力；若确需 V2，另按 G03 breaking-version migration 建立并行版本与观察窗口，不在本计划中原地改写 V1。
