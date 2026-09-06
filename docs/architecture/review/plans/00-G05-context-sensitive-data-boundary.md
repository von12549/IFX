# Plan 00 / Gate 05：关联上下文与敏感数据边界实施计划

> 状态：Architecture Decisions Approved / 待实施
> 上级前置计划：[`00-prerequisites.md`](00-prerequisites.md)
> 上级总计划：[`00-master-plan.md`](00-master-plan.md)
> 相关治理：[`00-G03-contract-event-governance.md`](00-G03-contract-event-governance.md)
> 相关运行边界：[`00-G04-deployment-runtime-boundary.md`](00-G04-deployment-runtime-boundary.md)
> 范围：OPS1、OPS3、OPS-G1，以及 HTTP、同步 Contract、Outbox/transport/Inbox 所需的关联、因果、租户、trace、数据分类、日志和失败语义
> 前置放行：完成 primitives、可信 context 基础、分类/失败规则和 fake-carrier conformance；真实 Contract/Event carrier 由子计划 1/2 实现并回交最终证据
> Gate 关闭条件：本计划全部 Phase、Definition of Done 和中英文图文交付均已完成

## 目标

为所有入口和模块通讯建立一套不依赖 HTTP 或具体 broker 的可信执行上下文：业务链使用稳定的 CorrelationId，单次调用使用 OperationId，直接原因使用 CausationId，Integration Event 使用不可变 EventId，技术追踪使用 W3C Trace Context，租户范围用显式 TenantScope/PlatformScope 表达。同步 Contract、事件 Envelope、日志、trace 和错误响应同时受到字段级敏感数据规则约束。

本 Gate 交付可复用的上下文语义、最小协议原语、入口验证、分类目录和 conformance tests。最终模块 Contracts 的迁移由子计划 1 执行，可靠 Outbox/Inbox 与真实 transport 传播由子计划 2 执行；两者必须复用本 Gate 的规则和测试，不得重新定义另一套上下文。

## 非目标

- [ ] G05-N01 不在本 Gate 完成全部 `*.Abstractions` → `*.Contracts` 迁移或删除旧 Reader/DTO。
- [ ] G05-N02 不在本 Gate 实现最终 Outbox、Inbox、Dispatcher、broker、dead-letter 或 replay 引擎。
- [ ] G05-N03 不把 CorrelationId、TraceId、EventId 或 TenantId 当作彼此的替代品，也不以它们代替业务幂等键或授权。
- [ ] G05-N04 不建立承载业务模型、通用 Result、ClaimsPrincipal 或 token 的共享 Context/SharedKernel。
- [ ] G05-N05 不允许通过字段改名、截断、普通 hash 或 serializer ignore 规避敏感数据分类。
- [ ] G05-N06 不在未识别真实用途、消费者和保留要求前批准 C3/C4 数据进入公共协议。

## 当前实现基线

| 位置 | 当前行为 | 风险/差距 |
| --- | --- | --- |
| `RequestLoggingMiddleware` | 仅使用 `HttpContext.TraceIdentifier` 作为 RequestId | 没有业务 Correlation/Operation/Causation 模型，也没有统一日志 scope |
| `CurrentUser` | 从 `HttpContext` 读取用户与 Tenant；无效 `X-Tenant-Id` 静默回退 primary tenant | 无法服务 Worker/Inbox；显式错误租户可能被悄悄替换 |
| `IntegrationEvent` | 仅有 `EventId: Guid` 与 `OccurredAt: DateTime` | 缺少 schema、producer、tenant、correlation、causation 和 trace；时间类型不统一 |
| 模块事件 payload | 多数事件重复携带 TenantId；部分携带姓名、账号、金额、NAV 或自由文本原因 | Envelope/payload 职责混合，数据最小化和分类不可验证 |
| 公共 Reader DTO | `InvestorSummaryDto` 等返回姓名、KYC、税务居住国等聚合字段 | 通用 Summary surface 超过能力所需最小字段 |
| Auth/authorization 日志 | 记录 username、issuer、subject、UserId、ResourceId 和异常 message | 运维日志与审计用途混合，直接/可关联标识未分级 |
| `ExceptionHandlingMiddleware`/endpoints | 部分 Argument/KeyNotFound/Result error 原文返回客户端 | 可能暴露用户输入、内部状态或第三方错误细节 |
| Auth login record | 当前模型包含 access/refresh token 持久化字段 | 虽非跨模块 Contract，仍违反本 Gate 的 Secret retention 原则，必须单列整改 |

