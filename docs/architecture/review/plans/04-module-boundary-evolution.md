# 子计划 4：模块边界演进与租户查询治理

> 状态：PRE-READY — Phase 0、1、4–8 的仓库工作已完成；Phase 2、3、7、8 的完成状态仅等待具名职能审批，生产能力未声明
> 上级计划：[`00-master-plan.md`](00-master-plan.md)
> 来源：[`TODO.md`](TODO.md) Topic 1、3、4 的当前阶段可执行目标
> 前置证据：Gate 02 module-owned DbContext/schema、Gate 03 权威 provider/consumer graph、Gate 04 共同业务发布边界、Gate 05 tenant/privacy policy、LayerGuard B4 严格依赖图
> 执行时点：可在 Plan 02 生产平台决策和目标环境证据等待期间独立推进；不得把本计划的仓库结论冒充生产 RLS、Microservice 拆分或真实报表上线证据

## 提取范围与唯一验收位置

| 原 TODO | 本计划唯一实施/验收位置 | 本计划中的完成含义 |
| --- | --- | --- |
| GOV4 | Phase 1–2、6–8 | 用源码、项目图、namespace 图和协议图审计模块粒度/依赖方向，形成逐模块保留、收窄、重划或候选提取结论并自动验证。 |
| DP6 | Phase 3、6、8 | 定义含硬门槛、评分、证据和审批的 Microservice 提取政策；不要求也不授权实际拆分。 |
| DB8 | Phase 4、6–8 | 建立 tenant-aware Repository/Contract 规范，完成 global query filter/RLS/显式过滤的适用性与旁路风险决策，并治理当前仓库。 |
| GOV3 | Phase 5–8 | 选定跨模块查询的 owned projection/read-model 模式，禁止跨 DbContext join，并定义重建、对账、隐私和生命周期规则。 |
| NEXT4 | 本计划创建与 TODO 反向链接 | 已批准的当前阶段事项只有本计划一套进度清单；TODO 不再重复维护复选框。 |

## 范围边界

本计划解决四个相互依赖的问题：当前模块边界是否合理、什么证据足以触发未来进程外提取、租户查询如何
fail closed，以及跨模块读取如何通过 owned projection 实现。它不增加当前业务功能，也不以“未来可能拆分”
为理由提前引入网络调用或分布式复杂度。

明确不在本计划内：

- 不创建或部署 Microservice；DP8/DP9 仍在 TODO，只有具体提取候选通过 DP6 后才启动。
- 不配置生产数据库 role/credential 或宣称 RLS 已部署；DB5 仍等待目标平台。
- 不决定 Tenant 删除、法律保留期限或隐私删除责任；DB6/DB7/GOV6 仍等待业务、Legal/Data Owner 决策。
- 不臆造不存在的跨模块报表需求；没有已批准 consumer 时只交付 projection policy 和 reference conformance。
- 不设置生产 SLO/error budget，也不执行 game day；OPS2/OPS5 仍等待真实流量和 production-equivalent 环境。

## 决策原则

1. 模块是业务 ownership 和数据事实边界，不由项目数、namespace 数或容器数单独决定。
2. “可提取”不等于“应提取”；提取必须同时通过业务、数据、协议、运行、团队和合规硬门槛。
3. 租户 scope 必须来自可信 ExecutionContext 或显式 platform scope，不能由 nullable/default tenant 修复。
4. 普通 tenant query 默认要求不可遗漏的 tenant predicate；跨租户操作必须使用独立、受权、可审计入口。
5. 跨模块读取不直接 join 其他模块 DbContext/table；由拥有者发布事实，查询 owner 维护专用 projection。
6. LayerGuard 继续负责静态边界；tenant 值传播、查询行为、projection 幂等和重建由专用测试/validator 负责。

## 目标状态

```text
Gate 03 capability/data ownership + B4 project/namespace graph
                              |
                              v
                 module granularity decision
                    /                    \
                   v                      v
       remain modular-monolith      extraction candidate
       narrow approved edges        must pass DP6 hard gates
                   |
                   v
 trusted tenant scope -> tenant-aware Repository/Contract
                   |
                   +---- local module query
                   |
                   +---- cross-module fact -> owned projection -> report/query
                                               |
                                               v
                                  rebuild + reconciliation + privacy controls
```

