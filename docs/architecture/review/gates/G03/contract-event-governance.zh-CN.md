# G03 Contract / Event 治理基线

> 状态：PRE-READY，尚未关闭；Plan 01/B2 与 Plan 02/B3 的四个协议已为 `Active`，
> 两个后续同步协议仍为 `Proposed`，最终多人批准保持开放。本文解释权威目录；
> 当前事实以 [`contract-event-catalog.yaml`](contract-event-catalog.yaml) 为准。

## 边界与职责

| 角色 | 拥有什么 | 不拥有什么 |
| --- | --- | --- |
| Provider Contract | 提供方命名的最小业务能力、输入/输出语义、稳定 identity | 消费方用例、数据访问、传输或 DI |
| Consumer Port | 消费方 Application 所需的业务形状与失败语义 | 提供方模型或传输细节 |
| Integration Adapter | 在消费方外层把 Port 转换为提供方 Contract，或把 Event Envelope 转为入站命令 | 业务决策 |
| Event owner | 已提交业务事实、schema、发生时点、版本和生产责任 | 消费方投影或跨模块 ACID |
| Application | 提供方实现能力；消费方编排自己的用例与 Port | foreign Contracts 直接依赖、broker/serializer SDK |
| Composition | 在模块边界装配实现、Port 和 Adapter | 业务逻辑或新的公共协议 |

同步依赖方向是 `Consumer.Application -> Consumer.Port <- Consumer.Adapter -> Provider.Contract`；
提供方 Application 实现 Contract。异步方向是 producer-owned schema 经 Outbox/transport 到
consumer-owned inbound Adapter/Inbox。总体图同时标出同步、异步和 mixed workflow：
[SVG](diagrams/provider-consumer.svg) · [PNG](diagrams/provider-consumer.png) ·
[Mermaid](diagrams/provider-consumer.mmd)。

## 当前公共表面与目标

2026-09-08 的迁移基线共有 46 个 legacy public items：4 个 Reader、15 个 Reader method、
7 个 DTO 和 20 个 Integration Event，处置为 20 个 `Internalize`、6 个 `Replace`、
20 个 `Remove`。当前 catalog 中 46 项均为 `Retired`；2026-12-01 是原迁移期限，
不是仍在等待的项目数。`HoldingFrozenEvent` 没有 producer 或 consumer，未提升为协议。

<!-- G03-CURRENT-PROTOCOLS-START -->
| 目标 identity | 模式 | Provider -> Consumer | 当前状态 | 下游 owner |
| --- | --- | --- | --- | --- |
| `crm.account-compliance.v1` | sync | CRM -> Transaction | Active | Plan 01/B2 |
| `registry.class-subscription-availability.v1` | sync | Registry -> Transaction | Active | Plan 01/B2 |
| `ifx.transaction.transaction-processed.v1` | event | Transaction -> Holdings | Active | Plan 02/B3 |
| `ifx.registry.class-status-changed.v1` | event | Registry -> Holdings | Active | Plan 02/B3 |
| `auth.resource-authorization.v1` | sync | Auth -> CRM, Registry, Transaction, Holdings | Proposed | IAM/Authorization |
| `authorization.policy-evaluation.v1` | sync | Authorization -> IAM | Proposed | IAM/Authorization |
<!-- G03-CURRENT-PROTOCOLS-END -->

任何 identity 只有在真实 `Contracts.V1` 源码、public API/serialization snapshot、provider 与
consumer 行为测试、catalog reconciliation 和审批同时存在后才能变为 Active。

### 模块能力与数据 ownership

| 模块 | owned capabilities | owned data facts |
| --- | --- | --- |
| Auth | identity、authentication、subject/external mapping | identity subjects、credentials、external identity mappings |
| CRM | party、investor、investment-account、account-compliance | party、investor、investment account、KYC/compliance |
| Registry | product、fund、fund-class、subscription availability | product、fund、fund class、subscription status |
| Transaction | order、transaction-processing | order instruction、transaction lifecycle |
| Holdings | position、holding-freeze | holding、position、freeze state |
| Platform Messaging | schema primitives、runtime delivery | envelope semantics、delivery attempt state |

共享物理数据库或进程不改变该 ownership；consumer 不得绕过 provider Application 读取 foreign
schema。`IFX.Platform.Messaging.Contracts` 只承载 BCL-only schema primitive；
runtime bus、handler、serializer、dispatcher、broker 和 DI 属于
`IFX.Platform.Messaging.Runtime`。Contracts 与 Runtime 项目均已物理创建，准入和依赖边界仍由门禁判定。详细 allowlist 见
[`shared-contract-primitives.md`](shared-contract-primitives.md)。

## 生命周期与迁移

正常协议按 `Proposed -> Active -> Deprecated -> Retired` 前进，Retired identity 永久保留；
legacy surface 则必须在 deadline 前 Internalize、Replace 或 Remove。状态与迁移图：
[SVG](diagrams/lifecycle-migration.svg) · [PNG](diagrams/lifecycle-migration.png) ·
[Mermaid](diagrams/lifecycle-migration.mmd)。