当前消息总线仅在进程内顺序调用 handler，并吞掉 handler 异常；当前仓库尚无持久化 Outbox backlog。因此首个可靠事件版本可直接要求完整 Envelope，不建立无期限的 legacy Envelope 兼容模式。

## 已确认架构决策

### 标识、Trace 与租户语义

- [x] G05-D01 严格区分 CorrelationId、OperationId、CausationId、EventId、TraceId/SpanId 和 TenantId：Correlation 表示完整业务链，Operation 表示当前处理边界，Causation 指向直接上游，EventId 标识不可变逻辑事件；它们不得相互代用，也不得替代业务幂等键或授权。
- [x] G05-D02 Trace 使用 W3C `traceparent`/`tracestate` 与 .NET `Activity`；同进程通过 Activity 传播，进程外由 Adapter 映射，Outbox 保存原 trace snapshot；trace 不是业务身份、审计主键或授权依据。
- [x] G05-D03 引入 transport-neutral、不可变 ExecutionContext，至少表达 CorrelationId、OperationId、CausationId、ExecutionScope、Actor 与 Source；Application 不依赖 HttpContext、JWT、ClaimsPrincipal、Activity 或 broker。
- [x] G05-D04 Tenant context 只在可信入口建立；ExecutionScope 显式区分 TenantScope(TenantId) 与 PlatformScope。Tenant-scoped 操作缺失、冲突或未授权时 fail closed，显式无效 header 不得回退 primary tenant，Platform Admin 目标租户必须显式且可审计。
- [x] G05-D05 同步调用使用与业务 DTO 分离的 BCL-only ContractRequestContext，包含 RequestId、CorrelationId、CausationId、ExecutionScope、最小 ActorReference 与 SourceReference，不含框架、实现或凭据类型。
- [x] G05-D06 Contract context 不是授权凭据：Consumer Adapter 从可信 ExecutionContext 构造，Provider Adapter 验证 consumer/scope/version 并重建 child context；未来进程外边界仍需重新认证和授权。
- [x] G05-D07 Event Envelope 至少包含 EventId、EventType、SchemaVersion、OccurredAt、Producer、TenantScope、CorrelationId、CausationId、ContentType 和可选 trace context；payload 只表达业务事实，TenantId 权威位置在 Envelope，Outbox 创建时冻结全部逻辑 metadata。
- [x] G05-D08 因果链逐 hop 生成：新 Contract 调用创建 RequestId 并以调用者 OperationId 为 CausationId；Event 以当前 Operation/Event 为直接原因；下游事件保留 CorrelationId 并以入站 EventId 为 CausationId；retry/replay 不改变原 EventId。

### 数据分类与最小化

- [x] G05-D09 使用 C0 Public、C1 Internal、C2 Confidential、C3 Restricted、C4 Secret 五级数据分类；GUID/opaque ID 仍可属于 C2，字段按业务语义而非名称判断，未分类公共字段 default deny。
- [x] G05-D10 Gate 03 权威目录扩展为字段级分类目录，记录 classification、business purpose、producer、approved consumers、requiredness、retention、log policy 和例外批准；降低级别必须安全评审。
- [x] G05-D11 Contract 按 capability/use case 返回最小字段；Restricted 仅在明确用途、Provider 授权、Tenant scope 和处理政策齐备时返回，不建立同时满足身份、KYC、税务等目的的通用 Summary DTO。
- [x] G05-D12 Event 默认采用最小 Notification Event；C3 默认禁止，只有获批 State Transfer Event 才可携带；Outbox、Inbox、broker、dead-letter、replay 和诊断存储继承 payload 最高敏感级别。
- [x] G05-D13 password、token、authorization/cookie、OTP、API/client secret、private key、connection string 等 C4 Secret 在跨模块 Contract、Event、消息存储、普通日志、审计和 trace 中绝对禁止；不得以 hash、截断或 partial masking 绕过。
- [x] G05-D14 普通运维日志与安全/合规审计分离：运维日志的 C2 默认 keyed-HMAC pseudonym、C3 redact、C4 drop；受控审计可按目的记录有限 C2/C3，但仍禁止 C4，并具备权限、不可篡改与 retention/deletion 规则。
- [x] G05-D15 span name、trace tag、baggage 和 metric label 不携带敏感或高基数业务值；Event/Contract body、SQL 参数和 HTTP body 默认不采集。
- [x] G05-D16 外部错误响应只返回稳定 ErrorCode、safe message、CorrelationId 和已清洗 validation errors；不返回 exception/SDK/SQL/内部路径或未经清洗的用户输入。
- [x] G05-D17 脱敏采用调用点数据最小化与集中 sink redaction 双层防护；字段名扫描只能辅助，不能替代字段目录、语义评审和 sentinel 测试。

