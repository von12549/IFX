# 子计划 7：Inbound / Outbound Contract Adapter 公共运行组件提取

> 状态：草案，尚未实施。
> 编写日期：2026-09-15；源码观察基线：`3ef1c92`。
> 来源：Plan 06 完成后对 CRM、Registry、IAM、Holdings、Transaction `Infrastructure/Integrations/Inbound|Outbound` 重复代码的复核，以及关于 `Validate`、`CreateChildContext`、`ContractRequestContext` 构造和 `ResourceAuthorizationAdapter` 共享方式的架构讨论。
> 定位：[Plan 06](06-contract-adapter-event-boundary.md) 的独立后续重构；只收敛跨 Adapter 的技术性边界算法，不改变 Contracts、Application 用例、模块自有 Port、公开 V1 协议或业务授权政策。
> 上游基线：[Plan 06 实施回交](../evidence/plan06/P06-implementation-handback.md) · [G03 catalog](../gates/G03/contract-event-catalog.yaml) · [G05 context](../gates/G05/context-sensitive-data-boundary.zh-CN.md) · [严格边界规则](../layerguard-strict-boundaries.zh-CN.md)。
> 进度规则：只有对应实现、行为验证与证据完成后才勾选项目；Phase 中全部项目完成后才勾选 Phase。

## 1. 目标与范围

将同步 Contract Adapter 中重复且安全敏感的上下文验证、provider child context 构造、outbound request context 构造，以及 IAM 授权 Contract 调用流程提取为可复用的外层运行组件。具体 Inbound/Outbound Adapter 继续存在，并继续负责实现模块边界接口、声明固定 consumer/provider identity、转换业务请求/响应，以及维持各 Contract 的失败语义。

| 位置 | 提取后的职责 | 明确保留的职责 |
| --- | --- | --- |
| `IFX.Platform.Context.Runtime` | 同步 Contract context 的通用验证、失败分类、provider child context 与 outbound context 构造 | 不知道 CRM/Registry/IAM DTO、业务规则、Contract Exception 或 Event Envelope |
| Provider `Infrastructure.Integrations.Inbound` | 选择入口 policy、映射验证失败、建立 scope、调用本模块 Application 用例、映射响应 | 不重复实现 context version/provenance/ambient/tenant 算法 |
| `IFX.Modules.IAM.Client` | 从可信执行上下文构造 IAM V1 请求、映射授权资源、调用 IAM Contract、统一 fail-closed 行为 | 不实现消费方 Application Port，不拥有消费方 identity，不执行 IAM 业务政策 |
| Consumer `Infrastructure.Integrations.Outbound` | 实现本模块 Application Port、固定本模块 consumer identity、把本模块模型交给 client | 不重复实现 IAM V1 DTO/context/拒绝处理 |
| Consumer `Application` | 继续拥有 Port 和业务调用；可使用批准的非版本化授权资源 primitive | 不引用 IAM Contract、IAM Client、Context Runtime 或其他模块 Infrastructure |
| Provider `Contracts` | 继续拥有公开 V1 接口、请求/响应和稳定错误语义 | 不加入 validator、factory、DI 或 client 实现 |

本计划不统一同步 Contract 与 Integration Event 的验证管道。Holdings 的 `EventEnvelope` producer/schema/tenant/quarantine 检查属于消息入口，仍保留在事件运行时或专用事件验证器中。本计划也不通过抽象基类合并完整 `CheckAsync`/`AuthorizeAsync`，不改变 IAM policy、KYC、subscription availability、Outbox/Inbox、数据库 schema、传输方式或发布边界。

## 2. 已核对的重复点与保留差异

