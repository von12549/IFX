# Plan 00 / Gate 04：部署与运行边界实施计划

> 状态：Architecture Decisions Approved / 待实施
> 上级前置计划：[`00-prerequisites.md`](00-prerequisites.md)
> 上级总计划：[`00-master-plan.md`](00-master-plan.md)
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

- [ ] **Phase 0 完成**：所有当前 deployable、嵌入式 runtime、启动动作和 probe 行为均有可复查证据。

- [ ] G04-0.1 枚举 executable/image/container/one-shot job/managed dependency，并区分 source module、assembly、process、artifact、release 和 deployment boundary。
- [ ] G04-0.2 保存 ApiHost 模块/Platform 注册、migration、endpoint mapping、Hangfire Server 和 messaging 当前启动顺序。
- [ ] G04-0.3 盘点所有 IHostedService/BackgroundService、线程、scheduler、queue、recurring registration 和 shutdown token 使用。
- [ ] G04-0.4 盘点 Compose/NAS/其他环境的 depends_on、restart、replica、healthcheck、stop signal、grace period 和 identity 配置。
- [ ] G04-0.5 记录 `/health`、`/health/ready` 当前检查集合、响应、权限和外部依赖调用，并保存误判场景。
- [ ] G04-0.6 生成当前单实例/多实例运行图，列出 HTTP scaling 对 Hangfire/未来 Dispatcher 并发的隐式放大。
- [ ] G04-0.7 保存当前 release、startup、shutdown 和 failure 基线，明确尚未实现的目标能力而不伪造验证结果。

## Phase 1 — 冻结业务部署边界与 Manifest

- [ ] **Phase 1 完成**：业务模块、Deployment Unit 和 release compatibility 的不同边界已显式建模。

- [ ] G04-1.1 形成部署边界 ADR：五个业务模块共同发布，Platform/Infrastructure deployable 不因此并入业务单体边界。
- [ ] G04-1.2 建立 Module Manifest schema，记录 ModuleId/version、requiredness、Contracts、endpoints、schema、配置、runtime capabilities 和 shutdown requirements。
- [ ] G04-1.3 建立 Deployment Unit Catalog，登记 API、Worker、all-in-one、Frontend、SQL、init、Migrator、OPA 与 managed dependencies。
- [ ] G04-1.4 建立 Release Manifest，将 ApiHost/Worker artifact、module versions、catalog hash、migration manifest 和 schema compatibility 绑定到不可变 release。
- [ ] G04-1.5 验证所有 ApiHost replicas 的 required module set、endpoint set 和版本一致，禁止按副本关闭整个模块。
- [ ] G04-1.6 定义独立基础设施的 compatibility matrix、owner 和升级责任，避免将其错误纳入业务模块锁步发布。
- [ ] G04-1.7 为 manifest/catalog 的唯一 identity、引用完整性、版本匹配和部署类型建立 validator。

## Phase 2 — 建立 API / Worker Runtime Roles

- [ ] **Phase 2 完成**：同一 release 可确定地运行 API、Worker 或本地 all-in-one，且不会误启动其他角色能力。

- [ ] G04-2.1 建立 Runtime Role 配置与启动验证，未知 role、空 Worker 或不安全生产 `all` 组合 fail fast。
- [ ] G04-2.2 将 Hangfire client 与 Server 注册拆开；API 只 enqueue，Worker 才启动 Server。
- [ ] G04-2.3 将 Outbox Dispatcher、message consumer 和 recurring registration 分成独立 capability flags，并验证合法组合。
- [ ] G04-2.4 Worker 加载所需模块 Application/Infrastructure/Contracts/Composition，但不加载或映射业务 Presentation endpoints。
- [ ] G04-2.5 为 API 与 Worker 提供独立 management endpoint 和 role-specific health，不让 Worker 暴露业务 HTTP。
- [ ] G04-2.6 保留 `all` 供本地与集成测试，证明其行为等价于同版本 API+Worker，但生产默认禁用。
- [ ] G04-2.7 验证 API/Worker 只能锁步使用同一业务 release，不支持按模块独立选择版本。

## Phase 3 — 重构确定性启动与依赖分类

- [ ] **Phase 3 完成**：注册、验证、环境准备和 Ready 状态之间具有确定且无副作用的边界。