### 失败、重试、门禁与文档

- [x] G05-D18 Context primitives 由受限平台协议拥有；ApiHost、Contract Adapter 和 Event Adapter 在各自边界建立 context，Application 只读抽象，Auth 提供身份/tenant membership 事实，Root Composition 选择实现。
- [x] G05-D19 HTTP 对 correlation/trace 与 tenant 使用不同失败语义：缺失/非法 correlation 或 trace 生成内部新值且不阻断业务；malformed/duplicate/unauthorized tenant 返回稳定 400/403，TenantScope/PlatformScope 显式。公共入口生成内部 CorrelationId，外部值仅作验证后的 ClientRequestId；可信网关/服务可在认证后传播。
- [x] G05-D20 Provider Adapter 在 Application 前验证 RequestId/Correlation、consumer allowlist、context version、scope、actor/source 和 tenant/resource 一致性；missing/invalid context、未登记 consumer 和 tenant mismatch 稳定拒绝，不用 ambient/default context 修补。
- [x] G05-D21 第一方消息的非法 type/version/EventId/tenant/correlation/causation 或 producer 属于 permanent/security failure，进入 quarantine/dead-letter；临时依赖故障 retry，损坏 trace 只建立新 trace。只有有 owner/截止日期的 Compatibility Adapter 可标记 `Synthesized` 并补 legacy context。
- [x] G05-D22 retry 保持逻辑 Envelope 不变，attempt/lease/error 属于 delivery metadata；replay 保持 EventId，已完成 Inbox 继续去重，强制重处理使用独立受控 ReprocessingRequest，不换 ID 绕过幂等。
- [x] G05-D23 每个 HTTP/job/message 建立和 finally 清理独立 scope；并行租户不得串扰，singleton、后台任务和 fire-and-forget 不得捕获过期安全上下文。
- [x] G05-D24 LayerGuard 只负责项目、依赖、声明和框架泄漏；Catalog/schema/security/integration/logging tests 分别负责字段语义、运行值、传播和脱敏，绿色结果不得相互替代。
- [x] G05-D25 最低测试矩阵覆盖 HTTP header/tenant、Contract correlation/causation/scope、Event Outbox/transport/Inbox/retry/replay、并行上下文隔离及敏感 sentinel。
- [x] G05-D26 建立低基数 context、tenant、contract、envelope、producer、trace restart、redaction 和 compatibility synthesis 指标/告警，不在 label 中使用原始 tenant/user/event ID 或错误 payload。
- [x] G05-D27 Gate 必须交付中英文说明、术语/分类/失败矩阵、当前与目标架构图、HTTP/Contract/Event/replay 流程图、字段目录、规则到门禁映射和测试证据；可渲染图与 Mermaid 源均保留。

## 统一标识模型

| 标识 | 所有者/创建点 | 传播/变化 | 明确禁止 |
| --- | --- | --- | --- |
| CorrelationId | 可信入口 | 完整业务链不变 | Inbox key、授权、资源 ID |
| OperationId | 每个执行/调用边界 | 每个 command/query/job/Contract call 新建 | 代替 EventId |
| CausationId | 当前 producer/adapter | 指向直接上游 OperationId/EventId | 指向模糊“最初请求” |
| EventId | Integration Event producer | retry/replay 永不改变 | delivery attempt ID |
| TraceId/SpanId | tracing runtime | 每 hop/span 按标准变化 | 业务审计/幂等主键 |
| TenantId | 已验证 ExecutionScope | 随授权 scope 传播 | 单独作为授权证明 |

```text
HTTP Operation R1 / Correlation C1
  -> Contract Request R2 / Causation R1 / Correlation C1
      -> Event E1 / Causation R2 / Correlation C1
          -> Consumer operation E1
              -> Event E2 / Causation E1 / Correlation C1
```