## Phase 0 — 冻结范围、证据和验收语义

- [x] **Phase 0 完成**：来源、基线、owner、非目标和完成语义均已冻结。证据：[`P04-S0`](../evidence/plan04/P04-S0-phase0-baseline.md) 与 [`machine status`](../evidence/plan04/phase0-baseline-status.json)。

- [x] ME0.1 保存当前 Git commit、LayerGuard 版本、B4 report/dependency graph hash、G03 catalog/report hash 和 module manifest hash。
- [x] ME0.2 确认权威输入分别由 G02、G03、G04、G05 和 LayerGuard 拥有，本计划只引用或生成派生视图，不复制 ownership/provider graph。
- [x] ME0.3 记录 Architecture、Database、Security、各模块 Application、Reporting/Data 和 LayerGuard repository delivery owner；所有最终职能审批仍为 `pending`，不得由交付责任推断审批。
- [x] ME0.4 建立范围清单，明确 GOV4、DP6、DB8、GOV3 是唯一活动目标，TX6、DB5–DB7/DB12、DP8/DP9、GOV6、OPS2/OPS5 不被隐式纳入。
- [x] ME0.5 定义“设计完成”“仓库治理完成”“生产验证完成”的不同语义；本计划不得用设计证据替代生产验证。
- [x] ME0.6 保存机器可读状态和 baseline report，未执行的检查显示 `pending`，不得默认通过。

## Phase 1 — 建立模块粒度与依赖事实基线

- [x] **Phase 1 完成**：模块、数据、协议和运行依赖事实均可由权威输入重建。证据：[`P04-S1`](../evidence/plan04/P04-S1-module-boundary-inventory.md) 与 [`machine status`](../evidence/plan04/phase1-inventory-status.json)。

- [x] ME1.1 从 G03 catalog 生成 capability、data fact、sync Contract、Event provider/consumer 边，不手工维护第二张协议图。
- [x] ME1.2 从 B4 dependency graph 生成 project 与 namespace edge，区分同模块层间依赖、合法跨模块 Contract/Event 边、Platform 依赖和 host composition。
- [x] ME1.3 将 Auth、CRM、Registry、Transaction、Holdings 的 schema、runtime capability、endpoint group 和发布版本与 G04 module manifest 对账。
- [x] ME1.4 盘点跨模块同步调用、异步事实、共享原语、共同变更热点和未登记 runtime/config/data coupling。
- [x] ME1.5 计算每模块 fan-in/fan-out、同步/异步边数量、变化耦合、数据 ownership 清晰度和独立测试能力；指标只用于审查，不自动决定拆分。
- [x] ME1.6 对未识别项目、未知模块、catalog/graph 漂移、跨 schema 数据访问或无法归属的边采用 fail-closed。
- [x] ME1.7 保存 machine-readable inventory、依赖图和人类可审查摘要，并验证可重复生成。

## Phase 2 — GOV4 模块粒度与依赖方向审计

- [ ] **Phase 2 完成**：GOV4 的逐模块结论、风险、owner 和复审触发条件均已批准并有证据。

- [x] ME2.1 验证同步环、异步反馈环和 mixed cycle；区分业务流程回路与编译期循环，不以“当前为零”替代未来门禁。
- [x] ME2.2 审核 CRM → Transaction、Registry → Transaction、Transaction/Registry → Holdings 的方向是否与 capability/data ownership 一致。
- [x] ME2.3 识别高 fan-in/out、共同发布热点、共享数据假设、跨模块变更频率和 owner 重叠；记录是否意味着边界错误或仅是合法协作。
- [x] ME2.4 为每个业务模块给出 `retain`、`narrow-edge`、`revisit-boundary` 或 `extraction-candidate` 结论，不允许无证据的 `split-now`。
- [x] ME2.5 对 `revisit-boundary` 建立问题、负责人、期限和修复选项；当前审计无 `revisit-boundary` 结论；不得用 shared DbContext、shared transaction 或公共 Domain model 缓解耦合。
- [x] ME2.6 定义新增协议边、循环、owner 变化、数据 ownership 冲突和高频联合修改的复审触发条件。
- [ ] ME2.7 Architecture 与受影响模块 owner 审核报告；GOV4 仅在所有模块都有具名结论时关闭。