外部 consumer 必须登记 owner、evidence 和 `lastConfirmedAt`，至少每 90 天复核。过期复核会告警
并阻止退役，但不会静默删除 consumer。退役还要求全部 consumer 已迁移、至少两个成功生产发布、
至少 30 天、旧版本零流量且无旧 schema backlog/dead-letter/replay liability。

## 兼容决策与 V1/V2

判定流程：[SVG](diagrams/compatibility-decision.svg) ·
[PNG](diagrams/compatibility-decision.png) · [Mermaid](diagrams/compatibility-decision.mmd)。

- Compatible：带 C# construction default 的 optional 字段、带已测试 fallback 的 enum value、
  无语义变化的文档澄清。
- Conditional：在已声明范围内收紧 validation/freshness/timeout，或 fallback 证据尚需确认的
  optional 字段。
- Breaking：删除/改名、改变类型或含义、optional 变 required、接口签名或稳定 error code 变化，
  以及 event fact/发生时点变化。
- Internal：公共 schema 与可观察协议之外的实现变化。

Breaking change 必须并行发布 V+1，consumer 在自己的 Adapter 切换，观察两版后再按退役条件关闭
旧版；不得原地改写 Active identity。时序图：[SVG](diagrams/v1-v2-migration.svg) ·
[PNG](diagrams/v1-v2-migration.png) · [Mermaid](diagrams/v1-v2-migration.mmd)。回滚保留 V1 和
Adapter switch point，也不遗弃已生成的 V2 message。

## 变更、审批与示例

审批流程：[SVG](diagrams/change-approval.svg) · [PNG](diagrams/change-approval.png) ·
[Mermaid](diagrams/change-approval.mmd)。Change Record 使用
[`contract-change-record.md`](templates/contract-change-record.md)，Breaking 迁移使用
[`breaking-version-migration.md`](templates/breaking-version-migration.md)。

最小 catalog 例（字段仅示意，完整 schema 由 catalog schema 校验）：

```json
{
  "identity": "crm.account-compliance.v1",
  "kind": "sync",
  "lifecycle": "Proposed",
  "provider": "crm",
  "owner": "xiaolong-feng",
  "consumers": ["transaction-application"]
}
```

Change Record 必须登记 classification、provider owner、affected consumers、兼容证据、发布顺序、
回滚和状态。waiver 必须有 rule、owner、reason、mitigation、createdAt、expiresAt 与 milestone；到期是
创建后 90 天与 milestone 两者较早者。missing owner/consumer、internal model、C4、未经批准 C3、
identity reuse 不可豁免。C3 State Transfer 是受控准入而不是 waiver。

外部 consumer 示例：`kind=external-service`，提供联系 owner、可审计 evidence、90 天内
`lastConfirmedAt`；不可因联系失败而删除记录。shared primitive 申请必须证明三个以上模块语义相同
或 uniform infrastructure protocol 必需，并给出 owner、canonical serialization、兼容政策和
所有 affected modules 的审批。

## 规则到证据映射

| 规则 | Catalog validator | Snapshot / contract test | LayerGuard | CI | 人工审批 |
| --- | --- | --- | --- | --- | --- |
| identity、owner、consumer、lifecycle 唯一且完整 | 是 | Active 准入测试 | ownership graph | G03 guard | Provider + Consumer |
| 字段 purpose、C0-C4、C4 禁止 | 是 | golden serialization | schema dependency | G03 guard | C3/敏感字段复核 |
| BCL-only 与 shared primitive allowlist | 是 | public API snapshot | framework/leak rules | handoff drift | Platform + Architecture |
| Compatible/Conditional/Breaking 分类 | Change Record 对账 | API/schema diff + behavior | 声明/依赖补充 | snapshot drift | 分类对应 reviewer set |
| V+1、Deprecated、Retired 条件 | lifecycle 校验 | 双版 consumer/provider 测试 | identity 不复用 | source reconciliation | 全部 consumer + Architecture |
| waiver 到期与不可豁免项 | 是 | negative self-tests | generated waiver input | 阻断 | owner + rule approver |
| external consumer 90 天复核 | 是 | 使用/流量证据 | dependency graph（仓内） | stale alert/block retire | 外部 owner + Provider |

自动化入口是 `docs/guards/V3_ifx/commands/Invoke-IFXGuardrails.ps1 -Mode Specialized -SpecializedGate G03`；Phase 8 还验证双语 identity 一致、链接、
Mermaid/SVG/PNG triplet 和 PNG signature。Plan 03 L5.1 已回交 LayerGuard 直接消费；
前四个协议已由 Plans 01/02 回交 Active 证据，两个后续同步协议与 G03-6.5/6.6
结项仍待完成。backup owner 已于 2026-09-08 指定；本 Gate 在剩余技术条件和最终批准满足前保持 PRE-READY。