## 目标上下文传播

```text
Untrusted HTTP headers
        |
        v
ApiHost trace/correlation/auth/tenant adapters
        |
        +--> immutable ExecutionContext
        |       |
        |       +--> Consumer Outbound Contract Adapter
        |       |       -> ContractRequestContext
        |       |       -> Provider Inbound Adapter validates
        |       |       -> child ExecutionContext -> Application
        |       |
        |       +--> Producer local transaction
        |               -> frozen Event Envelope + Payload -> Outbox
        |
        v
Dispatcher -> transport headers -> Consumer Inbound Adapter
                                  -> Envelope validation -> Inbox
                                  -> message ExecutionContext -> Application
```

## 数据分类准入矩阵

| 分类 | Contract | Notification Event | State Transfer Event | 运维日志/Trace | 安全审计 |
| --- | --- | --- | --- | --- | --- |
| C0 Public | 允许且最小化 | 允许且最小化 | 允许 | 允许 | 允许 |
| C1 Internal | 允许 | 允许 | 允许 | 允许，避免高基数 | 允许 |
| C2 Confidential | 按 capability/consumer 批准 | 仅必要字段 | 批准、加密、保留策略 | pseudonym/聚合 | 按目的批准 |
| C3 Restricted | 明确业务目的与授权 | 默认禁止 | 例外批准及完整控制 | redact | 受控字段、独立 sink |
| C4 Secret | 禁止跨模块 | 禁止 | 禁止 | 禁止 | 禁止 |

## 入口与消息失败摘要

| 场景 | 分类 | 结果 |
| --- | --- | --- |
| correlation 缺失/非法 | Diagnostic | 生成内部 ID，不回显非法值，记录低基数 metric |
| `traceparent` 非法 | Diagnostic | 建立新 trace，业务继续 |
| Tenant header 格式错误/重复 | Client/Security | `400 tenant_context_invalid` |
| Tenant 不属于 actor | Security | `403 tenant_access_denied` + audit |
| Tenant-scoped 操作无 scope | Security | fail closed，不进 Application |
| Contract context/consumer/version 非法 | Permanent/Security | Provider Adapter 拒绝，稳定错误码 |
| Event schema/EventId/producer/tenant 非法 | Permanent/Security | quarantine/dead-letter，不 retry Application |
| Tenant/依赖暂时不可用 | Transient | 保持 Envelope retry |
| trace metadata 损坏 | Diagnostic | 新 consumer trace，保持业务 CorrelationId |
| 业务规则拒绝 | Business | 使用事件政策记录/ack，不伪装 transient infrastructure failure |

## Phase 0 — 建立暴露面与数据流基线

- [ ] **Phase 0 完成**：本 Phase 下全部项目均已完成并附有证据。

- [ ] G05-0.1 盘点所有 HTTP headers、middleware、claims transformation、ICurrentUser 使用、job/handler scope 和日志 enrichment 路径。
- [ ] G05-0.2 盘点所有同步 Reader/Contract-like DTO、Integration Event、日志模板、trace/metric、错误响应和诊断 endpoint。
- [ ] G05-0.3 对 Outbox/Inbox/dead-letter/replay 尚未实现的状态作显式标记，不把设计目标记作当前能力。
- [ ] G05-0.4 记录当前 EventId/OccurredAt 构造方式、TenantId payload 重复、异常吞噬和日志/错误原文暴露样例。
- [ ] G05-0.5 对 Auth token 持久化和 identifier logging 建立独立安全 finding、owner、严重级别和修复/升级路径。
- [ ] G05-0.6 保存当前 build、相关测试、LayerGuard、公共 schema 和敏感字段扫描结果作为基线。

## Phase 1 — 建立最小 Context 与 Envelope 协议原语

- [ ] **Phase 1 完成**：标识和 scope 语义由最小 BCL-only 类型表达，且未形成新的业务 SharedKernel。