## Phase 3 — DP6 Microservice 提取门槛

- [ ] **Phase 3 完成**：提取政策可执行、可审计，并明确当前模块化单体仍是默认部署选择。

- [x] ME3.1 建立硬门槛：单一业务 owner、单一数据 owner、无共享 ACID 要求、版本化协议、已知一致性模型、独立安全边界和具名运行 owner。
- [x] ME3.2 建立证据维度：团队自治、扩缩容差异、发布频率、故障隔离收益、数据迁移复杂度、延迟/可用性预算和合规要求。
- [x] ME3.3 定义评分仅用于排序；任一硬门槛失败时，即使总分较高也不得提取。
- [x] ME3.4 要求候选提供现状基线、预期收益、额外运行成本、契约/数据迁移、回退路径和“保持单体”的比较方案。
- [x] ME3.5 定义从 `retain` → `observe` → `candidate` → `approved` → `executing` → `extracted` 的状态机和批准权限。
- [x] ME3.6 定义批准后才触发 DP8/DP9；认证、服务发现、resilience、独立 package cadence 未设计前不得进入执行态。
- [x] ME3.7 建立 decision-record schema、正反 fixture 和 validator，拒绝缺 owner、缺数据边界、共享事务或无回退的提取申请。
- [ ] ME3.8 Architecture、模块 owner、Platform、Database、Security 和 Operations 批准政策；批准政策不代表批准任何具体模块拆分。

## Phase 4 — DB8 tenant-aware Repository / Contract 规范

- [x] **Phase 4 完成**：tenant query 默认策略、例外、旁路和自动化验证均已实现。证据：[`P04-S4`](../evidence/plan04/P04-S4-db8-tenant-query-governance.md) 与 [`machine status`](../evidence/plan04/phase4-tenant-query-status.json)；SQL Server RLS 仍为 `deferred-not-claimed`。

- [x] ME4.1 盘点所有模块 Repository/Contract/query 的 tenant 参数、predicate、nullable scope、platform scope 和跨租户管理入口。
- [x] ME4.2 定义 tenant-scoped Repository 方法必须接收非空 tenant identity，并在数据查询中显式约束；禁止默认租户、空值回退和仅靠调用方口头约定。
- [x] ME4.3 定义 platform/cross-tenant 查询使用独立命名接口、独立权限、purpose、审计和有界结果，不复用普通 tenant method 的 bypass flag。
- [x] ME4.4 评估 EF global query filter：覆盖收益、后台作业/迁移/管理路径、测试可见性、`IgnoreQueryFilters` 旁路和隐式上下文风险。
- [x] ME4.5 评估 SQL Server RLS：连接身份/SESSION_CONTEXT、connection pooling、Migrator、运维 break-glass、性能和测试成本；记录采用、延后或拒绝决定及复审触发条件。
- [x] ME4.6 建立允许的 bypass registry，至少包含 owner、purpose、权限、审计、最大范围、到期和负向测试；普通代码不得直接使用旁路 API。
- [x] ME4.7 修复当前范围内违反最终规范的 Repository/Contract/query，并为同租户、跨租户、缺失 tenant、伪造 tenant 和 platform scope 添加测试。
- [x] ME4.8 增加静态/语义 validator；未识别查询模式报告为人工审查项，扫描失败不得绿色通过。

## Phase 5 — GOV3 跨模块 read model / projection

- [x] **Phase 5 完成**：跨模块查询的唯一允许模式、ownership 和生命周期已建立并自动验证；当前无批准 consumer，因此未创建公共 schema、未声明报表产品。证据：[`P04-S5`](../evidence/plan04/P04-S5-gov3-owned-projection.md) 与 [`machine status`](../evidence/plan04/phase5-projection-status.json)。

