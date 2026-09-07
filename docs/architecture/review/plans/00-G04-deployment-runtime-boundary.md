# Plan 00 / Gate 04：部署与运行边界实施计划

> 状态：Architecture Decisions Approved / 待实施
> 上级前置计划：[`00-prerequisites.md`](00-prerequisites.md)
> 上级总计划：[`00-master-plan.md`](00-master-plan.md)
> 工具前置：[`03-layerguard-alignment.md`](03-layerguard-alignment.md) 03-A0 已完成；本 Gate 产出的 Composition/API/Worker Runtime Role matrix 在 03-A1 绑定。
> 上下文与数据规则：[`00-G05-context-sensitive-data-boundary.md`](00-G05-context-sensitive-data-boundary.md) 定义 Worker/job/message scope、telemetry、quarantine 与 health/details 脱敏要求。
> 范围：DP1、DP3、DP4、DP5，以及业务发布边界、Runtime Role、多实例后台处理、部署编排、健康探针和优雅关闭规则
> 前置放行：完成 Runtime Role/manifest/lease/health/backpressure 协议及 reference conformance；真实 Dispatcher、消息 backlog 和 Event replay 由 E3/E6 实现并回交最终证据
> Gate 关闭条件：本计划全部 Phase、Definition of Done 和文档交付均已完成

## 目标

把 IFX 当前的部署现实和目标运行模型变成显式、可验证的架构：Auth、CRM、Registry、Transaction、Holdings 仍共同组成一个后端业务发布边界；Frontend、SQL Server、OPA、Migrator 和外部服务保持独立部署生命周期；同一 IFX release 可以用 `api`、`worker` 和本地 `all` 三种 Runtime Role 运行；多实例 Dispatcher 使用数据库 lease 安全竞争；启动、readiness、drain、回退和消息积压都有确定语义。

本 Gate 不把 Worker role 解释为业务微服务，也不允许通过不同 ApiHost 副本加载不同业务模块来模拟独立部署。API 与 Worker 继续使用同一业务版本、module manifest、Contract/Event catalog 和兼容数据库 schema。

## 非目标

- [ ] G04-N01 不在本 Gate 把五个业务模块拆成独立服务或允许独立业务版本。
- [ ] G04-N02 不在本 Gate 选择最终消息 broker，或重复实现 Event 子计划负责的 Outbox/Inbox/Dispatcher/transport 业务功能。
- [ ] G04-N03 不在本 Gate 建立跨模块共享 Dispatcher DbContext、共享消息事务或全局业务 Worker。
- [ ] G04-N04 不把独立 SQL、OPA、Frontend、Migrator 或托管服务的存在当成“已经微服务化”的证据。
- [ ] G04-N05 不用 readiness 探针执行 migration、seed、修复数据或触发业务副作用。
- [ ] G04-N06 不在未完成压测和 SLO 评审前硬编码生产 backlog、lease 或 shutdown 数值。

## 当前实现基线

| 事实 | 当前证据 | 风险 |
| --- | --- | --- |
| 五个业务模块共同加载 | `Program.cs` 显式调用五个 `Add*Module` | 业务模块锁步发布，但尚未正式定义发布边界 |
| Platform libraries 嵌入 ApiHost | Messaging、BackgroundJobs、Notifications 由同一 Host 注册 | 项目名为 Platform 不等于可独立部署 |
| Hangfire Server 随每个 ApiHost 启动 | `AddBackgroundJobs` 无 client/server role 区分 | 扩展 HTTP 副本会隐式扩大后台并发 |
| Hangfire server name 可固定重复 | Compose 默认 `auth-api-worker` | 多副本身份、诊断和接管语义模糊 |
| 消息总线仅为 scoped in-memory 调用 | 顺序调用 handler，并记录后吞掉异常 | 不是可靠 transport，也没有跨实例状态 |
| migration 位于 ApiHost startup | Host build 后枚举全部 `IAppMigrator` | 多实例 DDL 竞争、启动时间和权限耦合 |
| endpoint mapping 依赖 installer 枚举 | 注册顺序同时决定映射顺序 | 缺少显式 module/release manifest 和冲突验证 |
| `/health` 与 `/health/ready` 等价 | 两者 predicate 都选择全部检查 | liveness、startup、readiness 语义混合 |
| 健康范围不完整 | 只检查 Auth DB 与 Cognito | 不覆盖模块 schema、OPA、Hangfire、Dispatcher 或 backlog |
| Compose 顺序不完整 | API 等待 SQL healthy 与 OPA started，不等待 init | schema/init 未完成时 Host 可能启动 |
| 无显式 drain 与 shutdown budget | 未发现 HostOptions/Compose grace 配置 | rolling deploy 中可能中断请求、消息或 lease |

## 已确认架构决策

### 业务部署边界与启动语义

