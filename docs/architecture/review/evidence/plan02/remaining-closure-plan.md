# Plan 02 剩余关闭计划

日期：2026-09-09

状态：**B3 仓库检查点已完成；完整 Plan 02 等待增强项、production-like 演练和最终批准**

本文是 [`02-reliable-integration-events.md`](../../plans/02-reliable-integration-events.md)
所有未勾选项目的统一执行说明。它不替代主计划，也不把仓库测试等同于生产验收。
每一项只有在下述关闭证据可审计后，才允许更新对应 checklist。

## 1. 当前完成边界

已完成的 B3 仓库范围包括：

- provider-owned V1 Integration Event schema；
- producer-local Transactional Outbox 和 module-owned migration；
- Worker Dispatcher、claim/lease、retry、dead-letter、replay 和 backpressure 接缝；
- Holdings Inbound Adapter、Inbox、quarantine 和消费方本地事务；
- G01/G02/G03/G04/G05 仓库证据回交；
- solution 1,085 tests、LayerGuard 189 tests，以及 B4 0 finding / 0 waiver。

未完成的不是 B3 核心实现，而是完整 Plan 02 的真实 transport、目标平台数据控制、
告警校准、production-like 故障/发布演练和负责人签字。P02-C1 已关闭 Phase 4；Phase 5–8 及完整 Plan 02
仍不得标记完成。

## 2. 未勾选项总表

| 项目 | 当前状态 | 关闭所需结果 | 主要责任方 |
| --- | --- | --- | --- |
| E4.9 | **已关闭（P02-C1，2026-09-09）** | 生产 raw receiver 已验证非法 carrier、quarantine disposition、新 root span、身份保持和 handler 前置顺序 | Platform Messaging、Holdings、Security/G05 conformance |
| E5.7 | **P02-C2 仓库基线通过；目标证据待补** | 已有 fail-closed 策略/模板/验证器；仍需真实最小权限、传输/静态加密、保留/删除、legal hold、C3 负面测试和四方批准 | Security、Database、Platform Operations、Legal/data owner |
| E6.5 | 指标、readiness 和版本化阈值已完成；生产校准未完成 | exporter/dashboard、阈值、告警路由、silent-stop 触发和恢复证据 | Observability、Platform Operations、Messaging |
| E6.7 | immutable replay 和 Inbox 去重已完成；forced reprocessing 未决 | 正式决定“不支持”，或实现独立且受审计的 `ReprocessingRequest` | Product、Architecture、Operations、模块 owner |
| E7.3 | 组件与 SQL 测试已完成 | 源提交到消费方状态变化的真实 transport E2E，覆盖重复和短暂故障 | Test Engineering、生产/消费模块、Messaging |
| E7.4 | 仓库 crash-window/reference fixture 已完成 | 进程、网络、SQL、timeout、partial batch、takeover 和恢复演练 | Test Engineering、Operations、Database、Messaging |
| E7.5 | consumer-first DAG 和证据模板已完成 | production-like Migrator → Worker → API → scheduler → observation → cleanup 记录 | Release Operations、Database、Platform、模块 owner |
| E7.6 | 旧直发代码已基本删除 | 观测窗口证明指标达标、零旧版本需求和唯一权威路径后完成 cleanup | Architecture、模块 owner、Operations |
| E7.8 | context/sentinel 组件测试已完成 | 完整 HTTP → Outbox → transport → Inbox → downstream、租户隔离和敏感数据套件 | Security、Platform、Test Engineering、模块 owner |
| E8.9 | G01 仓库回交已接受 | 生产/演练链接及 Architecture/Application/Infrastructure 三方签字 | G01 approvers |
| E8.10 | G02 仓库回交已接受 | G04 发布回交、G02-DD06 关闭及 Architecture/Database/Operations 三方签字 | G02 approvers、Release Operations |

## 3. 各项处理方法与验收证据

### 3.1 E4.9：真实 Inbound Adapter 与非法 trace

P02-C1 已将 typed in-process transport 改为经过 transport-neutral raw carrier receiver，能够在
生产边界安全处理错误的 `traceparent`/`tracestate`。

处理步骤：

