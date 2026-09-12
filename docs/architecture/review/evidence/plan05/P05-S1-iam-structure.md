# P05-S1 — IAM 名称与四子域迁移

已将 Auth 的五层项目、测试、solution、消费者与 Migrator 引用迁移到 `Modules/IAM`。IAM 仍是一个业务模块；Identity、Users、Access、Tenancy 为内部子域。Tenant/Department 与成员关系用例归 Tenancy，角色/权限/策略与授予用例归 Access。

稳定标识保持 `auth`（G03/G04 模块 ID、数据库 schema）；`AuthDatabase`、`IfxDbContext`、migration ID/history、API 路径、权限字符串与配置键不变。G03 中 `auth` 的代码名称唯一映射为 IAM。迁移目录改变导致 catalog 哈希变化，因此发布清单及其派生运行清单同步重建。

BackgroundJobs Composition 增加显式类型别名解析扩展，由 IAM 注册唯一已盘点的旧 `IEmailVerificationCleanupService` 类型。真实 Hangfire InvocationData 测试覆盖旧简单程序集名、版本限定名、参数保留及新任务序列化；未知类型继续走正常失败路径。ApiHost/Worker 的共用 Composition 注册保证两类宿主使用同一别名。

## 验证

- 完整回归最终为 **1110/1110，19 个测试程序集**。首次完整运行仅发布清单哈希测试失败，修复后完整数据库程序集 **106/106**，包括隔离 SQL Server 的安装、升级、legacy adoption 与回退演练。所有尝试保存在 [测试证据](phase1-validation.json)。
- 五个 DbContext 的 `has-pending-model-changes` 均通过；没有新增 DDL 或仅因命名变化生成 migration。
- LayerGuard 工具测试 **189/189**；无 baseline 扫描零违规后生成 Plan 05 的零条目 baseline，严格检查 **39 个受管项目、零违规、零豁免**。
- G03 Phase 7、G05 Phase 9、Plan 04 统一治理均通过，见 [门禁证据](phase1-guards.json)。

## 治理衔接

历史 B4 报告与 baseline 不变。当前源码图保存于 [Plan 05 dependency graph](current-dependency-graph.json)，Plan 04 从该图取得现行物理依赖，仍由 G03/G04 决定逻辑模块身份。Plan 04 校验器读取显式审核过的治理锁哈希，拒绝漂移；保留历史 Phase 0 输入，通过具名 refresh 记录 G03 代码名称变化。五模块边界、四个 Active 协议、原提取决策与 pending 审批均不变。

构建遗留的空目录或仅有 bin/obj 的目录不作为业务模块；任何非构建文件所在的未知模块仍被拒绝。CI 分别检查当前严格边界和保存的 B4 历史完成条件。

本阶段没有调整认证或授权政策。真实目标数据未审计、外部 IdP 未进行在线验证、未部署生产；Phase 0 的 IAM0.4 保持 pending。后续 Phase 2 才提取认证协议并验证信任边界。