| 当前实现 | 已观察的重复 | 必须保留的差异 |
| --- | --- | --- |
| CRM/Registry Inbound Adapter | `Validate` 对 consumer、context version、scope、trusted provenance、ambient actor/tenant 的检查一致；`CreateChildContext` 仅 provider component 不同 | Request/Response、Application 用例、Contract Exception 类型、provider identity 与业务结果映射 |
| IAM Inbound Adapter | version/source/provenance/ambient/tenant 校验与 CRM/Registry 部分同构 | 允许四个 consumer、只允许 user actor、以拒绝响应而非 Contract Exception 表达失败，当前不建立 CRM/Registry 式 child scope |
| Holdings event Inbound Handler | 存在名为 `Validate` 的入口检查 | 输入是 `EventEnvelope`，还包含 producer/event type/quarantine/Inbox 语义，不进入同步 Contract 抽象 |
| 四个模块 IAM Outbound Adapter | 除模块 Application Port 类型和 `sourceComponent` 外，trusted context、V1 context/DTO 构造、IAM 调用和 deny→`ForbiddenException` 完全一致 | 每个模块必须继续实现自己的 Port，并静态固定 `crm|registry|holdings|transaction` consumer identity |
| Transaction→CRM/Registry Outbound Adapter | 共用 context factory，取消传播和 timeout/Contract/context failure→`false` 骨架重复 | foreign Contract DTO/Exception、端口方法和返回字段不同 |
| 五个 Application 授权 Port | `ResourceAttributes` 的六个字段重复，Port 签名同构 | Port ownership 仍属于各模块；不能让 Application 改为依赖 IAM V1 DTO |

Phase 0 必须用源码和测试重新生成逐文件清单，并区分“相同算法”“相似名称”和“不同安全语义”。只有经行为矩阵证明等价的路径才能共享实现。

## 3. 目标结构与依赖方向

```text
src/Platform/Context/
  IFX.Platform.Context.Contracts/
    ContractRequestContext.cs                         # 保持纯协议 primitive
  IFX.Platform.Context.Runtime/
    Inbound/InboundContractContextValidator.cs
    Inbound/InboundContractPolicy.cs
    Inbound/ContractContextFailure.cs
    Inbound/ProviderExecutionContextFactory.cs
    Outbound/OutboundContractRequestContextFactory.cs
    Outbound/ContractConsumerIdentity.cs

src/BuildingBlocks/IFX.BuildingBlocks.Security/
  Authorization/AuthorizationResourceAttributes.cs   # 非版本化 Application primitive

src/Modules/IAM/
  IFX.Modules.IAM.Contracts/V1/Authorization/...      # 保持公开 V1
  IFX.Modules.IAM.Client/
    Authorization/IamResourceAuthorizationClient.cs
    Authorization/IamAuthorizationRequestMapper.cs

src/Modules/<Consumer>/
  IFX.Modules.<Consumer>.Application/Ports/Authorization/
    IResourceAuthorizationService.cs                  # 继续由模块拥有
  IFX.Modules.<Consumer>.Infrastructure/Integrations/Outbound/IAM/
    ResourceAuthorizationAdapter.cs                   # 薄 Adapter，固定 consumer identity
```

编译期方向：

```text
Module.Infrastructure
    ├──> own Module.Application Port
    ├──> IFX.Platform.Context.Runtime
    └──> IFX.Modules.IAM.Client
              ├──> IFX.Modules.IAM.Contracts
              ├──> IFX.Platform.Context.Runtime
              └──> IFX.BuildingBlocks.Security

IFX.Platform.Context.Runtime
    ├──> IFX.Platform.Context.Contracts
    └──> IFX.BuildingBlocks.Application.Context

Module.Application
    └──> IFX.BuildingBlocks.Security authorization primitive
    X    IFX.Platform.Context.Runtime / IAM.Client / IAM.Contracts
```

`IFX.Modules.IAM.Client` 是 provider-owned、version-aware 的外层 client library，不是新的业务层，也不是公共 Contract。LayerGuard 必须只允许 Infrastructure/Composition 依赖它，禁止 Domain/Application 引用。消费者不得直接注册 client 代替自己的 Adapter，否则会丢失消费方 Port ownership 和固定 identity 接缝。

## 4. 目标调用链

### 4.1 同步 Inbound

```text
Provider Contract method
    → concrete Inbound Adapter 选择不可变 policy
    → InboundContractContextValidator
         consumer/version/scope/provenance/ambient actor+tenant/resource tenant
    → Adapter 将 ContractContextFailure 映射为本 Contract 的异常或拒绝响应
    → ProviderExecutionContextFactory 创建隔离 child context（仅需要的入口）
    → scopeFactory.Push
    → Provider Application use case
    → Adapter 映射 Contract response
```