1. `IntegrationEventTransportCodec` 把冻结 Envelope 映射为 raw headers/payload。
2. `RawIntegrationEventReceiver` 在 handler 前验证 core business context。
3. 非法业务上下文返回稳定 quarantine disposition，handler 不执行。
4. 非法 trace 被丢弃并创建新 consumer root span；Correlation/Causation/Tenant/EventId 保持。
5. 当前 in-process sender 已使用该边界；未来 broker Adapter 复用同一 receiver port。
6. 证据见 [`P02-C1-inbound-conformance.md`](P02-C1-inbound-conformance.md)，E4.9 与 Phase 4 已勾选。

### 3.2 E5.7：数据访问、加密、保留与删除

仓库侧已完成 [`P02-C2 target messaging data controls`](P02-C2-data-controls.md)：七类存储、
五种工作负载能力、加密/密钥、生命周期、tenant deletion/legal hold 和默认拒绝的 C3
State Transfer 均有机器可验证策略与目标证据模板。严格验证当前按设计失败，因为尚未提供真实
production-candidate 环境证据；因此 E5.7 与 Phase 5 保持未勾选。

处理步骤：

1. 对 Outbox、Inbox、broker、dead-letter、quarantine、replay 审计和诊断存储计算最高字段分类。
2. 为 producer、Dispatcher、consumer、diagnostics 和 replay 分配最小权限，禁止共享高权限身份成为最终生产配置。
3. 配置传输中加密、静态加密、密钥轮换和访问审计。
4. 定义 pending、delivered、dead-letter、quarantine、replay audit 的保留、归档和删除周期。
5. 明确租户删除、法定保留、legal hold 和 reconciliation 之间的优先级。
6. 如允许 C3 State Transfer，登记 owner、目的、字段、批准、到期日和删除条件；否则保持 fail closed。
7. 保存 IaC/config 快照、权限负面测试、删除/保留演练和批准引用后勾选 E5.7 与 Phase 5。

### 3.3 E6.5：生产指标与告警校准

处理步骤：

1. 将仓库 BCL `Meter` 接入目标 OpenTelemetry exporter 和指标后端。
2. 建立按 module/event category 展开的 backlog age、retry、dead-letter、lease、last-success 和吞吐 dashboard。
3. 在目标副本数、总并发和接近真实的流量下测量正常基线。
4. 校准 warning/critical、连续失败、silent dispatcher 和 backpressure 阈值，并记录 owner。
5. 注入 transport/SQL/consumer 故障，证明告警能触发、路由、确认并链接正确 runbook。
6. 恢复后证明指标和告警自动回到健康状态，保存图表和告警事件引用。

### 3.4 E6.7：强制重处理决策

普通 replay 已固定原 EventId/Envelope，不能通过换 ID 绕过 Inbox 去重。必须在以下两种方案中
作出正式选择：

- **不支持 forced reprocessing**：记录 Architecture/Product 决定，保持 execute capability 关闭，
  明确只支持 immutable replay 与 reconciliation，并将该项按批准的 N/A 关闭。
- **支持独立 `ReprocessingRequest`**：使用独立 request identity，引用 OriginalEventId、ConsumerId、
  原因、工单、请求人/批准人、目标 handler version、dry-run、幂等键和完整审计；不得修改原消息，
  且必须单独处理下游非幂等副作用。

无正式决定和验收测试时，E6.7 与 Phase 6 保持未勾选。

### 3.5 E7.3/E7.4/E7.8：全链路和故障验证

E7.3 的成功条件是完整链路
`源请求/命令 → 本地业务+Outbox commit → Dispatcher → transport → Inbound Adapter → Inbox+消费方状态`
最终完成，并证明重复投递和短暂故障不会产生重复业务效果。

E7.4 至少注入：发送前终止、发送后 ack 前终止、完成后终止、SQL/transport 中断、handler timeout、
partial batch、Worker forced kill、lease expiry/takeover、poison/quarantine 和重启恢复。验证不得丢失
已提交事件、不得伪造 delivered、不得删除 pending truth，重复必须由 Inbox 吸收。