- [x] G04-D01 Auth、CRM、Registry、Transaction、Holdings 共同构成一个 ApiHost 后端业务部署边界；Frontend、数据库、OPA、Migrator 和独立基础设施不包含在该边界中。
- [x] G04-D02 所有 ApiHost 副本加载相同业务模块和 endpoint；独立 Platform/Infrastructure deployment 不受副本同构规则限制。
- [x] G04-D03 五个业务模块均为 required module；不支持动态装卸、整模块 feature flag 或副本间模块差异。
- [x] G04-D04 无效配置、DI、manifest、Contract resolution 和 endpoint 冲突为 startup-fatal；暂时数据库/外部依赖故障保持进程存活并进入 NotReady/Degraded。
- [x] G04-D05 当前不支持模糊的部分模块启动：required module 不可用使 Host NotReady；optional/capability dependency 按批准策略降级。
- [x] G04-D06 建立 Module Manifest，描述 ModuleId/version、requiredness、Contract、endpoint、schema、配置、后台能力和 shutdown requirement。
- [x] G04-D07 启动采用确定阶段：静态配置与 manifest → platform → 模块拓扑注册 → DI 验证 → endpoint/health → Alive/NotReady → schema/dependency 检查 → worker enable → Ready。
- [x] G04-D08 Composition 注册和 endpoint mapping 不执行 migration、seed、网络调用、Dispatcher 启动或其他外部副作用。
- [x] G04-D09 ApiHost 内业务模块与嵌入式 Platform library 锁步发布；独立基础设施可独立升级，但必须遵守 release compatibility matrix。
- [x] G04-D10 建立 Deployment Unit Catalog，记录 artifact、进程类型、owner、版本、配置、依赖、扩容、readiness 和 shutdown 语义。

### Runtime Role、多实例与关闭

- [x] G04-D11 同一 IFX release 支持 `api`、`worker`、`all`；生产推荐 API/Worker 分离，`all` 仅用于本地、测试和过渡期。
- [x] G04-D12 Worker 加载必要业务 Application/Infrastructure/Contracts/Composition，但不映射业务 HTTP；运行角色不改变模块 ownership 或业务边界。
- [x] G04-D13 Hangfire client/server、Outbox Dispatcher 和 message consumer 分别显式启停；非法或空 Worker 配置启动失败。
- [x] G04-D14 Platform 提供 Dispatcher 框架，每个模块仍拥有自己的 Outbox schema、migration、事件映射、retention 和 backlog 指标。
- [x] G04-D15 Dispatcher 采用短事务原子 claim、唯一 LeaseOwner/LeaseUntil/concurrency token、事务外发送和 lease expiry 接管；发送期间不持有数据库事务。
- [x] G04-D16 每次进程启动生成唯一 runtime instance identity，用于 lease、Hangfire、日志、指标、trace 与 drain。
- [x] G04-D17 明确采用 at-least-once；EventId 在重试/接管时不变，Consumer Inbox 与业务幂等容忍“发送成功但未标记”窗口。
- [x] G04-D18 不提供全局事件顺序；只对显式业务分区保证必要顺序，其他分区可并行且毒消息不得阻塞整个模块。
- [x] G04-D19 Hangfire 使用唯一 server identity、按副本计算总 WorkerCount、声明 queue ownership、分离 client/server，并由单一 authority 幂等注册 recurring definitions。
- [x] G04-D20 未处理的关键 worker-loop 退出使其进程 NotReady 并非零终止；transient operation failure 进入 retry，不允许 worker 静默消失但保持绿色。
- [x] G04-D21 优雅关闭依次执行 NotReady → 停止新流量/调度/claim → drain in-flight → 保留可恢复 lease → flush telemetry → exit。
- [x] G04-D22 operation timeout < handler timeout < lease duration < process grace < orchestrator kill timeout；具体值通过测试、SLO 与平台配置确定。

### 部署、健康与回退

- [x] G04-D23 生产顺序为 immutable release → DB preflight/restore point → Migrator expand/validate → Worker consumers → Worker Ready → API producers rolling deploy → schedules → observe → contract cleanup。
- [x] G04-D24 Event 变化采用 consumer-first：Worker 先支持 V1+V2，所有 Worker 升级后 API 才生产 V2；旧 backlog/replay 清理前不移除 V1。
- [x] G04-D25 migration/reference seed、受控 system seed、demo seed、recurring registration 和业务 backfill 使用不同执行主体；不得作为每个 ApiHost 的隐式 startup 动作。
- [x] G04-D26 ApiHost/Worker 生命周期为 Starting → Alive/NotReady → Ready/Degraded/NotReady → Stopping → Terminated，并记录 reason、时间和组件。
- [x] G04-D27 提供 `/health/live`、`/health/startup`、`/health/ready` 和受保护的 `/health/details`；外部依赖不进入 liveness。
- [x] G04-D28 API readiness 验证业务装配/schema/请求安全性；Worker readiness 验证 storage、loop、claim、transport 和 backlog，按 Runtime Role 分开计算。
- [x] G04-D29 依赖分为 startup-fatal、readiness-critical、capability-critical、optional、operational；Cognito 默认 capability，SendGrid 默认 optional，OPA 按实际授权覆盖范围确认。
- [x] G04-D30 每个模块注册无副作用、有 timeout/freshness 的 Health Contributor，由 Runtime Host 聚合。
- [x] G04-D31 消息健康以 oldest backlog age 为主，并结合 pending/retry/dead-letter、last success、latency、lease 和 duplicate 指标；critical 时对生产命令施加 backpressure。
- [x] G04-D32 migration、Worker、API、transport、lease、backlog、schedule 与 shutdown 各失败点均有停止/接管/回退规则；应用回退不自动执行 database Down。
- [x] G04-D33 所有外部检查记录 lastCheckedAt、lastSucceededAt、duration、status、reasonCode，并使用 timeout、jitter、缓存和并发合并。
- [x] G04-D34 普通探针不泄漏 secret/payload/内部异常；details 和 Hangfire dashboard 受保护，Worker management endpoint 不暴露业务路由。
- [x] G04-D35 Gate 必须自动测试启动分类、Runtime Role、多实例 claim、崩溃窗口、lease 接管、drain、发布顺序、探针和失败回退。
- [x] G04-D36 Gate 交付中英文说明、Deployment Unit Catalog、架构图、状态/流程/时序图、失败矩阵、验证映射以及 Mermaid + SVG/PNG。