- [x] ME5.1 盘点当前与已批准的跨模块报表/查询 consumer；结果为零，没有创建公共 projection schema。
- [x] ME5.2 选择由查询用例 owner 管理的独立 read model/projection；源模块只发布最小版本化事实，不暴露表、DbContext 或内部 Entity。
- [x] ME5.3 定义 projection schema、tenant partition、Inbox/idempotency、顺序、freshness、eventual-consistency UI/API 语义和 schema version。
- [x] ME5.4 定义 bootstrap/backfill、全量重建、增量 catch-up、checkpoint、reconciliation、漂移检测和源事件保留依赖。
- [x] ME5.5 定义源模块/consumer 不可用、重复、乱序、poison、部分重建和 schema 不兼容时的失败与恢复。
- [x] ME5.6 应用 G05 最小化、C0–C4 分类、访问、加密、保留、删除和日志规则；projection 不成为隐私删除旁路。
- [x] ME5.7 以现有 Holdings event consumer 作为可靠投递/幂等参考，并明确它不是跨模块报表产品，也不自动满足新 projection 的 consumer 验收。
- [x] ME5.8 建立 architecture decision 和 registration schema；任何跨模块 query 必须选择 local Contract 或 registered projection，禁止跨 DbContext/table join。

## Phase 6 — 自动化治理与负向证明

- [x] **Phase 6 完成**：四项目标的关键规则均有自动化正反证据并进入统一验证入口。证据：[`P04-S6`](../evidence/plan04/P04-S6-automated-governance.md) 与 [`machine status`](../evidence/plan04/phase6-governance-status.json)。

- [x] ME6.1 新增 Plan 04 validator，绑定 B4 graph、G03 catalog、G04 module manifest 和本计划决策 artifact 的 hash。
- [x] ME6.2 为未登记跨模块引用、dependency cycle、未知 module owner 和 catalog/graph drift 添加失败 fixture。
- [x] ME6.3 为不满足硬门槛的提取申请、评分替代硬门槛、缺失回退和未经批准状态跃迁添加失败 fixture。
- [x] ME6.4 为漏 tenant predicate、nullable/default tenant、普通接口 bypass、未授权 cross-tenant query 和隐式 tenant context 添加失败测试。
- [x] ME6.5 为跨 DbContext/table join、未登记 projection、重复业务效果、重建漂移和敏感字段超集添加失败测试。
- [x] ME6.6 验证 LayerGuard、专用 validator 和行为测试职责互补，任何一侧绿色结果不能掩盖另一侧失败。
- [x] ME6.7 将验证接入本地/CI，上传 machine-readable reports；输入缺失、hash 漂移或扫描异常必须失败。

## Phase 7 — 仓库采用与证据收口

- [ ] **Phase 7 完成**：仓库 reconciliation 与全套验证已通过，但 GOV4/DP6 具名职能审批仍为 pending，因此不把政策称为“已批准”。证据：[`P04-S7`](../evidence/plan04/P04-S7-repository-reconciliation.md) 与 [`machine status`](../evidence/plan04/phase7-reconciliation-status.json)。

- [x] ME7.1 对五个模块运行 GOV4 审计；当前无 `revisit-boundary` 发现，五个具名结论均已记录。
- [x] ME7.2 使用 DP6 policy 评估当前模块；默认结论保持 modular monolith，当前无候选获批。
- [x] ME7.3 对全部 tenant-aware Repository/Contract/query 执行 DB8 reconciliation，违规为零，五个合法管理例外均有 owner、期限、权限、审计和范围上限。
- [x] ME7.4 对当前跨模块查询执行 GOV3 reconciliation，证明不存在跨 DbContext join；当前无批准 projection，Holdings 仅为 reference-only。
- [x] ME7.5 运行 targeted、module、integration、database-boundary、LayerGuard 和全解方案测试；19 个 test assembly 共 1108/1108 通过，LayerGuard 189/189 且 39 个项目零违规。
- [x] ME7.6 记录 global query filter 为 `not-selected`、RLS 为 `deferred-not-claimed` 及生产复审条件。
- [x] ME7.7 将 GOV4、DP6、DB8、GOV3 结果回写 G02/G03/G04/G05 evidence handback，且所有 `gateClosureChanged` 均为 `false`。