- [ ] G04-3.1 将 platform primitives 注册置于显式阶段，再按 Module Manifest 拓扑注册 required modules；不依赖偶然 DI 枚举顺序。
- [ ] G04-3.2 将 Composition `InstallServices` 和 endpoint mapping 约束为纯声明/注册，移除 migration、seed、网络探测和 worker 启动副作用。
- [ ] G04-3.3 在 Build 后验证 required Contract 单一实现、module dependency、endpoint collision、catalog/release/schema metadata 一致性。
- [ ] G04-3.4 将错误配置、duplicate identity、missing service 和 manifest mismatch 设为 startup-fatal，并提供稳定 exit/reason code。
- [ ] G04-3.5 让 Host 先进入 Alive/NotReady，再异步验证可恢复环境依赖；检查可取消、超时且不会无限阻塞启动。
- [ ] G04-3.6 建立 startup-fatal、readiness-critical、capability-critical、optional、operational dependency catalog。
- [ ] G04-3.7 审核 Cognito、OPA、SendGrid、各模块数据库、Hangfire storage 和 transport 的实际覆盖范围并批准 criticality。

## Phase 4 — 建立多实例 Worker 与 Lease Conformance

- [ ] **Phase 4 完成**：多个 Worker 可安全竞争模块 Outbox，崩溃后可接管且不宣称 exactly-once。

- [ ] G04-4.1 定义唯一 instance identity 的来源、格式、日志/metrics tag、重启变化和最大长度，不依赖所有副本共享固定名称。
- [ ] G04-4.2 为 Dispatcher 框架定义 per-module registration contract，使每个实例只通过模块服务访问其模块 Outbox；实际 registration 由 E3 实现。
- [ ] G04-4.3 建立并交付 E3 可复用的短事务 claim conformance suite：eligible filter、bounded batch、LeaseOwner、LeaseUntil、concurrency token 和 conditional completion。
- [ ] G04-4.4 用 reference fixture 验证事务外发送和发送确认前崩溃的 at-least-once 重发路径；真实 Dispatcher 在 E3 重跑。
- [ ] G04-4.5 定义 lease renewal、expiry、clock tolerance、stale owner 和并发更新失败语义。
- [ ] G04-4.6 为需要顺序的 Tenant/Aggregate partition 定义单 in-flight/sequence conformance，不声明全局顺序；具体 Event 分区由 E3 登记。
- [ ] G04-4.7 定义模块/分区公平性、batch size、poll jitter 和数据库负载限制接口，E3 负责真实 backlog 调度实现。
- [ ] G04-4.8 配置 Hangfire unique server identity、per-instance WorkerCount、queue ownership 和唯一 recurring registration authority。
- [ ] G04-4.9 关键 worker-loop 未处理异常必须使 role NotReady 并终止进程；普通消息失败进入可观察 retry/dead-letter 状态。

## Phase 5 — 建立优雅关闭与接管

- [ ] **Phase 5 完成**：API、Worker 与 all-in-one 在部署和故障终止时停止领取新工作，并保留可恢复状态。

- [ ] G04-5.1 实现统一 drain coordinator，在 shutdown 开始时原子设置 NotReady 并拒绝新的 claim/schedule/fetch。
- [ ] G04-5.2 配置负载均衡 drain，停止新 HTTP 请求后允许 in-flight request 在预算内完成。
- [ ] G04-5.3 Dispatcher 在 drain 中完成已确认发送的条件更新；未确认发送不得猜测 delivered。
- [ ] G04-5.4 Hangfire 与 Consumer 停止取新工作并遵守 cancellation；无法完成的任务保留平台可重新领取状态。
- [ ] G04-5.5 根据实测确定 operation、handler、lease、process grace、orchestrator kill 的严格递增预算与 renewal 限制。
- [ ] G04-5.6 配置 Host、Compose 和目标 orchestrator 的 stop signal/grace period，并验证日志/trace 在退出前有界 flush。
- [ ] G04-5.7 对 forced kill、网络中断和进程 crash 验证 lease expiry、Hangfire recovery 与 Inbox 幂等接管。

## Phase 6 — 重建 Health、Startup 与 Readiness

- [ ] **Phase 6 完成**：探针语义独立、按 role 聚合、无副作用且不会泄漏敏感信息。