## 当前与目标 Deployment Units

| Unit | 当前运行形态 | 目标运行形态 | 是否业务独立发布 |
| --- | --- | --- | --- |
| IFX API | `ifx-api` 同时承载 HTTP、业务模块、Hangfire 和 startup migration | `role=api`，只承载 HTTP、同步能力和 enqueue clients | 否；五模块锁步 |
| IFX Worker | 不存在独立 unit | 同 release/image 的 `role=worker`，承载 Hangfire、Dispatcher 和 consumers | 否；与 API 业务版本锁步 |
| Local All-in-one | 当前默认 ApiHost | `role=all`，仅本地、测试和迁移期 | 否 |
| IFX Frontend | 独立容器 | 独立部署 | 是，遵守 API compatibility |
| SQL Server | 独立容器/服务 | 独立基础设施 | 是 |
| sqlserver-init | one-shot 容器 | 幂等 infrastructure bootstrap | 是 |
| Database Migrator | ApiHost 内执行 | Gate 02 独立 one-shot artifact/job | 与 release 对齐但独立执行 |
| OPA | 独立容器 | 独立基础设施服务 | 是，遵守 policy/API compatibility |
| Cognito/SendGrid | 托管外部依赖 | 托管外部依赖 | 外部生命周期 |

“独立执行/部署”不自动等于业务微服务；业务自治仍以独立业务版本、进程协议、数据 ownership、故障和发布生命周期共同判断。

## 目标运行拓扑

```text
                         Load Balancer
                               |
                 +-------------+-------------+
                 |                           |
           IFX API replica A           IFX API replica B
           role=api                    role=api
           all business modules        all business modules
                 |                           |
                 +-------------+-------------+
                               |
                    module-owned schemas
                               |
                 +-------------+-------------+
                 |                           |
         IFX Worker replica A        IFX Worker replica B
         role=worker                 role=worker
         Hangfire + dispatchers      Hangfire + dispatchers
                 |                           |
                 +------ competing leases --+
                               |
                      transport / handlers

Independent: Frontend, SQL Server, OPA, Migrator, managed providers
```

## 启动与运行状态

```text
static config/manifest invalid ------------------> exit non-zero
          |
          v
register platform + modules -> validate DI/routes/catalog
          |
          v
     Alive / NotReady
          |
  schema + role dependencies
      /             \
  available       transiently unavailable
      |                    |
      v                    +--> remain Alive/NotReady + retry
    Ready
      |
  optional/capability issue
      v
   Degraded
      |
  SIGTERM / critical loop failure
      v
   NotReady -> drain -> exit
```

## 多实例 Dispatcher 流程

```text
Worker instance
   |
   v
short local transaction
select eligible rows + set LeaseOwner/LeaseUntil/token
   |
commit claim
   |
send outside transaction
   |                         crash/timeout
   |                              |
acknowledged                       v
   |                         lease expires
conditional delivered update      |
   |                              v
complete                    another worker reclaims
                                  |
                           same EventId may resend
                                  |
                           Inbox/idempotency absorbs duplicate
```

## 优雅关闭流程

```text
SIGTERM
   |
mark NotReady and start load-balancer drain
   |
stop schedules, queue fetch and new claims
   |
wait for bounded in-flight completion
   |                    |
completed             timeout
   |                    |
persist final state   keep recoverable lease/inbox state
   +---------+----------+
             |
flush telemetry and exit before orchestrator kill timeout
```

## Phase 0 — 建立部署与运行基线

- [x] **Phase 0 完成**：所有当前 deployable、嵌入式 runtime、启动动作和 probe 行为均有可复查证据。

- [x] G04-0.1 枚举 executable/image/container/one-shot job/managed dependency，并区分 source module、assembly、process、artifact、release 和 deployment boundary。
- [x] G04-0.2 保存 ApiHost 模块/Platform 注册、migration、endpoint mapping、Hangfire Server 和 messaging 当前启动顺序。
- [x] G04-0.3 盘点所有 IHostedService/BackgroundService、线程、scheduler、queue、recurring registration 和 shutdown token 使用。
- [x] G04-0.4 盘点 Compose/NAS/其他环境的 depends_on、restart、replica、healthcheck、stop signal、grace period 和 identity 配置。
- [x] G04-0.5 记录 `/health`、`/health/ready` 当前检查集合、响应、权限和外部依赖调用，并保存误判场景。
- [x] G04-0.6 生成当前单实例/多实例运行图，列出 HTTP scaling 对 Hangfire/未来 Dispatcher 并发的隐式放大。
- [x] G04-0.7 保存当前 release、startup、shutdown 和 failure 基线，明确尚未实现的目标能力而不伪造验证结果。

Phase 0 证据：[`G04-phase0-baseline.md`](../evidence/gates/G04/G04-phase0-baseline.md)、
[`G04-runtime-inventory.json`](../evidence/gates/G04/G04-runtime-inventory.json)、
[`G04-phase0-guard-report.json`](../evidence/gates/G04/G04-phase0-guard-report.json) 与
[`G04-phase0-layerguard-report.json`](../evidence/gates/G04/G04-phase0-layerguard-report.json)。

## Phase 1 — 冻结业务部署边界与 Manifest

- [x] **Phase 1 完成**：业务模块、Deployment Unit 和 release compatibility 的不同边界已显式建模。