Validator 返回稳定的内部失败分类，不抛 CRM/Registry/IAM 专用异常。Adapter 必须穷尽映射 `ConsumerDenied`、`ContextInvalid`、`TenantMismatch`；未知分类 fail closed。policy 必须显式提供允许的 consumer、source version、actor kind、scope 和 tenant 要求，不允许 wildcard、隐式默认 tenant 或从请求正文读取 identity。

### 4.2 IAM Outbound

```text
Consumer Application
    → own IResourceAuthorizationService Port
    → module ResourceAuthorizationAdapter（固定 sourceComponent）
    → IamResourceAuthorizationClient
         reject runtime parameters
         require trusted ambient context
         OutboundContractRequestContextFactory
         shared attributes → IAM V1 DTO mapper
         IAM.Contracts.V1.AuthorizeAsync
         denied → ForbiddenException
    → IAM Infrastructure Inbound Adapter
    → IAM Application authorization use case
```

### 4.3 Transaction→CRM/Registry Outbound

```text
Transaction Application Port
    → concrete CRM/Registry Outbound Adapter
    → shared OutboundContractRequestContextFactory.CreateTenantCall
    → provider Contract
    → concrete Adapter 保留 cancellation 与 fail-closed response mapping
```

若提取 fail-closed 调用壳，应限制在 Transaction Infrastructure 内部，并只捕获明确列出的 protocol/context/timeout 异常。不得用 `catch (Exception)` 或字符串前缀判断吞掉程序错误。

## Phase 0 — 冻结重复与行为基线

- [ ] **Phase 0 完成**：重复点、差异矩阵、依赖边和迁移前行为均有可复核证据。
- [ ] P07-0.1 记录实施时 Git commit、工作树、solution/project 清单、LayerGuard/G03/G05 报告和相关测试结果；证据保存到 `docs/architecture/review/evidence/plan07/`。
- [ ] P07-0.2 扫描全部 `Infrastructure/Integrations/Inbound|Outbound`，按 context validation、context creation、scope、DTO mapping、异常处理和业务委托分类；不得只扫描当前已知文件。
- [ ] P07-0.3 固定 CRM/Registry/IAM Inbound 的 consumer/version/actor/scope/tenant/失败矩阵，以及四个 IAM Outbound 的 context、resource mapping 和拒绝矩阵。
- [ ] P07-0.4 对 `ResourceAttributes` 五份定义做字段、nullability、调用点和语义对账；只有确认一致后才迁移为共享非版本化 primitive。
- [ ] P07-0.5 固定非目标和 public API/schema golden：不改变公开 V1 signature/serialization/error code，不改变业务结果、DI lifetime、event pipeline 或 Gate lifecycle 状态。

## Phase 1 — 建立共享 Context Runtime

- [ ] **Phase 1 完成**：共享项目只包含协议边界运行算法，并由独立测试证明 fail-closed 行为。
- [ ] P07-1.1 新建 `IFX.Platform.Context.Runtime` 并加入 solution；只引用 Context Contracts 与 ExecutionContext 抽象，不引用任何模块 Contracts/Application/Infrastructure。
- [ ] P07-1.2 实现 `InboundContractContextValidator`、不可变 `InboundContractPolicy` 和 `ContractContextFailure`；保留 G05 要求的 validation 顺序，不通过 permissive default、optional trust 或异常消息泄漏内部数据。
- [ ] P07-1.3 实现 `ProviderExecutionContextFactory`：保留 correlation/causation，创建新 operation，使用经验证的 scope/tenant/actor，并显式设置 provider identity/version。
- [ ] P07-1.4 实现 `OutboundContractRequestContextFactory` 与强类型 consumer identity；创建新 request id，继承 correlation，以当前 operation 为 causation，并区分 trusted、tenant-required 与允许 synthesized 后由 provider 拒绝的现有路径。
- [ ] P07-1.5 添加 policy、错误分类、无 ambient context、不可信 provenance、actor/scope/tenant 不匹配、嵌套/并行 context 和 scope 恢复测试。

## Phase 2 — 收敛同步 Inbound Adapter

