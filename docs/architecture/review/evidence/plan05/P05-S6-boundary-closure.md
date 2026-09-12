# P05-S6 — 装配与边界收口

父提交：`c4e36c7`；日期：2026-09-12。

当前源码使用 `IamModuleInstaller`、`IamTransactionOwner`、`IamTransactionExecutor`、`AddIamModule`，宿主通过 IdentityHostBoundary 进行本地准入与 IdP 配置读取。邮件任务调度 port 只在 IAM 内使用；实际持久任务仍指向既有 EmailService/cleanup 接口。保留的旧类型、物理 schema、配置和逻辑 module ID 见 [兼容标识清单](compatibility-identifiers.json)，其中旧 Auth FQN 只允许出现在唯一具名 Hangfire alias。

IAM Composition 是平台认证/授权的唯一装配 owner；ApiHost/Worker 共用装配，HTTP 只增加入口配置。删除 Host 的重复 OPA wrapper 和重复认证注册。`IAbacPolicyCache`、无实际缓存的 invalidate 调用和 IdP cache version/signal 一并移除。IdP 信任仍每次读当前 IAM 配置，外部 discovery/JWKS 缓存由平台执行实现管理，不把已缓存的元数据当作本地 IdP 仍启用的证据。

HttpIdentityFacts 现在只提取主体和认证方法，不再实现成员/权限事实接口。生产 `IExecutionIdentityFacts` 唯一绑定 VerifiedIdentityFacts，成员、角色、权限和平台角色均从 IAM 获取；路由测试需要的 claims fixture 已明确移入测试程序集。生产没有 AllowAll/NoOp 授权替代。BuildingBlocks.Security 仅保留仍有真实跨模块消费者的 `ICurrentUser`、`IPermissionChecker` 与 `ForbiddenException`；政策模型、模板、resolver 属于 IAM，技术求值类型属于 Platform.Authorization，没有新增 Abstractions 项目。

新增 [安全边界门禁](../../../../../scripts/Test-Plan05SecurityBoundary.ps1) 并接入 LayerGuard CI：检查 Contracts 纯度、平台 Runtime 无业务/隐式 HTTP 依赖、当前成员事实绑定、内部 context 检查、HTTP 权限转交以及精确旧类型例外。附带 10 个正反 detector 用例；真实行为由独立 .NET/SQL 测试覆盖，静态模式匹配不代替授权验证。新装配测试分别检查 API/Worker 的单一注册和 Contracts 程序集引用；8 个 context 用例覆盖 actor/type/tenant/source/provenance 与缺上下文的拒绝。

数据库清单工具纳入 solution；CI 明确传递 Release configuration 给 EF snapshot 和 inventory 检查。迁移源哈希改为 UTF-8/LF 文本规范化，避免换行差异；[逐文件对照](phase6-migration-hash-normalization.json)记录原、新哈希，同一源码的 SQL 操作和既有风险批准元数据未变。G02 新清单仍为五 owner、50 entities、19 migrations；新增具名 G02 authority refresh，并让 Plan 04 验证器从治理锁读取当前哈希，原 Phase 0 frozen hash 和 B4 证据未覆盖。

验证结果：**1225/1225 .NET 测试，21 个程序集**，其中数据库 117、IAM Application 271、Integration 170。LayerGuard 190 测试、49 项目零违规/零豁免；G03、G04 runtime Phase 7、G05、Plan 04、迁移安全及新安全门禁通过，见 [测试证据](phase6-validation.json)、[门禁证据](phase6-guards.json)。早期编译遗漏、detector 对标准 SDK 声明的误报、旧项目文件再现和 G02 历史哈希漂移均已定位，原日志保留于 `artifacts/plan05/phase6/`。

两个新授权协议仍为 Proposed；未推断具名批准或生产验收。Phase 7 继续执行 Release 构建、发布顺序与安全回退演练并完成当前架构说明。