- [x] G04-1.1 形成部署边界 ADR：五个业务模块共同发布，Platform/Infrastructure deployable 不因此并入业务单体边界。
- [x] G04-1.2 建立 Module Manifest schema，记录 ModuleId/version、requiredness、Contracts、endpoints、schema、配置、runtime capabilities 和 shutdown requirements。
- [x] G04-1.3 建立 Deployment Unit Catalog，登记 API、Worker、all-in-one、Frontend、SQL、init、Migrator、OPA 与 managed dependencies。
- [x] G04-1.4 建立 Release Manifest，将 ApiHost/Worker artifact、module versions、catalog hash、migration manifest 和 schema compatibility 绑定到不可变 release。
- [x] G04-1.5 验证所有 ApiHost replicas 的 required module set、endpoint set 和版本一致，禁止按副本关闭整个模块。
- [x] G04-1.6 定义独立基础设施的 compatibility matrix、owner 和升级责任，避免将其错误纳入业务模块锁步发布。
- [x] G04-1.7 为 manifest/catalog 的唯一 identity、引用完整性、版本匹配和部署类型建立 validator。

Phase 1 证据：[`ADR-G04-001`](../gates/G04/ADR-G04-001-deployment-runtime-boundary.md)、
`deployment/g04` 中的 manifests/catalog/matrix、
[`G04-phase1-manifest-report.json`](../evidence/gates/G04/G04-phase1-manifest-report.json)、
[`G04-phase1-guard-report.json`](../evidence/gates/G04/G04-phase1-guard-report.json) 与
[`G04-phase1-layerguard-report.json`](../evidence/gates/G04/G04-phase1-layerguard-report.json)。

## Phase 2 — 建立 API / Worker Runtime Roles

- [x] **Phase 2 完成**：同一 release 可确定地运行 API、Worker 或本地 all-in-one，且不会误启动其他角色能力。

- [x] G04-2.1 建立 Runtime Role 配置与启动验证，未知 role、空 Worker 或不安全生产 `all` 组合 fail fast。
- [x] G04-2.2 将 Hangfire client 与 Server 注册拆开；API 只 enqueue，Worker 才启动 Server。
- [x] G04-2.3 将 Outbox Dispatcher、message consumer 和 recurring registration 分成独立 capability flags，并验证合法组合。Dispatcher/consumer flags 默认关闭，等待 E3 提供真实实现。
- [x] G04-2.4 Worker 加载所需模块 Application/Infrastructure/Contracts/Composition，但不映射业务 Presentation endpoints；Presentation assembly 仍由同一锁步 artifact 链接，不形成可选模块。
- [x] G04-2.5 为 API 与 Worker 提供受保护的 `/management/runtime` endpoint；role-specific probe 聚合在 Phase 6 完成，Worker 不映射业务 HTTP。
- [x] G04-2.6 保留 `all` 供本地与集成测试，证明其 capability 是同版本 API+Worker 的并集；生产默认拒绝，除非显式批准。
- [x] G04-2.7 验证 API/Worker 只能锁步使用同一 `ifx-host` artifact 和 release manifest，不支持按模块独立选择版本。

Phase 2 证据：`RuntimeProfileResolverTests`、Compose API/Worker 同 artifact 配置、
[`G04-phase2-guard-report.json`](../evidence/gates/G04/G04-phase2-guard-report.json) 与
[`G04-phase2-layerguard-report.json`](../evidence/gates/G04/G04-phase2-layerguard-report.json)。

## Phase 3 — 重构确定性启动与依赖分类

- [x] **Phase 3 完成**：注册、验证、环境准备和 Ready 状态之间具有确定且无副作用的边界。

- [x] G04-3.1 将 platform primitives 注册置于显式阶段，再按 Module Manifest 拓扑映射 required modules；不依赖偶然 DI 枚举顺序。
- [x] G04-3.2 将 Composition `InstallServices` 和 endpoint mapping 约束为纯声明/注册；migration 已由 Gate 02 Migrator 独立执行，网络探测和 worker loop 均不在 Composition 中启动。
- [x] G04-3.3 在 Build 后验证 required module 单一 installer、module/release identity、允许 role 和 endpoint collision；Contract 单一实现继续由各 Composition DI 测试与 G03/Plan 01 catalog 约束，避免在 Host 复制 Contract registry。
- [x] G04-3.4 将错误 Runtime 配置、duplicate/missing module identity、manifest/release mismatch 和 endpoint collision 设为 startup-fatal，并提供稳定 `G04-*` reason code。
- [x] G04-3.5 Host 通过 `StartupDependencyMonitor` 先进入 Alive/NotReady，再异步、可取消且有 timeout 地验证 readiness-critical 依赖，并在恢复后转为 Ready。
- [x] G04-3.6 建立 startup-fatal、readiness-critical、capability-critical、optional、operational dependency catalog。
- [x] G04-3.7 审核 Cognito、OPA、SendGrid、各模块数据库、Hangfire storage 和 transport 的实际覆盖范围并记录 criticality；E3 启用 transport 后须回访真实 contributor。

Phase 3 证据：[`G04-phase3-dependency-review.md`](../evidence/gates/G04/G04-phase3-dependency-review.md)、
`deployment/g04/dependency-criticality-catalog.json`、`StartupBoundaryVerifierTests`、
[`G04-phase3-guard-report.json`](../evidence/gates/G04/G04-phase3-guard-report.json) 与
[`G04-phase3-layerguard-report.json`](../evidence/gates/G04/G04-phase3-layerguard-report.json)。

## Phase 4 — 建立多实例 Worker 与 Lease Conformance