- [ ] **Phase 2 完成**：CRM/Registry 不再复制 context 算法，IAM 复用公共校验且保持自身语义。
- [ ] P07-2.1 CRM/Registry Inbound Adapter 改用 shared validator 和 provider context factory；具体 Contract method、DTO、异常、Application use case 与 response mapping 留在本模块。
- [ ] P07-2.2 IAM Inbound Adapter 使用同一 validator 表达允许四个 consumer、user actor 与 tenant/platform scope 政策；保持拒绝响应和本地授权调用，不为代码统一而强制新增 child scope。
- [ ] P07-2.3 删除三处已被替代的私有 context validation/creation 代码，确认没有第二套等价检查继续漂移；Application 的业务授权与资源 tenant 校验不得删除。
- [ ] P07-2.4 保持 Holdings `EventEnvelope` 验证独立；如扫描发现多个事件消费者确有相同算法，记录为单独 event runtime 工作项，不纳入同步 validator。
- [ ] P07-2.5 运行所有 provider inbound 正反测试，证明 validation 先于 Application/data Port，取消正常传播，内部异常不泄漏，成功后 child scope 和返回后恢复与基线一致。

## Phase 3 — 提取授权 primitive 与 IAM Client

- [ ] **Phase 3 完成**：IAM V1 调用只有一个共享实现，模块 Application 仍只依赖自己的 Port。
- [ ] P07-3.1 将经 Phase 0 证明等价的 `ResourceAttributes` 提取为 `IFX.BuildingBlocks.Security` 中的非版本化 authorization primitive；更新各模块 Port 的泛型约束，但不合并或删除模块自有 Port。
- [ ] P07-3.2 新建 provider-owned `IFX.Modules.IAM.Client`；只引用 IAM Contracts、Context Runtime 和批准的 Security primitive，不引用任何消费模块或 IAM Application/Infrastructure。
- [ ] P07-3.3 在 client 中集中 runtime parameter 拒绝、trusted ambient context、ContractRequestContext 构造、resource DTO 映射、IAM Contract 调用及 deny→`ForbiddenException` 行为。
- [ ] P07-3.4 consumer identity 使用强类型不可变值并由具体模块 Adapter 静态固定；禁止从 HTTP/body/resource/config 任意字符串覆盖 source system/component/version。
- [ ] P07-3.5 添加 client 单元测试，覆盖 tenant/platform context、全部资源字段、参数拒绝、缺失/不可信 context、IAM allow/deny、调用取消和敏感 reason 不外泄。

## Phase 4 — 收敛同步 Outbound Adapter

- [ ] **Phase 4 完成**：四个 IAM Adapter 成为模块自有 Port 的薄实现，其他同步出站调用复用 context factory 而不改变失败语义。
- [ ] P07-4.1 CRM、Registry、Holdings、Transaction 的 IAM Outbound Adapter 委托共享 client，只保留模块 Port、静态 consumer identity 和必要的本地模型接缝。
- [ ] P07-4.2 Transaction→CRM/Registry Adapter 改用共享 outbound context factory，删除 Transaction 私有 `ContractRequestContextFactory`。
- [ ] P07-4.3 评估剩余两个 fail-closed 布尔调用壳；若提取，使用 typed context failure 和明确 Contract Exception 类型，替代当前基于 `InvalidOperationException.Message` 前缀的识别。
- [ ] P07-4.4 Persistence Adapter、IAM Authentication/Authorization provider Adapter 保持具体实现；只有扫描证明算法等价才提取 mapper/helper，不以方法名相似作为共享依据。
- [ ] P07-4.5 验证所有 consumer source identity、request/correlation/causation、scope/tenant/actor、取消、timeout、deny 和不可用结果与基线一致。

## Phase 5 — 装配、依赖与防回归门禁

- [ ] **Phase 5 完成**：共享组件的允许依赖和唯一调用路径由自动化规则保护。
- [ ] P07-5.1 更新 Composition/DI，确保 context runtime/client 生命周期正确，每个模块 Port 仍只有一个 Adapter 实现，公开 provider Contract 仍只有一个 Inbound 实现。
- [ ] P07-5.2 扩展 LayerGuard 项目角色和规则：`IAM.Client` 只允许 Infrastructure/Composition 引用；Application/Domain 禁止 Client/Runtime/foreign Contracts；Context Runtime 禁止模块依赖。
- [ ] P07-5.3 添加结构守卫，限制模块 Adapter 中重复直接构造 `ContractRequestContext`/provider child context，并防止模块间 Infrastructure 引用或直接以 IAM Client 替换 Application Port。
- [ ] P07-5.4 运行 G03 public API/serialization/source reconciliation 与 G05 context conformance；任何 V1 identity、字段、consumer、version、失败码或传播语义变化均须失败。
- [ ] P07-5.5 运行受影响模块单元测试、IntegrationTests、LayerGuard、完整 solution build/test；数据库与事件代码若无变化，记录为何无需新增数据库迁移或重复数据库故障测试。

