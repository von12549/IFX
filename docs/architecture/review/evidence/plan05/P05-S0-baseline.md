# P05-S0：事实基线与迁移决策

> 执行日期：2026-09-12；基线：`f29ad32`；分支：`codex/plan05-iam-platform-security`。
> 执行：Codex，依据用户要求逐阶段实施。仓库验证与目标环境验收分别记录。

## 实际执行路径

| 场景 | 当前路径 | 目标所有者 |
| --- | --- | --- |
| 浏览器登录 | OAuthEndpoints → IOidcAuthService → Cognito/Auth0 OIDC | IAM.Identity 编排，平台执行协议 |
| API Bearer | DynamicJwtBearerEvents → IdpConfigurationService → OIDC signing keys → claims transformation | 宿主适配、平台验证、IAM 本地准入 |
| 本地身份 | Auth composition facade → GetOrProvisionUser → ProvisionSsoUser | IAM.Identity；外部身份以 issuer/subject 匹配 |
| 租户选择 | HTTP execution context → HttpIdentityFacts/ExecutionTenantSelection | 可信入口与 IAM 成员事实 |
| 资源授权 | 模块 handler → ResourceAuthorizationService → resolver/engine/OPA | 模块执行点、IAM.Access 编排、Platform 求值 |
| 策略管理 | Auth policy commands → PolicyDefinition repository → cache invalidation | IAM.Access |
| 邮件 | AuthEmailJobScheduler → IEmailService job | IAM 用例、平台邮件执行 |
| 定期清理 | IEmailVerificationCleanupService.CleanupExpiredTokensAsync | IAM.Identity；旧序列化类型需有界兼容 |

`Invoke-Plan05Inventory.ps1` 从固定 git commit 生成逐文件 owner 候选、DI/路由行、项目引用、migration、测试文件和权威目录切片。owner 候选用于审计，不取代 G03 catalog。重新运行不会将当前修改误写为历史基线。

## 名称与持久化兼容决策

| 对象 | Phase 1 决策 |
| --- | --- |
| src/Modules/Auth、程序集、namespace、测试项目 | 迁移为 IAM，调整真实引用及脚本 |
| Identity/Users/Authorization 目录 | Identity、Users、Access、Tenancy；授予操作归 Access |
| G03/G04 稳定模块 ID | 保留 `auth`，显示名称和代码 ownership 映射为 IAM；只有一个所有者 |
| auth schema、AuthDatabase、__EFMigrationsHistory | 保留；不因程序集更名改变数据库身份 |
| IfxDbContext、已应用 migration id、数据库对象/约束名称 | 保留；EF 历史 metadata 中旧实体名称按物理兼容检查处理 |
| API /auth、/oauth、/user、/tenant 等 | 保留；权限字符串与既有配置键保留 |
| issuer/audience、event schema/source identity | 保留已登记 wire identity；新能力独立登记，不重新使用 retired identity |
| email-verification-cleanup | 保留任务 ID；旧 application interface 类型通过显式、有限类型别名解析到新类型 |
| Email 投递任务 | 继续使用现有 Platform.Notifications.Contracts 类型，本阶段无需变更 |

不将旧 Auth 程序集保留为无限期兼容层。旧 job 解析只允许盘点到的类型并做真实 Hangfire 序列化往返测试，平台 BackgroundJobs 提供中立扩展点，由 IAM Composition 注册别名。

## 行为基线与后续差异

| 观察到的行为 | 结构阶段 | 行为阶段目标 |
| --- | --- | --- |
| User 已有 Tenants/Departments、PrimaryTenantId 和直接/组角色关系 | 保留表映射 | 成员与授予分离；PrimaryTenantId 不是成员证据 |
| 部分角色授予用例只校验角色租户，未校验目标用户成员资格 | 保存基线 | Phase 5 增加目标成员校验，不自动新增成员 |
| GetOrProvisionUser 已存在用户分支未显式检查 IsActive | 保存缺口 | Phase 5 每次本地准入校验停用状态 |
| claims transformation 在异常时可能返回原 principal | 保存缺口 | 提取认证链时关闭失败路径，回归明确标识行为修复 |
| DynamicJwtBearerEvents 修改共享 options 验证参数 | 保存并发风险 | Phase 2 使用每次请求独立验证参数 |
| GlobalAdmin 在共享授权服务直接放行 | 迁移至 IAM 政策保持既有结果 | Phase 4 显式管理入口/政策，普通租户强制隔离不被绕过 |
| 多 GlobalRole 取列表第一项 | 保留可复现基线 | Phase 4 明确角色组合，顺序不能改变结果 |
| 租户→平台→静态策略回退，部分数据库异常后继续回退 | 保存基线 | 只允许 NotConfigured 回退；Invalid/Unavailable 不授权 |
| 全局角色缓存 5 分钟；政策缓存 60 秒 | 保留现状记录 | 撤销类操作在下一受保护操作前以权威事实校验，不依赖 TTL 才失效 |
| Tenant 无停用状态字段 | 不虚构已有停用功能 | 本计划只规范现有删除/成员退出；新增租户停用产品流程不隐式引入 |

失效决策：本地 User 停用或成员退出后，后续受保护操作重新检查权威事实；已签发外部 token 的密码学有效性与本地访问权独立。已进行中的数据库事务按现有事务边界完成；后台任务在开始业务效果前复查主体/成员及资源，不继承过期请求权限。需要即时中断已在途事务属于另行设计范围。

ABAC 目标：平台强制约束 AND 所需权限 AND 适用 ABAC；租户只能定制授权范围内策略。多个已授予平台角色使用明确的允许组合，并始终满足强制约束；缺/坏策略和引擎失败不授权。具体政策迁移在 Phase 4 提供逐项差异与测试，不在 Phase 1 偷改。

## 数据范围与迁移前置

源码/EF metadata 确认存在 Users、UserTenants、UserDepartments、UserRoles、UserRoleGroups、RoleGroupRoles 及 PrimaryTenantId；现有 UserTenants 是迁移的成员事实来源。不会从角色或默认租户推断新增成员。

目标数据库未被指定，未读取生产连接配置或实际账户数据。`phase0-inventory.json` 明确记录 not-inspected。目标数据的数量、歧义及清理不声明完成；Phase 5 数据切换前运行只读 preflight，孤立和跨租户记录阻止切换。仓库中的隔离 SQL Server migration tests 不代表真实目标数据已经清洁。

## 验证与状态

具体命令和结果见 `phase0-validation.json`。原始输出位于 `artifacts/plan05/phase0/`，提交的摘要包含文件哈希。首次全套运行时 Docker 未运行，数据库容器测试失败；已启动 Docker 并在可访问其管道的执行环境单独重跑数据库测试，保留首次失败记录。

阶段状态：仓库基线可以支持独立结构迁移；目标数据库审计保持待执行。IAM0.4 不因源码盘点而勾选完成。

仓库验证：1108/1108（19 个测试程序集）；LayerGuard 189/189 且 39 个受管项目零违规；G03 Phase 7、G05 Phase 9、Plan 04 统一治理通过。误用历史 G05 Phase 0 的失败输出另行保留，实际验收使用现行 Phase 9。