- [x] **Phase 4 完成**：多个 Worker 的 reference fixture 可安全竞争模块式 Outbox，崩溃后可接管且不宣称 exactly-once；真实 E3/E4 绑定仍为最终关闭条件。

- [x] G04-4.1 定义唯一 instance identity 的来源、格式、日志/metrics tag、重启变化和最大长度，不依赖所有副本共享固定名称。
- [x] G04-4.2 为 Dispatcher 框架定义 per-module registration contract，使每个实例只通过模块服务访问其模块 Outbox；实际 registration 由 E3 实现。
- [x] G04-4.3 建立并交付 E3 可复用的 SQL Server 短事务 claim conformance suite：eligible filter、bounded batch、LeaseOwner、LeaseUntil、rowversion 和 conditional completion。
- [x] G04-4.4 用 reference fixture 验证发送确认前崩溃经 lease expiry 以相同 EventId 重发；send 明确位于 claim 事务外，真实 Dispatcher 在 E3 重跑。
- [x] G04-4.5 定义并测试 lease renewal、expiry、clock tolerance、stale owner 和并发更新失败语义。
- [x] G04-4.6 为需要顺序的 Module/Tenant/Aggregate partition 定义单 in-flight/sequence conformance，不声明全局顺序；具体 Event 分区由 E3 登记。
- [x] G04-4.7 定义模块/分区公平性、batch size、poll jitter、renewal 和数据库负载限制接口；E3 负责真实 backlog 调度实现及公平性指标。
- [x] G04-4.8 Hangfire 使用 runtime instance identity、per-instance WorkerCount 和显式 queues；recurring registration 是独立且默认关闭的 capability，生产启用前须由编排选择唯一 authority。
- [x] G04-4.9 `CriticalWorkerBackgroundService` 使未处理关键 loop 异常进入 NotReady、设置非零 exit 并停止进程；普通消息失败仍由 E3 durable retry/dead-letter 实现。

Phase 4 证据：[`G04-phase4-lease-conformance.md`](../evidence/gates/G04/G04-phase4-lease-conformance.md)、
`G04DispatcherLeaseConformanceTests`、`RuntimeInstanceIdentityTests`、
[`G04-phase4-guard-report.json`](../evidence/gates/G04/G04-phase4-guard-report.json) 与
[`G04-phase4-layerguard-report.json`](../evidence/gates/G04/G04-phase4-layerguard-report.json)。

## Phase 5 — 建立优雅关闭与接管

- [ ] **Phase 5 PRE-READY**：API、Worker 与 all-in-one 的 Host drain 已实现并验证；真实 Dispatcher/Inbox 的故障接管等待 E3/E4。

- [x] G04-5.1 实现统一 drain coordinator，在 shutdown 开始时原子设置 NotReady 并拒绝新的 claim/schedule/fetch；E3 loops 通过 `IRuntimeDrainSignal` 接入。
- [x] G04-5.2 配置负载均衡 drain，停止新 HTTP 请求后允许 in-flight request 在预算内完成；health 端点保持可探测。
- [ ] G04-5.3 Dispatcher 在 drain 中完成已确认发送的条件更新；未确认发送不得猜测 delivered。Host contract 已就绪，真实行为等待 E3。
- [x] G04-5.4 Hangfire 随 Host cancellation 停止领取，Consumer 获得统一 drain token；真实 consumer durable recovery 等待 E3。
- [x] G04-5.5 以自动化边界测试验证 operation、handler、lease、process grace、orchestrator kill 的严格递增预算；生产负载校准仍列为交接项。
- [x] G04-5.6 配置 Host 与 Compose 的 SIGTERM/45s grace，并为有界 drain 保留 telemetry flush 预算；目标生产 orchestrator 参数仍需运维确认。
- [ ] G04-5.7 reference SQL 已验证 lease expiry，Hangfire 使用持久 storage；真实 Dispatcher crash 与 Inbox 幂等接管等待 E3/E4。

Phase 5 证据：[`G04-phase5-drain-conformance.md`](../evidence/gates/G04/G04-phase5-drain-conformance.md)、
`RuntimeDrainCoordinatorTests`、[`G04-phase5-guard-report.json`](../evidence/gates/G04/G04-phase5-guard-report.json) 与
[`G04-phase5-layerguard-report.json`](../evidence/gates/G04/G04-phase5-layerguard-report.json)。

## Phase 6 — 重建 Health、Startup 与 Readiness

- [ ] **Phase 6 PRE-READY**：Host 探针语义、role 聚合、缓存与受保护 details 已实现；真实 Worker contributors 与 Gate 05 sentinel 等待 E3/E6/G05。

- [x] G04-6.1 建立 `/health/live`，只读取进程 lifecycle/关键 loop 状态，不调用任何网络依赖。
- [x] G04-6.2 建立 `/health/startup`，静态 config/manifest/DI/route 初始化完成后保持成功，drain 不倒退 startup。
- [x] G04-6.3 重建 `/health/ready`，从缓存按 API/Worker/all role 聚合，并在 Starting/Stopping 阶段失败。
- [ ] G04-6.4 建立受保护 `/health/details`，输出稳定 reason、release、role、instance、freshness 和 contributor 状态且不复制异常/description；最终字段分类等待 Gate 05。
- [x] G04-6.5 五个业务模块的 SQL/schema contributor 无写入、低成本且由 monitor timeout 约束；contract/external contributor 随真实能力接入。
- [ ] G04-6.6 Hangfire 使用 Host lifecycle；Dispatcher、consumer、transport、lease 和 module backlog contributor 等待 E3/E6 真实信号。
- [x] G04-6.7 外部检查由单 monitor 串行合并并缓存 lastChecked/lastSucceeded/duration/status/reason，具有 timeout 与轮询窗口；生产 jitter 校准留待演练。
- [x] G04-6.8 readiness-critical 决定 Ready/NotReady，Cognito 标为 capability-critical/Degraded；SendGrid optional 与 OPA operational 维持 Phase 3 审核结论。
- [ ] G04-6.9 details 已认证且公开探针已脱敏；Hangfire/Worker 网络边界和 Gate 05 C0-C4 sentinel 等待 G05 与运维环境。