## Phase 8 — 架构、规则与关闭文档化

- [ ] **Phase 8 完成**：中英文设计、图、规则、证据与计划索引均已完成，但 ME8.7 具名批准仍为 pending，因此整体保持 PRE-READY。证据：[`evidence index`](../evidence/plan04/README.md) 与 [`machine status`](../evidence/plan04/phase8-documentation-status.json)。

- [x] ME8.1 编写完整中文设计，解释模块粒度、提取门槛、tenant query 和 projection ownership。
- [x] ME8.2 编写语义一致的英文设计，并建立双向链接。
- [x] ME8.3 保存当前模块/协议/数据依赖图和模块粒度决策图。
- [x] ME8.4 保存 Microservice extraction decision flow/state 图，标明硬门槛、评分、批准和 DP8/DP9 handoff。
- [x] ME8.5 保存 tenant query trust/bypass flow 和 projection normal/rebuild/reconciliation 流程图。
- [x] ME8.6 保存规则到 LayerGuard、validator、测试、owner 和 Gate evidence 的映射。
- [ ] ME8.7 记录所有具名、带日期批准；缺少批准时本计划保持 PRE-READY。
- [x] ME8.8 更新总计划、计划索引和 TODO 提取记录；未恢复第二套进度复选框。

## 完成标准（Definition of Done）

- [x] ME-D01 GOV4 对每个业务模块给出有证据、owner 和复审条件的粒度/方向结论。
- [x] ME-D02 权威协议图与项目/namespace 依赖图可重复生成，未知边、循环和输入漂移 fail closed。
- [x] ME-D03 DP6 同时包含不可绕过的硬门槛、证据评分、状态机、批准和回退要求。
- [x] ME-D04 没有具体模块因为完成 DP6 policy 而被误报为已批准或已提取。
- [x] ME-D05 tenant-scoped Repository/Contract/query 默认 fail closed；跨租户能力只能经独立、受权、审计和有界入口。
- [x] ME-D06 global query filter 与 RLS 有明确决定、风险、owner 和复审触发条件，未部署项显示 `not-claimed`。
- [x] ME-D07 跨模块读取只使用批准的同步 Contract 或 owned projection，不直接 join 外部 DbContext/table。
- [x] ME-D08 任何未来 projection 注册必须具备 tenant partition、幂等、版本、重建、对账、失败恢复和 G05 数据生命周期规则；当前无批准 projection，不虚构产品实例。
- [x] ME-D09 核心规则有正反测试并进入 CI；LayerGuard、validator、行为测试之间没有责任空洞。
- [ ] ME-D10 中英文文档、架构/流程/状态图、机器可读报告、Gate 回交和具名批准完整。

## Gate 回交与后续触发

- **G02**：接收 tenant-aware query/RLS 评估和 projection 数据 ownership；不替代 DB5 production credential 或 DB6/DB7 lifecycle 证据。
- **G03**：继续拥有 module/capability/provider/consumer catalog；新增 projection protocol 必须按其版本和 lifecycle 流程登记。
- **G04**：接收 DP6 提取政策；只有具体候选获批后才由 DP8 定义进程外 runtime/resilience。
- **G05**：接收 tenant bypass、projection 字段和数据生命周期检查；GOV6 仍负责跨模块租户删除责任矩阵。
- **DP8/DP9**：仅在某个候选通过 DP6 并获得具名批准后，从 TODO 提取为独立执行计划。

## 安全与回退原则

- [x] ME-R01 新 tenant guard 造成兼容问题时，只能回退到上一条已批准的显式 tenant policy，不得回退到默认/空 tenant。
- [x] ME-R02 projection rollout 失败时停止新消费、保留 durable source/checkpoint，并通过修复后重建或 roll-forward 恢复，不跨库直接查询兜底。
- [x] ME-R03 提取评估或试验失败时默认保持当前 modular monolith；不得为保留试验成果而放宽 Contract、数据或事务边界。
- [x] ME-R04 任何治理 artifact/hash 不一致时停止判定，重新生成并审核，不手工修改派生报告制造绿色结果。
