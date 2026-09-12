# P05-S5 — 成员事实与授权失效

父提交：`b04fca9`；仓库验证日期：2026-09-12。目标环境数据审计和发布仍 pending。

现有 `auth.UserTenants` 是唯一成员来源，已有复合主键防止重复关系。用户启用、租户启用且 join 存在才构成有效成员；`PrimaryTenantId` 只是经成员校验的偏好。普通角色、RoleGroup、部门都要求同租户有效成员；GlobalRole 保持独立的平台关系。没有从角色或主租户反推、补建成员。

Users 的标量与身份映射、Tenancy 的成员映射、Access 的授予映射分别维护，仍由同一个 IAM DbContext/事务持久化。成员退出删除该租户的角色、组和部门关联，并清空相同主租户偏好。其他租户的关系保留。关系命令采用 ConsistentReadWrite/Serializable；所有 SaveChanges 重载在提交前检查持久化结果。并发授予与退出不能留下孤立授予，冲突方必须失败并重试完整用例，不能把部分写入当成功。外部 IdP 调用仍不占用长数据库事务。

`VerifiedIdentityFacts` 每个授权入口重新读取 IAM 当前事实，按可信执行租户筛选权限；HTTP claims 只提供经前置认证确认的本地主体与 MFA 信息，后台 user actor 从显式可信上下文识别。停用用户/租户、退出成员或撤销角色在下一次授权检查失效，无跨请求授权事实/决定缓存，不依赖异步清理。已通过授权并在执行中的操作不宣称可被即时中断。用户还可以认证自己的身份，但已退出租户的旧 token 不能恢复该租户访问。

HTTP PermissionAuthorizationHandler 同样调用 IAM PermissionChecker，删除旧任意 GlobalRole/permission claim 旁路。显式 tenant header 必须验证成员，包括平台管理员。平台跨租户清单保留原 `Platform.GlobalRole:manage` 权限、500 行上限和现有登记；目前该平台权限只由 PlatformAdmin 明确授予。没有引入新的跨租户权限或扩大 Support/Auditor 的绕过范围。内部成员管理额外验证操作租户和部门归属。

## 迁移与回滚边界

新增 `20260912101127_EnforceActiveTenantMembership`，只增加 `Tenants.IsActive bit NOT NULL DEFAULT 1`。扩展先于新 API/Worker；旧无歧义 join 原样保留，默认值维持既有租户状态。没有另建 Membership 表，没有业务推断式 backfill，重复运行迁移不重复添加关系。

发布前后运行 [只读成员审计](../../../../../scripts/sql/plan05-membership-audit.sql)，保存孤立角色、组、部门、跨租户组角色和错误主租户清单及五种关系的行数；歧义由目标数据 owner 审核处理。仓库 SQL 样本的升级、重复执行和失效验证通过，不代替 IAM0.4 的真实数据审计。validate 后才切换新读取逻辑；contract 阶段保留旧 join 与兼容窗口，不做破坏性清理。

停用租户后直接回退到忽略 IsActive 的旧程序会恢复访问，**不属于安全回退**。默认修复前进；回退演练应先隔离流量并确认停用状态，保留扩展列。生产自动 Down 继续禁止；临时库的结构回退与行为回退在 Phase 7 单独演练。

数据库清单工具同步修正 IAM 路径与显式 Auth→IAM 源码 owner 映射。历史五条 Auth migration 已逐条与 `f29ad32` 比较，只有命名空间改变，Up/Down 不变；[哈希衔接记录](phase5-migration-source-refresh.json)保存原、新源码哈希，既有风险审批元数据不变。新迁移按原门禁归类为 schema-lock/medium，未伪造高风险迁移批准。

## 验证

- [phase5-validation.json](phase5-validation.json)：最新完整程序集合并 **1212/1212，21 个程序集**；数据库 117、IAM Application 263、Integration 165。保留初次失败 TRX，不用筛选测试覆盖完整程序集结果。
- 新增 SQL 场景覆盖升级与重复运行、原子退出、主租户切换、HTTP/Worker 失效、绕过领域方法的持久化校验、并发授予/退出、旧孤立事实只报告不修复。领域与应用负向用例覆盖无成员授予、停用租户、跨租户组和内部成员操作。
- [phase5-guards.json](phase5-guards.json)：LayerGuard 190 项工具测试；49 项目、零违规、零豁免；G03/G04/G05、Plan 04 和迁移安全门禁通过。五个 EF 模型与 snapshot 一致。
- 首轮失败涉及测试 seed 重复权限、SQL 保留字、旧测试缺成员/跨租户组、旧迁移计数及清单工具的旧命名/哈希；对应修复和原始日志位于 `artifacts/plan05/phase5/`。跨租户权限更名被自动审批拒绝后已撤去，原策略未改变。

真实 IdP 联调、目标数据对账、具名协议批准、生产性能和发布均未执行。
