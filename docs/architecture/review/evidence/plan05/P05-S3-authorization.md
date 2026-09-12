# P05-S3 — 授权结构提取

源码父提交：`768a950`；日期：2026-09-12。本报告记录仓库验证，未部署目标环境。

## 实际调用路径

资源模块 Application 自有授权 Port → 本模块 Infrastructure Adapter → IAM.Contracts.V1 → IAM.Access → IAM 自有求值 Port → 平台 Adapter → Platform.Authorization.Runtime → OPA Provider。

- 五个模块各自声明资源事实和授权 Port；既有资源加载、受限查询和领域操作保持原位。四个外部消费者经版本化 IAM 契约调用，不再从容器共享授权实现。
- 入口 Adapter 显式携带 G05 可信上下文，IAM 校验登记消费者、上下文来源及租户一致性；请求不携带调用者声明的角色、权限或已授权标志。
- IAM 持有政策选择、模板目录及现有 GlobalRole 语义。平台仅处理已选快照：参数替换与远程求值是两个独立步骤。HTTP 环境读取留在 IAM 外层；无 HTTP 时网络属性缺失，不能假设内部网络。
- Contracts 使用固定属性 schema；OPA envelope、snake_case 操作符及固定路径只存在于 OPA Provider。IAM Adapter 为政策内容计算版本摘要；不缓存决定。
- 删除 BuildingBlocks 中 ABAC/OPA 运行代码以及未被生产调用的直接 decisionPath 入口；移除其他模块重复注册的政策解析器。

## 行为对账与明确差异

保持的基线：租户政策解析顺序、GlobalAdmin 例外、多个全局角色的第一项选择，均由 IAM 实现并在测试中固定，下一阶段显式改进。现有列表查询过滤及领域状态机不改变。

安全差异：原 `Opa:Enabled=false` 的无条件放行及 `FailClosed=false` 的故障放行被移除，分别返回 Indeterminate；缺参数、未知属性和空快照也返回 Indeterminate，IAM/资源模块拒绝。调用方取消继续传播。此项遵循计划第 6 节“无默认 Allow/NoOp authorization”要求，不宣称全部旧配置下结果相同。依赖关闭 OPA 的本地运行需要启用 OPA；测试仅在显式测试夹具内替换授权能力。

## 验证

详见 [测试记录](phase3-validation.json)、[门禁记录](phase3-guards.json)。

- 完整 solution 构建通过。21 个测试程序集合计 **1177/1177**：首次完整运行的平台新测试有一处 C# 测试代码编译错误，修复后重跑该程序集 **21/21**；其他完整程序集结果保留，包含 SQL **106/106**、集成 **171/171**、IAM Application **245/245**。
- 新增真实 Adapter 的四模块允许/拒绝映射、可信链、无上下文后台拒绝；IAM 政策选择及拒绝后不执行；平台报文兼容、六类操作符、参数缺失、未知字段、取消、故障与关闭状态拒绝。平台不因 `PlatformAdmin` 名称绕过求值。
- LayerGuard **190/190**，**49** 个受管项目、**0** 违规；无 baseline 豁免。G03 Phase 7、G05 Phase 9、Plan 04 统一门禁通过。
- 主要命令：`dotnet test IFX.sln --logger trx`、平台测试定向重跑、`dotnet test mcp/LayerGuard/LayerGuard.slnx --no-restore`、既有 G03/G05/Plan04/LayerGuard 入口。原始日志与 TRX 位于 `artifacts/plan05/phase3/`。

## 治理与剩余工作

新增两个协议登记保持 **Proposed**，不虚构命名审核人的批准。源核对支持实际登记的平台项目，兼容快照从当前源码重新提取；G03 的逻辑 `auth` 映射到代码 owner `IAM`，provider 边和 consumer 边一致。Plan 04 新增四条 IAM 授权消费边，五个数据 owner 保持不变，无同步依赖环。G05 保留原 165 字段基线，另核对新增 35 个字段。历史 B4 证据未重写。

Phase 4 仍需政策分类、组合、故障及缓存语义；Phase 5 仍需成员与停用失效。真实 IdP、目标数据审计和部署状态继续 pending。当前 Worker 没有凭空取得用户身份的后门；后台业务授权必须提供可信执行上下文及可验证主体事实。