E7.8 在同一套环境运行 G05 conformance：HTTP/producer 到 downstream Event 的 context 传播、
retry/replay identity、并行租户隔离，以及日志、trace、error、health、dead-letter、quarantine 的
C0–C4 sentinel。三项报告都完成后，才能进入发布关闭。

### 3.6 E7.5/E7.6：consumer-first 发布与旧路径关闭

使用 `deployment/g04/release-evidence-template.json` 创建 release-specific 不可变证据，严格执行：

1. database preflight；
2. verified restore point；
3. DatabaseMigrator；
4. schema validation；
5. 兼容旧/新 schema 的 Worker consumers，并确认全部 Ready；
6. API producers；
7. 唯一 scheduler authority；
8. observation window；
9. 仅在 zero old-version demand 后进行 contract cleanup。

演练同时覆盖 rolling rollout、SIGTERM drain、forced termination、backpressure、网络策略、总容量、
安全回退和 roll-forward。只有当 observation 证明 backlog/retry/dead-letter 稳定、无旧 consumer/API/schema
需求且唯一权威路径成立，才可勾选 E7.5、E7.6 和 Phase 7。

### 3.7 E8.9/E8.10：跨 Gate 回交和签字

G01 已接受 E2/E4 的仓库级事务证据；剩余工作是链接最终演练证据，并取得 Architecture、Application、
Infrastructure 三方具名、带日期批准。完成后更新 G01-9.6、G01 Phase 9、E8.9。

G02 已接受 module-owned Outbox/Inbox、migration 和 SQL Server matrix；剩余工作是回交 production-like
Migrator → Worker → API 证据、关闭 G02-DD06，并取得 Architecture、Database、Operations 三方批准。
完成后更新 G02 Phase 10、E8.10。

## 4. Definition of Done 依赖关系

| DoD | 关闭依赖 |
| --- | --- |
| E-D06 | E6.5、E7.3、E7.4、E7.5 的故障、积压和告警证据 |
| E-D08 | E5.7 与 E7.8 的目标平台数据保护和敏感信息证据 |
| E-D10 | E8.9 的 G01 回交和三方签字 |
| E-D11 | E8.10 的 G02 发布回交和三方签字 |

关闭顺序必须是：明细项 → 对应 Phase completion → E-D06/E-D08/E-D10/E-D11 → Plan 02 最终状态。

## 5. 分步关闭顺序

后续工作按以下六个可独立审计的切片推进，每次只关闭一个切片：

1. **[x] P02-C1 / Adapter conformance**：raw carrier seam、E4.9 和 Phase 4 已于 2026-09-09 完成。
2. **[进行中] P02-C2 / Data controls**：仓库控制契约已完成；填充真实目标证据并通过 strict validator 后关闭 E5.7/Phase 5。
3. **P02-C3 / Operations decisions**：完成 E6.5 校准，并对 E6.7 作出正式决定/实现。
4. **P02-C4 / Full-path validation**：完成 E7.3、E7.4、E7.8。
5. **P02-C5 / Release rehearsal**：完成 E7.5、E7.6、G04-B03/B06 和 observation/cleanup。
6. **P02-C6 / Gate approvals**：完成 E8.9、E8.10、E-D06/E-D08/E-D10/E-D11 及最终签字。

每个切片完成时必须同时：保存机器可读报告、链接不可变外部证据、更新主 checklist、运行相关 guard，
并以独立提交记录。不得预先勾选后续切片。

## 6. 最终验证

完成 production-like release record 后运行：

```powershell
./scripts/Test-G04ReleaseOrchestration.ps1 `
  -EvidencePath <immutable-release-evidence.json> `
  -ReportPath <immutable-validation-report.json> `
  -RequireCompleted

./scripts/Invoke-LayerGuard.ps1
./scripts/Test-Plan03B4StrictClosure.ps1
./scripts/Test-G04Closeout.ps1
```

`-RequireCompleted` 必须拒绝 placeholder、无效 hash、缺失或无日期的批准、未完成阶段、无效证据引用、
无效时间戳和非单调执行顺序。完整跨 Gate 状态继续由
[`final-closure/README.md`](../final-closure/README.md) 跟踪。
