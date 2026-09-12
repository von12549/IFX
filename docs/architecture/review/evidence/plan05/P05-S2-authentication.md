# P05-S2 — Platform.Authentication 与 IAM.Identity

仓库实现完成；真实 IdP 联调与目标环境配置检查保持 pending。验收不把模拟 SDK/HTTP 测试写成云服务实测。

## 实现边界

新增 `Platform/Authentication` 的 Contracts、Runtime、Cognito/Auth0 Infrastructure 与 Composition。IAM 使用自己的消费接口及 `Infrastructure/Integrations/Authentication` 映射。账号注册/确认、密码认证、token 生命周期成为三个接口；Cognito SDK 已移出 IAM。Auth0 原先为占位实现，其专有账号 API 仍不声明支持；公共 OIDC 执行代码可复用，但不能据此声明 Auth0 全流程上线。

平台执行签名、issuer/audience、nonce、生命周期验证，以及 Discovery、授权码/PKCE 和 UserInfo 协议。它不引用 IAM、Repository、EF 或请求上下文。IAM.Identity 选择启用的 IdP、检查客户端配置、映射 `(Issuer, Subject)`、决定自动建号与本地账号准入。浏览器回调与 Bearer 均经过这条本地准入路径；本地停用账号不再因外部 token 有效而被接受。

Bearer 入口仅用未验证 issuer 作 IAM lookup key。平台为每次调用新建验证参数，成功后仅输出已验证 issuer/subject；外部 `user_id`、角色和租户 claims 不被继承。Claims transformation 的缺失配置、业务拒绝和异常路径均返回未认证主体。IAM 的启用状态每次读取，签名 metadata 可独立缓存。

## 显式行为改进与兼容

- 登录事务关联 state、随机浏览器 binding、nonce、PKCE verifier、issuer/client/回调配置指纹和过期时间。原子消费拒绝并发或重复 callback。PKCE verifier/client secret 不返回前端。
- Callback、logout redirect 必须精确匹配配置；前端 `redirect_to` 不再覆盖已配置地址。前端登录改为导航到 API，使 API 能设置 HttpOnly 事务 cookie，然后跳转 IdP。API 路径与成功 token 响应保持原有形式。
- 默认 Cognito 的空 audience/algorithm 旧配置仅在 issuer 精确匹配现有配置时，从既有 client ID 与 RS256 默认值构建验证快照；不修改数据库，也不让其他租户 IdP 继承该 client。Cognito access token 检查 `client_id` 和 `token_use=access`；OIDC ID token 检查 `aud` 和 nonce。依据：[AWS token verification](https://docs.aws.amazon.com/cognito/latest/developerguide/amazon-cognito-user-pools-using-tokens-verifying-a-jwt.html)。
- 其他 IdP 必须明确配置 audience/algorithm。需要 Cognito access-token 语义时，在既有 ClaimMapping JSON 中设置 `audienceClaim=client_id`；缺少配置会拒绝认证，不能继续沿用旧的跳过 audience 校验行为。
- UserInfo subject 必须匹配已验证身份。原有无 UserInfo 时建立受限 pending profile 的业务政策仍由 IAM 决定，不以相同 email 合并身份。并发 provisioning 只按同一 issuer/subject 重读已提交身份。
- 外部账号 SDK 操作日志不输出参数或原始异常；协议错误使用稳定结果。成功的认证技术调用不等于本地授权。

## 敏感协议与治理

G03 catalog 的 `infrastructureProtocols` 单独登记 IAM → Authentication 这一条技术依赖，逐字段记录 C1–C4 分类、用途、短暂保留和禁止日志/持久化的边界。既有四个公共业务协议及其 C4 禁令不变。LayerGuard 从同一个 catalog 派生依赖，校验哈希、消费者和敏感接口约束；不通过另建允许清单或豁免解决新依赖。

新增 catalog 负向测试拒绝 durable credential protocol、credential logging 和未知消费者；LayerGuard 测试证明即便重新计算 catalog 哈希，也不能把敏感协议改为持久化用途。

## 验证与限制

- .NET 最新完整程序集结果：**1142/1142，20 个程序集**，包含平台认证 22、IAM.Application 240、Integration 162、数据库 106。首次失败及重跑见 [测试证据](phase2-validation.json)。
- 平台测试覆盖真实 RSA token、错误签名/issuer/audience/nonce/subject、过期、metadata 不匹配/不可用、并发多 issuer；OIDC 测试覆盖 PKCE、回调配置、浏览器 binding、重放、并发一次消费、事务过期和 UserInfo subject。Cognito SDK 边界通过模拟请求验证注册、确认、refresh、revoke 和 logout。
- 前端相关四文件 **23/23**；TypeScript/Vite build 通过。构建中发现的已有测试导入/未使用变量及 Vite test 配置类型错误一并修复。
- LayerGuard **190/190**，44 个受管项目零违规、零豁免；G03 Phase 7、G05 Phase 9 和 Plan 04 统一治理通过，见 [门禁证据](phase2-guards.json)。

登录事务保持进程内短期存储。重启或回调到另一实例时拒绝并要求重新登录；未声明跨实例事务恢复，目标部署需保持登录事务的实例路由，或另行提供同等原子消费的共享存储。外部 IdP 的在线签名轮换、云端撤销传播、真实 callback allowlist 和配置审计在目标环境发布前验证。未读取目标数据库、未联系云 provider、未部署生产。

此阶段没有数据库 schema/migration 变化；新旧已持久化 Hangfire 类型兼容仍由 Phase 1 的显式别名保留。后续 Phase 3 提取授权技术执行，Phase 4/5 再规范政策和成员失效。