- [ ] G05-1.1 确定 context primitives 的物理项目、namespace、owner、版本和 Gate 03 allowlist 条目；禁止依赖 ASP.NET、Security implementation、MediatR、EF、DI、serializer 或 broker。
- [ ] G05-1.2 定义强类型 CorrelationId、OperationId、CausationId/EventId 边界和 canonical serialization；禁止 Guid.Empty 与含糊 string identity。
- [ ] G05-1.3 定义 TenantScope/PlatformScope 判别模型；TenantScope 必须有非空 TenantId，PlatformScope 不伪造 TenantId。
- [ ] G05-1.4 定义最小 ActorReference、SourceReference 和 ContextProvenance；不包含 display name、email、role/permission 列表或 credential。
- [ ] G05-1.5 定义 ContractRequestContext 的 required/optional 字段、V1 identity、未知字段和兼容规则。
- [ ] G05-1.6 定义 Messaging Contracts 中 Event Envelope 的字段、时间类型、版本、content type 和可选 W3C trace carrier。
- [ ] G05-1.7 为 primitives 建立构造/解析、空值、格式、序列化 round-trip 和禁止依赖测试。

## Phase 2 — 重构可信 Execution Context 与生命周期

- [ ] **Phase 2 完成**：Application 可在 HTTP、Worker 和 Event 场景读取一致的不可变 context，且不存在跨 scope 泄漏。

- [ ] G05-2.1 定义 Application-facing execution-context accessor/port，并把 transport-specific 建立逻辑留在外层。
- [ ] G05-2.2 将当前 Auth.Infrastructure `CurrentUser` 的身份事实、tenant membership 与 HTTP accessor 职责拆分，避免 Auth 实现成为所有模块的运行上下文宿主。
- [ ] G05-2.3 由 root composition 注册 context factory/accessor；验证 scoped 生命周期、缺失上下文失败和唯一实现。
- [ ] G05-2.4 为 HTTP、scheduled job、dispatcher、message delivery 和受控管理命令分别定义 Actor/Source/Scope 建立规则。
- [ ] G05-2.5 若使用 AsyncLocal，实现 push/pop/finally 清理和嵌套 scope 恢复；禁止 singleton 保存当前 context。
- [ ] G05-2.6 测试并行 tenant、嵌套 Contract 调用、取消、异常、fire-and-forget 和 scope disposal，证明上下文不串扰。

## Phase 3 — 建立 HTTP Trace、Correlation 与 Tenant 入口

- [ ] **Phase 3 完成**：每个 HTTP 请求在进入 Application 前具有可验证的 trace、correlation、actor 和显式 execution scope。

- [ ] G05-3.1 按 D18 顺序调整 middleware，确保 exception、Activity、correlation、logging、authentication、tenant context、authorization 的建立次序确定。
- [ ] G05-3.2 公共入口生成内部 CorrelationId；验证外部 ClientRequestId，配置受信任网关传播策略，并回传规范化内部 ID。
- [ ] G05-3.3 使用 W3C Activity 传播 trace；非法 `traceparent` 建立新 trace，不将 trace failure 转为业务失败。
- [ ] G05-3.4 解析 `X-Tenant-Id` 的 absent、malformed、duplicate、unauthorized 与 primary fallback；显式错误不得回退。
- [ ] G05-3.5 为 TenantScope 与 PlatformScope 建立 endpoint metadata/policy，禁止以 nullable TenantId 隐式推断权限。
- [ ] G05-3.6 统一 `tenant_context_invalid`、`tenant_access_denied` 等 error code 与安全响应，不返回内部 exception message。
- [ ] G05-3.7 添加 HTTP 集成测试，覆盖匿名/认证、多租户、Global Admin、无效 header、反向代理和 response correlation。

## Phase 4 — 建立同步 Contract Context Conformance

- [ ] **Phase 4 完成**：未来所有进程内或进程外 Contract Adapter 使用同一语义，且 Provider 在信任边界重新验证。

- [ ] G05-4.1 定义 Consumer Adapter 如何从 ExecutionContext 生成新 RequestId、继承 CorrelationId 并设置 CausationId。
- [ ] G05-4.2 定义 Provider Adapter 对 consumer allowlist、context version、scope、actor/source 和 tenant/resource 一致性的验证顺序。
- [ ] G05-4.3 定义 `contract_context_invalid`、`contract_consumer_denied`、tenant mismatch、timeout、cancel 和 unavailable 的稳定结果映射。
- [ ] G05-4.4 建立进程内 conformance Adapter/harness，证明未来 HTTP/gRPC carrier 替换不影响 Consumer Application Port。
- [ ] G05-4.5 验证 ContractRequestContext 不接受 token、ClaimsPrincipal、角色全集或调用方自报的授权结果。
- [ ] G05-4.6 将 conformance suite 交给子计划 1，要求每个实际 Adapter 和 Provider capability 执行相同测试。