## Phase 6 — 文档、证据与回交

- [ ] **Phase 6 完成**：目标结构、调用链、门禁和实际源码一致，并完成独立复核。
- [ ] P07-6.1 更新同步 Contract 架构图和双语边界说明，区分 Contract DTO 构造验证、Inbound trust validation、provider child scope 与 outbound context creation。
- [ ] P07-6.2 更新模块目录示例、DI 调用链、IAM client role 与 LayerGuard 规则说明；历史 Plan 06 证据保持不可改写，只增加后续计划链接。
- [ ] P07-6.3 保存迁移前后重复清单、代码量/构造点对比、依赖图、行为矩阵、public API/schema diff、测试和 LayerGuard 报告。
- [ ] P07-6.4 回交 G03/G05，确认共享实现未把 identity 字段变成凭证、未扩大 consumer allowlist、未改变字段分类或 Gate lifecycle 状态。
- [ ] P07-6.5 完成源码、测试、文档和生成证据的最终扫描；不存在旧 helper、无用项目引用、双实现、空目录或构建生成的遗留路径。

## 完成标准（Definition of Done）

- [ ] P07-D01 CRM/Registry/IAM 同步 Inbound 共用一套 context validation primitive，具体 Adapter 保留各自 policy、Contract 失败和业务映射。
- [ ] P07-D02 provider child context 与 outbound ContractRequestContext 由共享 Context Runtime 构造，标识传播、scope 隔离和 trusted provenance 与 Plan 06 基线一致。
- [ ] P07-D03 四个 IAM Outbound Adapter 不再复制 V1 context/DTO/调用/拒绝算法，但仍分别实现 CRM、Registry、Holdings、Transaction 自有 Application Port。
- [ ] P07-D04 Application 不引用版本化 Contracts、Context Runtime、IAM Client 或 foreign Infrastructure；Contracts 不包含 validator/factory/client 实现。
- [ ] P07-D05 IAM consumer identity 由具体 Adapter 固定，未知 consumer、不可信 context、跨租户、非法参数和 provider deny 均 fail closed。
- [ ] P07-D06 同步 Contract 与 Integration Event 验证没有被错误合并；Event producer/schema/quarantine/Inbox 行为保持不变。
- [ ] P07-D07 公开 V1 API/schema/error、业务结果、DI 唯一性和 context 行为通过 G03/G05、LayerGuard、单元、集成及全解方案验证。
- [ ] P07-D08 计划、架构文档、目录、依赖规则和证据与最终实现一致，且没有依赖字符串异常消息或 catch-all 的新共享路径。

## 安全与回退原则

- [ ] P07-R01 按“先建立并测试共享组件 → 单个 Adapter 切换 → 行为对比 → 删除重复实现”推进；不得先删除所有本地检查再一次性接线。
- [ ] P07-R02 Validator policy 默认拒绝，allowlist/actor/version/scope/tenant 必须显式声明；不得为了复用引入 wildcard、默认 tenant 或 optional trust。
- [ ] P07-R03 共享组件返回内部失败分类；Contract Exception/response 仍由具体 Adapter 映射，禁止把内部异常、policy reason、资源字段或 actor 数据直接暴露。
- [ ] P07-R04 若 IAM Client 切换失败，回退为上一版已验证的模块 Adapter 实现；不得让 Application 直接调用 IAM Contract，也不得让消费模块引用 IAM Infrastructure。
- [ ] P07-R05 若共享 `ResourceAttributes` 出现语义分化，保留模块模型并在薄 Adapter 显式映射；不得用可空字段、字典或弱类型对象掩盖差异。
- [ ] P07-R06 任何需要改变 V1 signature、consumer/version 或失败语义的发现必须退出本计划，按 G03 Change Record/并行版本流程处理。
