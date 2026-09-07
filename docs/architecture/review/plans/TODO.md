# 后续架构讨论 TODO

> 状态：Backlog
> 目的：记录本轮 Contracts / Adapters / Events / LayerGuard 计划之外，讨论中已经识别但尚未形成完整实施计划的事项。
> 使用方式：每一项进入实施前应补充现状证据、目标决策、独立计划、负责人和验收标准。
> 已提取前置项：TX1–TX5、DB1–DB4/DB9–DB11、GOV1/GOV2/GOV5、DP1/DP3/DP4/DP5、OPS1/OPS3 已移动至 [`00-prerequisites.md`](00-prerequisites.md)，不在本 TODO 重复维护。其他已计划化事项记录在下表，也不再保留第二套进度复选框。

## 已提取或合并记录（不再作为独立 backlog）

| 原事项 | 唯一实施/验收位置 | 合并原因 |
| --- | --- | --- |
| TX8 | [`00-G01-transaction-boundary.md`](00-G01-transaction-boundary.md) | 事务 ownership、嵌套事务、重试与幂等语义已经是 Gate 01 的主体内容。 |
| DP2 | [`00-G04-deployment-runtime-boundary.md`](00-G04-deployment-runtime-boundary.md) | Module Manifest 已由 Gate 04 定义并验收。 |
| DP7 | [`01-contracts-adapters-refactor.md`](01-contracts-adapters-refactor.md) C5.4 | 进程内 Adapter 的远程替换接缝属于 Contracts/Adapters 重构。 |
| OPS4 | [`00-G03-contract-event-governance.md`](00-G03-contract-event-governance.md) | 权威目录、依赖图与 waiver 生命周期统一由 Gate 03 治理。 |
| NEXT1 | [`00-G02-database-boundary.md`](00-G02-database-boundary.md)；[中文基线](../gates/G02/database-boundary.zh-CN.md) / [English baseline](../gates/G02/database-boundary.en.md) | 数据库边界评审、实施计划与中英文图文基线已完成；最终关闭仍按计划接收 E2/E4 证据。 |
| NEXT2 | [`00-G01-transaction-boundary.md`](00-G01-transaction-boundary.md) | 事务边界评审及计划已完成。 |
| NEXT3 | [`00-G04-deployment-runtime-boundary.md`](00-G04-deployment-runtime-boundary.md) | 部署/运行边界评审及计划已完成。 |

## Topic 1 — 数据库边界：独立 DbContext、migration 与 schema

已实施的 DB1–DB4、DB9–DB11 以 [G02 Gate Plan](00-G02-database-boundary.md)、
[ADR-G02-001](../gates/G02/ADR-G02-001-module-database-ownership.md) 和
[G02 双语基线](../gates/G02/database-boundary.zh-CN.md)为准。以下项目保持为后续范围。

- [ ] **Topic 1 完成**：全部事项已转为正式计划或有证据地完成。

- [ ] DB5 评估生产环境每模块独立数据库 role/credential 与 schema 权限；当前共享高权限连接不构成强隔离。
- [ ] DB6 明确“不建立跨模块数据库 FK”的完整生命周期协议，尤其是 Tenant 删除/停用后其他模块数据的处理。
- [ ] DB7 设计 `TenantDeleted`/`TenantDeactivated` 等事实事件、软删除/保留策略和孤儿数据 reconciliation。
- [ ] DB8 建立 tenant-aware Repository/Contract 规范，并评估 global query filter 或数据库 RLS 的适用性与旁路风险。
- [ ] DB12 定义模块拆分为独立数据库时的数据复制、报表、备份恢复与迁移策略。

## Topic 2 — 事务边界：模块本地事务与跨模块一致性

- [ ] **Topic 2 完成**：全部事项已转为正式计划或有证据地完成。

- [ ] TX6（Owner：Architecture + Registry/Transaction Application）评估 KYC 与 Class 状态“先查后写”的 TOCTOU 风险，按业务需要采用 reservation、version token、有效期或最终补偿。
- [ ] TX7（Owner：Architecture + 各 owning module Application）为需要跨模块完成的业务流程定义状态机、超时、补偿、人工干预和审计，不引入分布式数据库事务。
- [ ] TX9（Owner：Infrastructure + Test Engineering）为 TX7 的跨模块状态机与补偿流程添加故障注入，覆盖补偿失败、超时和人工恢复；本地事务、消息崩溃与重复投递测试分别由 Gate 01 和事件子计划负责。

## Topic 3 — 部署边界：单一 ApiHost 的模块化单体

- [ ] **Topic 3 完成**：全部事项已转为正式计划或有证据地完成。

- [ ] DP6 定义未来 Microservice 提取门槛：团队 ownership、扩缩容、发布频率、故障隔离、数据 ownership 与合规需求。
- [ ] DP8 设计拆分时的认证、服务发现、超时、重试、熔断、可观测性与 schema/version rollout。
- [ ] DP9 在正式进程外拆分时设计独立 package registry、版本节奏、兼容窗口与弃用策略，避免共享 Contracts package 形成 lockstep deployment。

## Topic 4 — 模块边界与公共能力治理

- [ ] **Topic 4 完成**：全部事项已转为正式计划或有证据地完成。

- [ ] GOV3 为跨模块报表和查询选择专用 read model/projection，禁止通过跨 DbContext join 绕过模块边界。
- [ ] GOV4 审核模块粒度与依赖方向，识别高耦合循环是否意味着边界划分错误。
- [ ] GOV6 在 DB6/DB7 与 Gate 05 隐私规则基础上，建立租户生命周期、数据保留、隐私删除和审计的跨模块责任矩阵。

## Topic 5 — 可观测性与运行治理

- [ ] **Topic 5 完成**：全部事项已转为正式计划或有证据地完成。

- [ ] OPS2 在 Gate 04/05 与事件子计划定义的指标契约之上，设定模块级 SLI/SLO、error budget、告警责任和持续复审节奏。
- [ ] OPS5 建立跨 Gate 的定期 game day；复用各 Gate runbook，联合演练消息积压、schema 不兼容、migration 失败和跨租户风险。

## Topic 6 — 计划维护

- [ ] **Topic 6 完成**：全部事项已转为正式计划或有证据地完成。

- [ ] NEXT4 将已批准事项从本 TODO 移入独立计划，并在此保留反向链接与完成日期。