## Phase 5 — 建立 Event Envelope 与传播 Conformance

- [ ] **Phase 5 完成**：Event schema 与运行时 carrier 的职责清晰，逻辑 Envelope 在 retry/replay 中保持不变。

- [ ] G05-5.1 实现或生成 Event Envelope V1 schema/golden fixture，并验证 required/optional、canonical name、UTC DateTimeOffset 和 unknown-field 行为。
- [ ] G05-5.2 定义 producer 在本地执行上下文中生成 EventId、OccurredAt、Producer、TenantScope、Correlation/Causation 与 trace snapshot 的规则。
- [ ] G05-5.3 定义 Outbox record 对 immutable Envelope、payload 与 mutable delivery metadata 的物理分离要求。
- [ ] G05-5.4 定义 transport header 映射和 Consumer Adapter 验证；Producer identity 由可信 runtime 注入，不由业务 payload 自报。
- [ ] G05-5.5 定义 Consumer ExecutionContext：OperationId 使用入站 EventId，Correlation 不变，下游事件 CausationId 使用入站 EventId。
- [ ] G05-5.6 建立 fake Outbox/carrier/Inbox conformance harness，验证 retry/replay identity、损坏 trace 恢复与损坏 tenant 拒绝。
- [ ] G05-5.7 将同一 suite 交给子计划 2，在真实数据库 Outbox/Inbox、Dispatcher 和 transport 上重新执行。

## Phase 6 — 建立字段分类、最小化与整改目录

- [ ] **Phase 6 完成**：每个公共字段都有业务目的和准入结论，Secret 与非必要 Restricted 数据被阻断。

- [ ] G05-6.1 向 Gate 03 所有的唯一 catalog/validator 贡献字段分类扩展：classification、purpose、consumer、requiredness、retention、log policy 和 exception reference；不得建立第二份目录或 validator。
- [ ] G05-6.2 对所有现有公共 Reader DTO、目标 Contract DTO、Event Envelope 和 payload 字段逐一完成 C0-C4 分类。
- [ ] G05-6.3 将 `InvestorSummaryDto` 等通用表面拆分为 capability-specific 迁移建议，明确姓名、KYC、税务等字段的真实消费者。
- [ ] G05-6.4 评审并计划移除 Event 中非必要 Name、AccountNumber、Code、自由文本 RejectionReason 和重复 TenantId。
- [ ] G05-6.5 对确需 Amount/Units/NAV/KYC 等 C2/C3 数据的 Event 记录 consumer、投影目的、加密、访问、retention、deletion 和 replay policy。
- [ ] G05-6.6 建立 C4 denylist 与语义规则，覆盖 password、token、authorization、cookie、OTP、API/client secret、private key 和 connection string。
- [ ] G05-6.7 为所有 C3/State Transfer 例外要求 owner、批准人、到期日、补偿控制和撤销条件。

## Phase 7 — 重建日志、Trace、审计与错误安全

- [ ] **Phase 7 完成**：普通运维数据不再成为敏感信息旁路，审计数据有独立治理。

- [ ] G05-7.1 定义集中日志字段 allowlist、C2 keyed-HMAC pseudonym、C3 redact 和 C4 drop 策略；密钥轮换不暴露原值。
- [ ] G05-7.2 清理 username/email/issuer/subject/IP/UserId/TenantId/ResourceId 等现有日志，按运维或审计用途迁移。
- [ ] G05-7.3 禁止日志记录完整 request/response/Contract/Event/exception payload；第三方 SDK exception 经过安全过滤。
- [ ] G05-7.4 建立独立 security/compliance audit sink 的权限、不可篡改、retention、deletion 和查询规则。
- [ ] G05-7.5 限制 span name、tag、baggage、metric label 的敏感值和基数；禁止 SQL 参数与 body 默认采集。
- [ ] G05-7.6 统一外部 ErrorCode/safe message/CorrelationId schema，移除 Argument/KeyNotFound/Result/SDK exception 原文外泄。
- [ ] G05-7.7 解决或正式升级 Auth access/refresh token 持久化 finding；Gate 关闭前不得以普通审计需求批准长期保存 Secret。
- [ ] G05-7.8 使用捕获 sink 和 sentinel 数据测试日志、trace、metric、error response 与诊断 endpoint。

