# G04 部署与运行边界

> 状态：PRE-READY（2026-09-08）  
> 权威输入：ADR-G04-001、`deployment/g04/*`、Gate 02 migration policy  
> 最终关闭仍依赖：Plan 02 E3/E4/E6、Gate 05、Plan 03 B2/B3/B4、生产演练与负责人批准；03-A1/B1 已回交

## 决策

| 编号 | 决策 |
|---|---|
| G04-D01 | Auth、CRM、Registry、Holdings、Transaction 五个业务模块共同形成 `ifx-backend` 发布边界；不能按副本选择模块版本。 |
| G04-D02 | 同一个不可变 `ifx-host` artifact 可运行 `api`、`worker` 或本地 `all`；角色是运行能力分离，不是业务微服务。 |
| G04-D03 | Frontend、SQL Server、Migrator、OPA、Cognito、SendGrid 可独立部署/托管，其生命周期不改变业务模块 ownership。 |
| G04-D04 | 启动先加载 manifest 并验证 Composition/endpoint，再由有界后台检查把 Alive/NotReady 转为 Ready。 |
| G04-D05 | 多 Worker 使用唯一 instance identity、短事务 claim、lease/renewal、rowversion 条件完成和 at-least-once；不承诺 exactly-once 或全局顺序。 |
| G04-D06 | SIGTERM 原子进入 Stopping，先拒绝新 claim/fetch/schedule/HTTP，再在递增预算内完成已接收工作；超时允许依赖持久状态强退。 |
| G04-D07 | live/startup/ready/details 语义分离。公开探针不做网络调用、不输出 contributor 异常；details 需要认证并读取缓存。 |
| G04-D08 | backlog 必须结合 age、类别、速率、dead-letter 和容量判断；backpressure 只阻断会扩大对应 module/event 积压的命令。 |
| G04-D09 | 发布顺序固定为数据库前置、Worker consumer、API producer、scheduler、观察、cleanup；失败立即停止且不自动 Down。 |

## 边界与 Manifest

Module Manifest 描述业务模块 identity、版本、Contracts、endpoint、schema、配置、runtime capability 和 shutdown 要求。Deployment Unit Catalog 描述可独立启动/部署的进程或依赖。Release Manifest 把同一个 Host artifact、五模块集合、数据库 migration、部署编排、backpressure 与失败矩阵哈希绑定起来。

因此，两个 API 副本可以独立扩容，但必须具有同一 release 和完整 required module set。Worker 不映射业务 HTTP，却仍链接并加载同版本模块 Composition/Infrastructure；这不会成为可独立版本化的微服务。

![部署边界](diagrams/deployment-boundary.svg)

## Runtime roles 与拓扑

`api` 只映射业务 endpoint，并注册 Hangfire client；`worker` 启动允许的后台执行能力且不映射业务 endpoint；`all` 是两者同版本并集，仅用于本地/集成测试，生产默认拒绝。Dispatcher、consumer 和 recurring scheduler 是独立 capability；在 E3 落地前保持关闭。

![运行拓扑](diagrams/runtime-topology.svg)

## 启动、健康与关闭

静态配置、manifest、required module、role 和 endpoint collision 错误是 startup-fatal。SQL/schema 等可恢复依赖只影响 readiness。`/health/live` 只检查本进程和 critical loop；`/health/startup` 表示静态初始化；`/health/ready` 读取 role-specific 缓存；`/health/details` 返回 release、role、instance、freshness 与稳定 reason，且必须认证。

关闭预算是 `10s operation < 20s handler < 30s lease < 40s process grace < 45s orchestrator kill`，另保留 2 秒 telemetry flush。生产值必须经目标平台负载演练确认。

![启动健康关闭](diagrams/startup-health-drain.svg)

## Dispatcher、backpressure 与发布

claim 在模块本地数据库短事务内完成，发送在事务外进行，broker ack 后才使用 owner/token 条件更新 delivered。发送后标记前崩溃可能重复，因此 EventId 必须稳定、Inbox 必须幂等。分区内只允许最早 sequence in-flight，不建立全局顺序。

![Dispatcher 与背压](diagrams/dispatcher-backpressure.svg)

consumer-first 发布要求 V2 Worker 先能消费 V1/V2，全部 Ready 后才允许 API 产生 V2。发生 API 回退时，只要存在 V2 backlog/replay，就保留 V2 Worker。cleanup 只在 observation 和零旧版本需求证据后执行。

![发布时序](diagrams/consumer-first-release.svg)

失败动作由版本化矩阵决定：停止、保留旧副本、接管、局部 backpressure 或有界强退；任何路径都不得删除 Outbox、伪造 delivered 或自动执行 Down。

![失败回退](diagrams/failure-rollback.svg)

## 规则到验证机制

| 规则 | 主要验证 |
|---|---|
| G04-D01/D02/D03 | ADR、Module/Unit/Release manifests、manifest validator、RuntimeProfile tests |
| G04-D04 | StartupBoundaryVerifier、StartupDependencyMonitor、startup tests、G04 guard |
| G04-D05 | SQL Server lease conformance、instance identity tests；E3/E4 重跑是最终条件 |
| G04-D06 | drain coordinator tests、Compose config、生产 SIGTERM 演练 |
| G04-D07 | health endpoint/snapshot tests、认证；Gate 05 sentinel 是最终条件 |
| G04-D08 | backpressure policy tests；E3/E6 真实指标与告警是最终条件 |
| G04-D09 | orchestration/failure validators；生产 release evidence 与批准是最终条件 |
| 编译期 host 边界 | LayerGuard 03-A1/B1 已绑定；B2/B3/B4 继续验证相同目标语义 |

## 运行手册与未关闭项

- Backpressure：[backpressure-recovery-runbook.md](backpressure-recovery-runbook.md)
- 失败/回退：[failure-rollback-runbook.md](failure-rollback-runbook.md)
- G04 ADR：[ADR-G04-001-deployment-runtime-boundary.md](ADR-G04-001-deployment-runtime-boundary.md)
- Phase 12 handoff 是最终 owner、revisit trigger 和所需证据的权威清单。PRE-READY 不等于生产批准。