Phase 6 证据：[`G04-phase6-health-conformance.md`](../evidence/gates/G04/G04-phase6-health-conformance.md)、
`HealthEndpointTests`、`HealthSnapshotStoreTests`、[`G04-phase6-guard-report.json`](../evidence/gates/G04/G04-phase6-guard-report.json) 与
[`G04-phase6-layerguard-report.json`](../evidence/gates/G04/G04-phase6-layerguard-report.json)。

## Phase 7 — 消息积压、Backpressure 与告警

- [ ] **Phase 7 PRE-READY**：指标、阈值、判定、选择性 backpressure 与恢复契约已通过 synthetic 验证；真实 E3/E6 信号和生产容量校准未关闭。

- [x] G04-7.1 定义 per-module/event oldest pending age、count、retry/dead-letter、last success、latency/rate、expired lease 和 duplicate rate 的指标契约；E3/E6 负责从真实存储采集。
- [ ] G04-7.2 warning/critical/freshness 阈值已版本化并由 validator 检查顺序；按事件类别/环境的生产容量校准等待 E6/运维。
- [ ] G04-7.3 evaluator 已产生 Healthy/Warning/Critical 稳定 reason；接入 Worker lifecycle、告警和命令管道等待 E3/E6 真实信号。
- [x] G04-7.4 Backpressure 决策只限制同 module/event 且 `ExpandsBacklog` 的命令，保留读取和无关能力，并提供 retryable/Retry-After 契约。
- [x] G04-7.5 evaluator 明确禁止只按数量判断，组合 age、业务类别、处理速率、dead-letter 和 storage capacity。
- [ ] G04-7.6 synthetic suite 覆盖 transport stall、毒消息、dead-letter、作用域隔离和恢复；真实单模块饥饿/silent-stop 告警等待 E3/E6。
- [x] G04-7.7 提供受控恢复流程：暂停相关生产、扩展 Worker、修复 transport、审查 dead-letter、回放并解除 backpressure。

Phase 7 证据：[`G04-phase7-backpressure-conformance.md`](../evidence/gates/G04/G04-phase7-backpressure-conformance.md)、
[`backpressure-recovery-runbook.md`](../gates/G04/backpressure-recovery-runbook.md)、`MessageBackpressurePolicyTests`、
[`G04-phase7-guard-report.json`](../evidence/gates/G04/G04-phase7-guard-report.json) 与
[`G04-phase7-layerguard-report.json`](../evidence/gates/G04/G04-phase7-layerguard-report.json)。

## Phase 8 — 实现部署编排、Seed 与兼容发布

- [ ] **Phase 8 PRE-READY**：consumer-first 编排 DAG、失败策略、独立数据 job 与证据模板已版本化并验证；目标环境 rollout/观测/批准尚未执行。

- [x] G04-8.1 编排 DAG 将 Gate 02 preflight/restore point/Migrator/validation 设为 Worker/API 的严格前置，任一失败均停止且不自动 Down。
- [ ] G04-8.2 DAG 强制 Worker consumer 在 API producer 前并要求全部 Ready/V1+V2 兼容证据；真实 E3 consumer 与目标副本部署未执行。
- [ ] G04-8.3 API rolling/compatibility window 与失败停止规则已编码；生产滚动发布未执行。
- [ ] G04-8.4 scheduler 是 Worker Ready/API 后的唯一 authority 阶段；真实 recurring definitions、幂等注册与 authority 选择未演练。
- [x] G04-8.5 reference migration、system seed、demo seed 和业务 backfill 已拆为四类独立 job contract，均要求 owner、幂等、审计且禁止自动执行。
- [ ] G04-8.6 cleanup 依赖 observation 阶段及 schema/API/Worker/backlog/retry/dead-letter 稳定证据；E6/生产观测未执行。
- [ ] G04-8.7 Release Manifest 要求 `observed-zero-old-version-demand`，但真实 Outbox/Inbox/dead-letter/replay 清零等待 E3/E4/E6。
- [ ] G04-8.8 evidence template 覆盖 digest、manifest、migration、阶段、批准和观测；尚无生产 release 可填写并验证 `RequireCompleted`。

Phase 8 证据：[`G04-phase8-release-orchestration.md`](../evidence/gates/G04/G04-phase8-release-orchestration.md)、
`deployment/g04/release-orchestration.json`、`Test-G04ReleaseOrchestration.ps1`、
[`G04-phase8-orchestration-report.json`](../evidence/gates/G04/G04-phase8-orchestration-report.json)、
[`G04-phase8-guard-report.json`](../evidence/gates/G04/G04-phase8-guard-report.json) 与
[`G04-phase8-layerguard-report.json`](../evidence/gates/G04/G04-phase8-layerguard-report.json)。

## Phase 9 — 失败矩阵与安全回退

- [ ] **Phase 9 PRE-READY**：部署与运行失败矩阵及安全回退规则已机器验证；真实 E3/E4 接管与生产演练仍待下游证据。