- [ ] G04-6.1 建立 `/health/live`，只检查进程和关键循环是否不可恢复故障，不调用 SQL、Cognito、OPA、transport 或其他网络依赖。
- [ ] G04-6.2 建立 `/health/startup`，在静态 config/manifest/DI/route 初始化完成前失败，完成后保持成功。
- [ ] G04-6.3 重建 `/health/ready`，按 API/Worker/all role 选择 contributor，并在 Starting/Stopping 阶段失败。
- [ ] G04-6.4 建立受保护 `/health/details`，按 Gate 05 输出稳定 reason、release、role、instance、freshness 和 contributor 状态，不输出 secret/payload/stack trace 或原始 tenant/user 标识。
- [ ] G04-6.5 为五个业务模块提供无写入、低成本、有 timeout 的 schema/database/contract/external dependency Health Contributor。
- [ ] G04-6.6 为 Worker 提供 Hangfire、Dispatcher、consumer、transport、lease 和 module backlog contributor。
- [ ] G04-6.7 为外部检查实现 lastChecked/lastSucceeded/duration/status/reason、缓存、timeout、jitter 和并发合并。
- [ ] G04-6.8 按 dependency criticality 聚合 Healthy/Degraded/Unhealthy，明确 Cognito capability、SendGrid optional 和 OPA 审核结论。
- [ ] G04-6.9 对 details、Hangfire dashboard 和 Worker management port 建立生产认证、网络和 Gate 05 C0-C4/日志脱敏规则。

## Phase 7 — 消息积压、Backpressure 与告警

- [ ] **Phase 7 完成**：消息通道故障不会静默积压，系统可在保留读取能力的同时限制扩大风险的写入。

- [ ] G04-7.1 定义 per-module/event oldest pending age、count、retry/dead-letter、last success、latency、expired lease 和 duplicate rate 的指标契约；E3/E6 负责从真实存储采集。
- [ ] G04-7.2 为不同事件类别和环境定义 warning/critical SLO 与 freshness window，阈值配置受版本控制并经容量验证。
- [ ] G04-7.3 warning 进入 Degraded 和告警；critical 使 Worker NotReady，并触发事件生产命令的受控 backpressure。
- [ ] G04-7.4 Backpressure 只限制会扩大相关积压的命令，尽可能保留安全读取和无关能力；返回稳定 retryable error 与 Retry-After 语义。
- [ ] G04-7.5 禁止只以消息数量判断健康；age、业务类别、处理速率和 storage capacity 必须共同评估。
- [ ] G04-7.6 建立告警规则和 synthetic/reference 验证，覆盖 transport outage、毒消息、单模块饥饿、dead-letter 增长和 dispatcher silent-stop；真实信号由 E3/E6 接入。
- [ ] G04-7.7 提供受控恢复流程：暂停生产、扩展 Worker、修复 transport、审查 dead-letter、回放并解除 backpressure。

## Phase 8 — 实现部署编排、Seed 与兼容发布

- [ ] **Phase 8 完成**：数据库、Worker consumer、API producer、scheduler 和清理阶段按兼容顺序部署且失败可停止。

- [ ] G04-8.1 将 Gate 02 的 preflight/restore point/Migrator/validation 作为发布硬前置，schema 未验证时 Worker Dispatcher 和 API 新版均不得 Ready。
- [ ] G04-8.2 部署支持旧/新 Event schema 的 Worker，并等待所有目标副本 Ready 后才允许 API 生产新版本。
- [ ] G04-8.3 滚动部署 API，保持旧/新实例只在批准的 Contract、Event 和 Expand/Contract 窗口内共存。
- [ ] G04-8.4 将 recurring definitions 交由唯一 Scheduler authority 在 Worker Ready 后幂等注册；失败阻断相应 capability。
- [ ] G04-8.5 将 reference migration、system seed、demo seed 和业务 backfill 拆成独立命令/job，定义 owner、幂等、审计和失败行为。
- [ ] G04-8.6 发布后观察 schema、API、Worker、backlog、retry、dead-letter 和 compatibility 指标，再允许 contract cleanup。
- [ ] G04-8.7 旧 Event consumer 只有在 Outbox/Inbox/dead-letter/replay 均无旧版本需求后才能移除。
- [ ] G04-8.8 生成并保存每次发布的 artifact digest、manifest、migration、部署阶段、批准和观测证据。

## Phase 9 — 失败矩阵与安全回退

- [ ] **Phase 9 完成**：每个部署和运行失败点都有明确的继续、停止、接管、限流或回退动作。