## Phase 8 — 落实失败、Quarantine、Replay 与兼容规则

- [ ] **Phase 8 完成**：所有上下文错误具有稳定分类，不会被无限 retry、静默修补或跨 tenant 继续执行。

- [ ] G05-8.1 实现 D19/D21 失败矩阵，区分 Diagnostic、Client、Business、Transient、Permanent 与 Security。
- [ ] G05-8.2 对 Event type/version/EventId/producer/tenant/correlation/causation 建立 pre-Inbox 验证和 stable reason code。
- [ ] G05-8.3 对 permanent/security message 建立 quarantine/dead-letter metadata、审计和告警；诊断字段仍受分类与脱敏约束。
- [ ] G05-8.4 验证 transient retry 不改变 Envelope；attempt、lease 和 last error 仅改变 delivery state。
- [ ] G05-8.5 定义并测试 dead-letter replay 保留 EventId；已完成 Inbox 继续去重，强制重处理走独立 ReprocessingRequest。
- [ ] G05-8.6 建立 Compatibility Adapter 注册表、owner、来源、允许补充字段、`Synthesized` provenance、指标和强制到期。
- [ ] G05-8.7 采集 context/envelope/tenant/producer/redaction/compatibility 指标；metric labels 不含原始高基数或敏感值。

## Phase 9 — 自动化门禁与测试矩阵

- [ ] **Phase 9 完成**：结构、schema、敏感数据和运行传播由各自适合的自动化机制阻断。

- [ ] G05-9.1 在 Gate 03 的唯一 catalog validator 中实现字段分类完整性、consumer/purpose、exception 引用和降级审批规则；Gate 05 不创建平行 validator。
- [ ] G05-9.2 建立 Contract/Event reflection/schema tests，验证 primitive allowlist、序列化 shape、golden files、未知字段和版本兼容。
- [ ] G05-9.3 建立 security schema tests：未分类字段、C4 字段、未批准 C3、可疑自由文本和 forbidden type/name 失败。
- [ ] G05-9.4 建立 HTTP → Application → Contract harness 的 correlation/operation/causation/tenant/trace 传播测试。
- [ ] G05-9.5 建立 Event producer → fake/real Outbox → transport → Inbox → downstream Event 的传播与错误矩阵测试。
- [ ] G05-9.6 建立 retry、replay、parallel tenant、异常、取消和 scope cleanup 测试，验证 Envelope immutability 与无上下文泄漏。
- [ ] G05-9.7 建立敏感 sentinel 测试，捕获日志、trace、metrics、errors、dead-letter diagnostics，证明禁止值不存在。
- [ ] G05-9.8 将依赖/框架泄漏规则交给 LayerGuard，将字段和值语义留在 catalog/schema/runtime tests；两类 CI 报告相互链接。
- [ ] G05-9.9 提供本地与 CI 相同的单一验证入口并保存基线；扫描异常、未知 schema 或过期 exception 必须失败。

## Phase 10 — 架构与规则文档化

- [ ] **Phase 10 完成**：所有设计、规则、图、目录与测试证据均可独立审阅，中文和英文含义一致。

- [ ] G05-10.1 创建中文设计文档 `docs/architecture/review/gates/G05/context-sensitive-data-boundary.zh-CN.md`。
- [ ] G05-10.2 创建对应英文文档 `docs/architecture/review/gates/G05/context-sensitive-data-boundary.en.md`，保持决策编号和术语一致。
- [ ] G05-10.3 创建 Correlation/Operation/Causation/Event/Trace/Tenant 术语表、生命周期表和禁止替代表。
- [ ] G05-10.4 创建当前/目标上下文架构图，以及 HTTP、Contract、Outbox/transport/Inbox、downstream event 的流程图。
- [ ] G05-10.5 创建 trust boundary、tenant selection、context rejection、retry/dead-letter/replay 状态图与失败矩阵。
- [ ] G05-10.6 创建 C0-C4 分类、Contract/Event/日志/trace/审计准入矩阵和字段级 catalog。
- [ ] G05-10.7 创建日志脱敏、错误响应、Compatibility Adapter 和安全 finding 的操作/整改说明。
- [ ] G05-10.8 Mermaid 源文件与可直接查看的 SVG/PNG 一并保存，并完成渲染检查。
- [ ] G05-10.9 将每条规则映射到 owner、代码位置、Catalog validator、LayerGuard、schema/security/integration test、指标或人工审批。
- [ ] G05-10.10 更新架构索引、前置/总计划和三个原子计划的双向链接，完成中英文一致性与安全评审。