- [x] G04-9.1 Migrator/preflight 失败硬阻断新 Worker/API，保持兼容旧 release，矩阵禁止自动 Down。
- [x] G04-9.2 Worker V2 未 Ready 禁止 API V2 producer rollout；兼容 Worker 的 V1 消费要求写入编排与矩阵。
- [x] G04-9.3 API rolling failure 停止 rollout 并保留健康旧副本，cleanup 被阻断并要求复核 schema 兼容。
- [x] G04-9.4 API V2 已产生 V2 Event 时回退 API 必须保留 V2 Worker，直至 backlog/replay 清零。
- [ ] G04-9.5 transport/storage 故障的 retry/backpressure 与不得删除/伪造规则已固定；真实 E3 durable retry/dead-letter 尚未验证。
- [ ] G04-9.6 reference lease/Hangfire storage 与 fleet runbook 已就绪；真实 Worker crash/fleet 接管等待 E3/生产演练。
- [x] G04-9.7 shutdown 超时有界强退，规则要求保留可重试持久状态与审计关联；Inbox 部分等待 E4。
- [x] G04-9.8 module、dependency、role、failure reason、operator action 和恢复验证已形成版本化失败矩阵。

Phase 9 证据：[`G04-phase9-failure-safety.md`](../evidence/gates/G04/G04-phase9-failure-safety.md)、
[`failure-rollback-runbook.md`](../gates/G04/failure-rollback-runbook.md)、`Test-G04FailureMatrix.ps1`、
[`G04-phase9-failure-matrix-report.json`](../evidence/gates/G04/G04-phase9-failure-matrix-report.json)、
[`G04-phase9-guard-report.json`](../evidence/gates/G04/G04-phase9-guard-report.json) 与
[`G04-phase9-layerguard-report.json`](../evidence/gates/G04/G04-phase9-layerguard-report.json)。

## Phase 10 — 自动化测试与发布验收

- [ ] **Phase 10 PRE-READY**：当前可实现的启动、角色、reference lease、探针、drain 与策略验证已纳入 CI；真实 E3/E4、G05 sentinel 和生产演练未关闭。

- [ ] G04-10.1 invalid config/manifest 与 duplicate module/endpoint 已有 startup-fatal 测试；missing/multiple Contract implementation 仍由 G03/Plan 01 catalog 验收，尚未在 Host 重复建模。
- [ ] G04-10.2 monitor 已实现 timeout、Alive/NotReady 和恢复转 Ready；真实 transient DB integration 需目标环境演练。
- [x] G04-10.3 `RuntimeProfileResolverTests` 与 Host/guard 验证 API/Worker/all capabilities、endpoint role gate 和 Hangfire server gate。
- [x] G04-10.4 真实 SQL Server reference fixture 验证两个 claimant、conditional completion、expiry、renewal 和接管；E3 重跑仍是 DD03 条件。
- [ ] G04-10.5 reference fixture 已覆盖 crash before send、after send before persisted ack、after completion；E3/E4 的真实不丢失/重复吸收证据未交回。
- [ ] G04-10.6 fixture 覆盖分区顺序和不同分区并发；毒消息、模块公平性与具体事件映射等待 E3。
- [ ] G04-10.7 unique identity、WorkerCount/queue config 与 recurring API 有测试/静态 guard；多 Server 总容量及唯一 scheduler authority 未演练。
- [ ] G04-10.8 drain coordinator 测试停止新工作、in-flight、timeout；真实 SIGTERM/load-balancer/forced kill/telemetry flush 等待平台演练。
- [ ] G04-10.9 live/startup/ready/details 状态码与权限、snapshot freshness 已测试；Gate 05 敏感 sentinel 未交回。
- [ ] G04-10.10 编排 DAG 和失败矩阵通过结构验证；目标环境全链路演练尚未执行。
- [x] G04-10.11 CI workflow 运行 G04 guard、manifest/orchestration/failure validator、LayerGuard、解方案 build/test 并上传报告。

Phase 10 证据：[`G04-phase10-automated-acceptance.md`](../evidence/gates/G04/G04-phase10-automated-acceptance.md)、
`.github/workflows/g04-deployment-runtime.yml`、`Invoke-G04Verification.ps1`、
[`G04-phase10-guard-report.json`](../evidence/gates/G04/G04-phase10-guard-report.json) 与
[`G04-phase10-layerguard-report.json`](../evidence/gates/G04/G04-phase10-layerguard-report.json)。

## Phase 11 — 架构与规则文档化

- [x] **Phase 11 完成**：部署边界、运行角色、多实例处理和健康治理形成可维护的中英文图文基线。

- [x] G04-11.1 创建中文设计文档 `docs/architecture/review/gates/G04/deployment-runtime-boundary.zh-CN.md`。
- [x] G04-11.2 创建对应英文文档 `docs/architecture/review/gates/G04/deployment-runtime-boundary.en.md`，保持 G04-D01 至 G04-D09 与运行术语一致。
- [x] G04-11.3 文档解释业务模块共同发布与 Platform/Infrastructure 独立部署的区别，以及为何 Worker role 不等于微服务。
- [x] G04-11.4 Deployment Unit Catalog、Module Manifest、Release Manifest 和 dependency criticality 矩阵均已链接和解释。
- [x] G04-11.5 创建总体部署边界、单/多实例 API/Worker 拓扑和业务发布边界图。
- [x] G04-11.6 创建启动/健康/drain 状态机以及 Dispatcher claim/lease/backpressure 流程图。
- [x] G04-11.7 创建 DB → Worker consumer → API producer → scheduler → observation/cleanup 的 V1/V2 时序图。
- [x] G04-11.8 创建 failure/rollback 图与运行手册，覆盖 migration、schema、transport、worker crash、backlog 和 shutdown。
- [x] G04-11.9 六份 Mermaid 源文件均用 Mermaid CLI 11.17.0 渲染为 SVG/PNG，并完成可视检查与文件 validator。
- [x] G04-11.10 G04-D01 至 D09 映射到 manifest/startup/probe/test/CI/指标/人工审批，并标注下游证据。
- [x] G04-11.11 更新架构索引、前置/总计划和 Contracts/Event/LayerGuard 子计划反向链接，脚本验证中英文 decision IDs 一致。