- [ ] G04-9.1 Migrator/preflight 失败时阻断新 Worker/API，保持兼容旧 release，禁止自动 Down。
- [ ] G04-9.2 Worker V2 未 Ready 时禁止 API V2 producer rollout；已升级 Worker 可继续处理旧消息。
- [ ] G04-9.3 API rolling failure 时停止 rollout 并保留健康旧副本，验证 schema 仍向后兼容。
- [ ] G04-9.4 如果 API V2 已产生 V2 Event，回退 API 时保留支持 V2 的 Worker，直至 backlog/replay 清零。
- [ ] G04-9.5 transport/storage 故障进入 retry/backlog/backpressure；不得删除、跳过或伪造 delivered。
- [ ] G04-9.6 单 Worker 崩溃依赖 lease/Hangfire recovery 接管；大面积故障使用明确暂停与恢复 runbook。
- [ ] G04-9.7 shutdown 超时允许强制退出，但必须留下可重试、可诊断的持久状态和审计记录。
- [ ] G04-9.8 将 module、dependency、role、failure reason、operator action 和恢复验证形成运行失败矩阵。

## Phase 10 — 自动化测试与发布验收

- [ ] **Phase 10 完成**：启动、角色、多实例、探针、关闭与部署时序均由自动化或受控演练证明。

- [ ] G04-10.1 测试 invalid config/manifest、duplicate module/endpoint、missing/multiple Contract implementation 的 startup-fatal exit。
- [ ] G04-10.2 测试 transient DB/dependency 故障时 Alive/NotReady，以及恢复后不重启转为 Ready。
- [ ] G04-10.3 测试 API/Worker/all 角色只启动允许能力，Worker 不映射业务 endpoint，API 不启动 Server/Dispatcher。
- [ ] G04-10.4 使用真实 SQL Server reference fixture 验证两个以上 claimant 的原子 claim、conditional completion、lease expiry、renewal 和接管；E3 在真实 Dispatcher 重跑。
- [ ] G04-10.5 在 reference fixture 注入 claim 前、发送后标记前、标记后崩溃；E3/E4 回交真实 Outbox/Inbox 的不丢失与重复吸收证据。
- [ ] G04-10.6 用 conformance fixture 测试分区顺序、不同分区并发、毒消息隔离和模块公平性；具体事件映射由 E3 验收。
- [ ] G04-10.7 测试 Hangfire 多 Server identity、总 WorkerCount、queue ownership、recurring registration 和 failure health。
- [ ] G04-10.8 测试 SIGTERM、load-balancer drain、停止新 claim、in-flight completion、timeout、forced kill 和 telemetry flush。
- [ ] G04-10.9 测试 live/startup/ready/details 的选择、状态码、权限、freshness、timeout，并运行 Gate 05 敏感 sentinel 验证无未批准数据。
- [ ] G04-10.10 演练 Migrator → Worker → API → scheduler → cleanup，以及各阶段失败、停止和安全回退。
- [ ] G04-10.11 在 CI/CD 中验证 release/module/deployment/catalog/migration manifest 一致并保存报告。

## Phase 11 — 架构与规则文档化

- [ ] **Phase 11 完成**：部署边界、运行角色、多实例处理和健康治理形成可维护的中英文图文基线。

- [ ] G04-11.1 创建中文设计文档 `docs/architecture/review/gates/G04/deployment-runtime-boundary.zh-CN.md`。
- [ ] G04-11.2 创建对应英文文档 `docs/architecture/review/gates/G04/deployment-runtime-boundary.en.md`，保持决策编号与运行术语一致。
- [ ] G04-11.3 文档解释业务模块共同发布与 Platform/Infrastructure 独立部署的区别，以及为何 Worker role 不等于微服务。
- [ ] G04-11.4 创建当前/目标 Deployment Unit Catalog、Module Manifest、Release Manifest 和 dependency criticality 矩阵。
- [ ] G04-11.5 创建单实例/多实例总体架构图、API/Worker 拓扑图和业务发布边界图。
- [ ] G04-11.6 创建启动状态机、role readiness 判定流程、Dispatcher claim/lease、backpressure 和 graceful shutdown 流程图。
- [ ] G04-11.7 创建 DB → Worker consumer → API producer → scheduler → cleanup 发布时序图和 V1/V2 consumer-first 图。
- [ ] G04-11.8 创建 failure/rollback 状态图与运行手册，覆盖 migration、schema、transport、worker crash、backlog 和 shutdown。
- [ ] G04-11.9 Mermaid 源文件与可直接查看的 SVG/PNG 一并保存，并完成渲染检查。
- [ ] G04-11.10 将每条运行规则映射到 manifest validator、startup validation、probe、测试、CI/CD、指标或人工审批。
- [ ] G04-11.11 更新架构索引、前置/总计划、数据库/Event/LayerGuard 子计划反向链接，并完成中英文一致性审查。