## Phase 11 — Gate 关闭与子计划交接

- [ ] **Phase 11 完成**：OPS1、OPS3、OPS-G1 均有实现、测试和文档证据，后续计划没有未声明语义。

- [ ] G05-11.1 向子计划 1 交付 ContractRequestContext、ExecutionContext、tenant/consumer validation、字段最小化和 Contract conformance suite。
- [ ] G05-11.2 向子计划 2 交付 Event Envelope、Outbox snapshot、transport carrier、Inbox context、retry/replay 和 Event conformance suite。
- [ ] G05-11.3 向子计划 3 交付 context primitive allowlist、Contracts forbidden dependency/type 和 Adapter declaration rules；确认敏感字段语义不错误塞入 LayerGuard。
- [ ] G05-11.4 向 Gate 04 交付 Worker scope、shutdown cleanup、telemetry flush、quarantine/backlog 和无敏感 health details 规则。
- [ ] G05-11.5 对照 OPS1、OPS3、OPS-G1 附上代码、目录、schema、测试、指标和中英文图文证据。
- [ ] G05-11.6 仅在全部交付完成后更新 [`00-prerequisites.md`](00-prerequisites.md) 的 Gate 5 checkbox。
- [ ] G05-11.7 记录所有未关闭 exception/security finding 的 owner、风险、到期日和阻断范围；C4 暴露不允许豁免关闭。
- [ ] G05-11.8 由架构、模块、Platform、安全和运维负责人共同批准 Gate 关闭。

## Definition of Done

- [ ] G05-DD01 Correlation、Operation、Causation、Event、Trace 与 Tenant 语义唯一且由强类型/测试保护。
- [ ] G05-DD02 HTTP、job、同步 Contract 和 Event consumer 都能建立独立可信 ExecutionContext，异常和并发下无泄漏。
- [ ] G05-DD03 TenantScope/PlatformScope 显式，非法、缺失、冲突和未授权 tenant 全部 fail closed 且有稳定 reason code。
- [ ] G05-DD04 ContractRequestContext 与 Event Envelope 为 BCL-only、transport-neutral、可版本化，并通过 golden/conformance tests。
- [ ] G05-DD05 Event retry/replay 保持逻辑 Envelope，不用新 EventId 绕过幂等；compatibility synthesis 显式且会到期。
- [ ] G05-DD06 所有公共 Contract/Event 字段完成 C0-C4 分类、purpose 和 consumer 登记；C4 零暴露，C3 仅有批准例外。
- [ ] G05-DD07 运维日志、trace、metric、错误响应和 health details 不泄漏禁止数据；审计 sink 独立受控。
- [ ] G05-DD08 Catalog、schema/security/integration tests 与 LayerGuard 分工明确并进入 CI，扫描异常和过期例外不能静默通过。
- [ ] G05-DD09 Auth token 持久化 finding 已修复或升级为阻断性安全计划；不得以未到期豁免关闭 C4 风险。
- [ ] G05-DD10 中英文设计说明、架构图、流程图、状态图、字段目录、失败矩阵和规则验证映射全部完成并审核。

## 回退与安全原则

- [ ] G05-R01 新 context middleware 可按入口逐步启用，但旧路径不得在显式无效 TenantId 时继续静默回退。
- [ ] G05-R02 schema 切换失败时可保留有期限 Compatibility Adapter，不得恢复 Dispatcher 全局补值或省略 tenant 验证。
- [ ] G05-R03 日志整改不得通过关闭所有错误观测掩盖问题；保留安全 ErrorCode、CorrelationId、异常类型和受控 stack trace。
- [ ] G05-R04 pseudonym key 轮换必须保留审计、环境隔离和过渡查询方案，不回退到原始标识日志。
- [ ] G05-R05 C3 State Transfer Event 出现风险时优先停止新生产、保留受控消费/清理路径，并切回通知 + 授权 Contract。
- [ ] G05-R06 任何回退、replay、强制重处理或例外都必须记录 actor、原因、范围、到期日和恢复验证。