Phase 11 证据：[`G04-phase11-documentation.md`](../evidence/gates/G04/G04-phase11-documentation.md)、
[`G04-phase11-documentation-report.json`](../evidence/gates/G04/G04-phase11-documentation-report.json)、
[`G04-phase11-guard-report.json`](../evidence/gates/G04/G04-phase11-guard-report.json) 与
[`G04-phase11-layerguard-report.json`](../evidence/gates/G04/G04-phase11-layerguard-report.json)。

## Phase 12 — Gate 关闭与后续计划交接

- [ ] **Phase 12 PRE-READY**：仓库内可实现基线和交接审计已完成；Gate 04 未批准关闭，真实 Event Dispatcher、生产演练与下游证据仍受阻塞清单约束。

- [x] G04-12.1 对照 DP1、DP3、DP4、DP5 附上 ADR、catalog/manifest、代码、reference/synthetic 测试、probe 和文档证据；生产演练差距保留为 G04-B06。
- [x] G04-12.2 确认五个业务模块仍为一个发布边界，而 API/Worker 角色和独立 infrastructure 没有伪装成业务独立部署。
- [x] G04-12.3 向 Gate 02 交付 Migrator/schema readiness 与发布编排接口；生产执行证据仍由 G04-B06 回交。
- [x] G04-12.4 向 Event 子计划交付 Runtime Role、instance identity、lease、shutdown、consumer-first、health 和 backpressure 规则；E3/E4/E6 为 G04-B01 至 B03。
- [x] G04-12.5 向 LayerGuard 子计划交付 API/Worker Runtime Host 只能引用 Composition/host primitives 的编译期要求；L5.1/L5.2 与 B1/B4 为 G04-B05。
- [ ] G04-12.6 在 [`00-prerequisites.md`](00-prerequisites.md) 勾选 Gate 4 相关事项，仅在全部实施、验证与文档完成后操作。
- [x] G04-12.7 在机器可读状态中记录未解决的生产平台特有参数、owner、到期里程碑和 production-like 验证环境，不使用永久默认值掩盖。
- [ ] G04-12.8 由架构、模块、Platform、数据库和运维负责人共同批准 Gate 关闭。

Phase 12 PRE-READY 证据：[`G04-phase12-handoff.md`](../evidence/gates/G04/G04-phase12-handoff.md)、
[`G04-phase12-status.json`](../evidence/gates/G04/G04-phase12-status.json) 与
[`G04-phase12-closeout-report.json`](../evidence/gates/G04/G04-phase12-closeout-report.json)。

## Definition of Done

- [x] G04-DD01 Deployment Unit、Module 和 Release Manifest 能准确区分共同业务发布与独立基础设施生命周期。
- [x] G04-DD02 API/Worker/all Runtime Role 行为确定，生产可独立扩展 HTTP 与后台容量但业务版本继续锁步。
- [ ] G04-DD03 多实例 claim/lease、at-least-once、分区顺序和 crash recovery conformance 通过真实数据库 reference fixture，且 E3/E4 的真实 Dispatcher/Inbox 通过同一验收。
- [ ] G04-DD04 Hangfire client/server、identity、queue、WorkerCount 和 recurring authority 在多实例环境可验证。
- [x] G04-DD05 startup-fatal、NotReady、Degraded、worker fatal 和 graceful drain 状态均有稳定的 reference 行为与 reason code；生产编排验证仍归 G04-B06。
- [ ] G04-DD06 live/startup/ready/details 按 role 和 criticality 正确聚合，无副作用且不泄漏敏感信息。
- [ ] G04-DD07 database → Worker consumer → API producer → scheduler → cleanup 顺序及失败回退由 CI/CD 或演练验证。
- [ ] G04-DD08 backlog age、retry/dead-letter、lease、last success 和 backpressure 具有指标、阈值、告警与恢复手册。
- [ ] G04-DD09 中英文说明、架构图、流程图、状态图、时序图、失败矩阵和规则验证映射全部完成并审核。

## 回退与运行安全原则

- [x] G04-R01 API/Worker role 切分失败时可暂时回到同版本 `all`，但必须保留多实例安全、唯一 identity、health 和 shutdown 规则。
- [x] G04-R02 schema/migration 问题优先停止发布并 roll-forward；不自动执行 Down，也不让未验证实例开始 dispatch。
- [x] G04-R03 Consumer-first 发布中即使 API 回退，也不得先删除或回退仍需处理 V2 backlog 的 Worker consumer。
- [ ] G04-R04 Dispatcher/transport 故障不删除 Outbox、不伪造成功；通过持久 retry、lease 接管和受控 backpressure 恢复。
- [ ] G04-R05 forced termination 必须依赖持久状态恢复，不能通过无限 shutdown 或 lease 隐藏无法停止的问题。
- [x] G04-R06 health/readiness 配置回退不得把外部依赖放进 liveness，也不得通过始终 Healthy 掩盖 critical worker failure。