## Phase 12 — Gate 关闭与后续计划交接

- [ ] **Phase 12 完成**：Gate 04 已批准关闭，Event Dispatcher 和生产发布具有明确运行约束。

- [ ] G04-12.1 对照 DP1、DP3、DP4、DP5 附上 ADR、catalog/manifest、代码、测试、演练、probe 和文档证据。
- [ ] G04-12.2 确认五个业务模块仍为一个发布边界，而 API/Worker 角色和独立 infrastructure 没有伪装成业务独立部署。
- [ ] G04-12.3 向 Gate 02 交付 Migrator/schema readiness 与发布编排接口；两处顺序和 failure policy 必须一致。
- [ ] G04-12.4 向 Event 子计划交付 Runtime Role、instance identity、lease、shutdown、consumer-first、health 和 backpressure 规则。
- [ ] G04-12.5 向 LayerGuard 子计划交付 API/Worker Runtime Host 只能引用 Composition/host primitives 的编译期要求。
- [ ] G04-12.6 在 [`00-prerequisites.md`](00-prerequisites.md) 勾选 Gate 4 相关事项，仅在全部实施、验证与文档完成后操作。
- [ ] G04-12.7 记录未解决的生产平台特有参数、owner、到期日和验证环境，不使用永久默认值掩盖。
- [ ] G04-12.8 由架构、模块、Platform、数据库和运维负责人共同批准 Gate 关闭。

## Definition of Done

- [ ] G04-DD01 Deployment Unit、Module 和 Release Manifest 能准确区分共同业务发布与独立基础设施生命周期。
- [ ] G04-DD02 API/Worker/all Runtime Role 行为确定，生产可独立扩展 HTTP 与后台容量但业务版本继续锁步。
- [ ] G04-DD03 多实例 claim/lease、at-least-once、分区顺序和 crash recovery conformance 通过真实数据库 reference fixture，且 E3/E4 的真实 Dispatcher/Inbox 通过同一验收。
- [ ] G04-DD04 Hangfire client/server、identity、queue、WorkerCount 和 recurring authority 在多实例环境可验证。
- [ ] G04-DD05 startup-fatal、NotReady、Degraded、worker fatal 和 graceful drain 状态均有稳定行为与 reason code。
- [ ] G04-DD06 live/startup/ready/details 按 role 和 criticality 正确聚合，无副作用且不泄漏敏感信息。
- [ ] G04-DD07 database → Worker consumer → API producer → scheduler → cleanup 顺序及失败回退由 CI/CD 或演练验证。
- [ ] G04-DD08 backlog age、retry/dead-letter、lease、last success 和 backpressure 具有指标、阈值、告警与恢复手册。
- [ ] G04-DD09 中英文说明、架构图、流程图、状态图、时序图、失败矩阵和规则验证映射全部完成并审核。

## 回退与运行安全原则

- [ ] G04-R01 API/Worker role 切分失败时可暂时回到同版本 `all`，但必须保留多实例安全、唯一 identity、health 和 shutdown 规则。
- [ ] G04-R02 schema/migration 问题优先停止发布并 roll-forward；不自动执行 Down，也不让未验证实例开始 dispatch。
- [ ] G04-R03 Consumer-first 发布中即使 API 回退，也不得先删除或回退仍需处理 V2 backlog 的 Worker consumer。
- [ ] G04-R04 Dispatcher/transport 故障不删除 Outbox、不伪造成功；通过持久 retry、lease 接管和受控 backpressure 恢复。
- [ ] G04-R05 forced termination 必须依赖持久状态恢复，不能通过无限 shutdown 或 lease 隐藏无法停止的问题。
- [ ] G04-R06 health/readiness 配置回退不得把外部依赖放进 liveness，也不得通过始终 Healthy 掩盖 critical worker failure。
