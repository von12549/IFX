# Plan 04 模块边界、租户查询与 Owned Projection 设计

> 状态：PRE-READY（仓库实现与验证通过；具名职能审批、生产 RLS 和真实报表验收未完成）
> English: [Module boundaries, tenant queries and owned projections](module-boundary-evolution.en.md)
> 执行计划：[子计划 4](plans/04-module-boundary-evolution.md)
> 证据索引：[Plan 04 evidence](evidence/plan04/README.md)

## 1. 决策摘要

IFX 当前继续作为模块化单体交付。Auth、CRM、Registry、Transaction、Holdings 分别拥有业务能力、
Domain、DbContext 与 schema；共同 ApiHost、Worker 角色、物理数据库和共同 release 不改变这些
ownership。当前结论为 Auth/CRM/Registry/Holdings `retain`，Transaction `narrow-edge`。后者只允许
消费方外层 Adapter 依赖 CRM/Registry 的版本化 Contracts，Application 不得直接依赖外部模块。

四条 Active 边完全来自 G03 catalog：CRM → Transaction 与 Registry → Transaction 是最小同步
决策；Transaction → Holdings 与 Registry → Holdings 是版本化事实。B4 项目/namespace 图与 G03
协议图职责不同，必须同时绿色，不能相互替代。

## 2. 模块粒度与提取门槛

项目数、fan-in/out、共同提交和共同发布只提供复审信号，不自动证明应拆分。任何 Microservice
候选必须同时满足单一业务 owner、单一数据 owner、无共享 ACID、版本化协议、已知一致性模型、
独立安全边界和具名运行 owner 七个硬门槛。评分只排序，不能覆盖失败的硬门槛。

状态只能沿 `retain → observe → candidate → approved → executing → extracted` 的受控转换前进。
进入执行前必须有 Architecture、Module、Platform、Database、Security、Operations 的相应批准，
并完成 DP8 runtime/resilience 与 DP9 package cadence。失败或证据不足时保持模块化单体；不能以
共享 DbContext、跨模块事务或放宽 Contract 作为试验保留手段。

## 3. Tenant query 的可信边界

普通业务 Repository/Contract 接收非空 `Guid tenantId`，在入口调用 `TenantQueryGuard.Require`，并在
EF 查询中显式使用 tenant predicate。租户值必须来自 G05 可信 ExecutionContext，不允许 nullable、
default、隐式全局上下文或普通接口上的 bypass flag。当前选择显式 predicate；EF global query
filter 为 `not-selected`，因为它会引入不可见上下文与后台/迁移旁路风险。

跨租户平台查询只能进入独立命名的 `AcrossTenants` 接口，并同时满足 platform execution scope、
受信 actor、platform role allowlist、专用 permission、purpose、结构化 audit 与 500 行上限。五个
已登记 Auth 管理入口均带 owner、期限和负向测试。SQL Server RLS 为
`deferred-not-claimed`：生产连接身份、`SESSION_CONTEXT`、pool 清理、Migrator、break-glass、性能和
目标环境测试完成前不能宣称启用。

## 4. 跨模块读取与 projection ownership

跨模块 query 只有两条合法路径：本地版本化 Contract，或由查询用例 owner 拥有并完成注册审批的
owned projection。源模块只发布最小、版本化事实；不得暴露表、DbContext 或内部 Entity。跨
DbContext/table join 以及 projection 故障时的跨库回退均被禁止。

未来 projection 注册必须定义 schema version、`TenantId` 分区、Inbox/idempotency、顺序、freshness
目标及 eventual-consistency UI/API 语义；还必须定义 bootstrap、backfill、rebuild、catch-up、
checkpoint、reconciliation、drift detection 和源事件保留依赖。失败矩阵覆盖源/consumer 不可用、
重复、乱序、poison、部分重建和 schema 不兼容。恢复采用保留 durable source/checkpoint 后的
roll-forward。

G05 的 C0–C4 分类、最小化、访问、加密、保留、删除与日志约束独立适用于 projection；不能保存源
字段敏感超集，也不能成为租户删除旁路。当前实际批准报表 consumer 为 0，公共 projection schema
为 0。Holdings 的两个 event consumer 只证明 tenant envelope、durable delivery 与
`ConsumerId + EventId` 幂等，它们更新 Holdings-owned domain state，不是报表产品，也不证明重建、
保留或 consumer 验收。

## 5. 自动化、失败与回退

统一入口 `scripts/Test-Plan04Governance.ps1` 绑定 B4、G03、G04 和 Plan 04 决策 hash，并分别执行
模块图、GOV4、DP6、DB8、GOV3 validator。负向夹具要求未登记边、循环、未知 owner、hash drift、
硬门槛绕过、tenant 漏过滤、未授权旁路、跨 DbContext、重复效果、重建漂移和敏感超集均准确失败。

Phase 7 的完整复核为 1108/1108 solution tests、189/189 LayerGuard tests、39 个受控项目零违规。
规则与责任映射见 [rule-validation-map.json](evidence/plan04/rule-validation-map.json)，流程图见
[Plan 04 diagrams](diagrams/plan04/README.md)。输入/hash 不一致时停止判定并重新生成审核；不得修改
派生报告制造绿色结果。

## 6. 尚未关闭的事项

GOV4 与 DP6 的具名职能审批仍为 pending；Architecture、模块、Platform、Database、Security、
Operations、Reporting/Data 等角色不能由代码作者代签。DB5–DB7、GOV6、OPS2/OPS5、DP8/DP9 仍在
各自后续范围。故本设计仅代表仓库治理通过，整体保持 PRE-READY。
