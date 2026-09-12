# 子计划 5：Auth → IAM 与平台认证、授权能力拆分

> 状态：Phase 0–7 仓库实施与隔离验证完成；IAM0.4 目标数据审计、真实 IdP 联调、协议准入及目标发布/回退验收待执行，详见总验收。
> 编写日期：2026-09-12；源码观察基线：`13a0a74`。
> 来源：本次关于 Platform、Authentication、Authorization/ABAC 与 Auth 职责拆分的讨论。
> 定位：B4 严格边界之后的独立演进计划；沿用现有 G01–G05 与 Plan 04 治理，不重写既有里程碑或声明生产验收完成。
> 配套讨论：[Platform 能力、Provider 与租户连接边界](../platform-capabilities-and-tenant-connections.zh-CN.md)。
> 目标结构逐阶段实施；证据见 [Plan 05 evidence](../evidence/plan05/README.md)，未勾选项不代表已完成。

## 1. 目标与范围

将含义过宽的 `Auth` 重命名为 `IAM`（Identity and Access Management），保持一个业务模块和现有模块化单体部署方式，在模块内部形成 Identity、Users、Access、Tenancy 四个子域。将通用认证协议与授权求值机制提取到两个 Platform 能力。

| 位置 | 唯一职责 | 不承担的职责 |
| --- | --- | --- |
| Platform.Authentication | OIDC/认证协议执行、token 验证机制、provider 技术适配 | 本地用户建号、租户成员资格、IdP 信任政策 |
| Platform.Authorization | 输入校验、通用条件处理、授权求值及结果归一化 | 谁能修改政策、特殊角色特权、查询业务模块数据库 |
| IAM.Identity | 身份绑定、注册/登录编排、SSO provisioning、IdP 信任规则 | OIDC/SDK 技术实现 |
| IAM.Users | 本地用户资料、启停和账户生命周期 | 成员关系与角色授予的唯一存储 |
| IAM.Access | 角色、权限、授予、RBAC/ABAC 政策管理与组合 | 交易状态机和基金业务不变量 |
| IAM.Tenancy | Tenant、Department、成员关系及其生命周期 | 认证协议和通用策略计算 |
| 资源所属业务模块 | 资源属性、操作入口的授权执行、领域不变量 | IAM 内部表和其他模块数据的直接访问 |

本计划不拆分微服务，不将四个子域立即拆成四个模块，不新增租户计费/订阅，不创建通用 Integrations 产品，不增加新的身份服务商，不要求租户运行自己的 OPA。Email 多连接与 SES 接入属于配套讨论中的后续轨道。

结构迁移与行为变更分开验收：目录/程序集迁移阶段保持现有外部行为；成员关系规范化、全局角色策略和 ABAC 组合变化各自提供差异清单与测试，不以“重构”隐式改变授权结果。

## 2. 已核对的现状与迁移映射

| 当前源码或组件 | 观察 | 目标动作 |
| --- | --- | --- |
| [AuthModuleInstaller](../../../../src/Modules/IAM/IFX.Modules.IAM.Composition/AuthModuleInstaller.cs) | 统一装配各类入口，并按全局配置选择 Cognito/Auth0 | IAM Composition 装配 IAM；技术 provider 由平台 Composition 注册 |
| [IOidcAuthService](../../../../src/Modules/IAM/IFX.Modules.IAM.Application/Identity/Interfaces/IOidcAuthService.cs) | 授权地址、code exchange、UserInfo、logout 等协议操作 | 保留消费方 Port 的需求，平台契约按真实能力拆小 |
| [Provider services](../../../../src/Modules/IAM/IFX.Modules.IAM.Application/Identity/Interfaces/ProviderServices.cs) | 注册、认证、刷新、撤销混在一个接口中 | 区分协议登录、token 生命周期、外部账号管理；不原样搬成万能接口 |
| [ProvisionSsoUserCommandHandler](../../../../src/Modules/IAM/IFX.Modules.IAM.Application/Identity/Commands/ProvisionSsoUser/ProvisionSsoUserCommandHandler.cs) | 建立本地 User/UserIdentity、解析 IdP、授予 PendingUser | 保留在 IAM.Identity，通过同模块应用协调完成成员与初始角色处理 |
| [User](../../../../src/Modules/IAM/IFX.Modules.IAM.Domain/Users/User.cs) | 已有 Tenants、Departments、Roles、RoleGroups、PrimaryTenantId 等关系 | 先保留映射，后明确 Membership 与 Assignment 所有权；并非从零新增租户关系 |
| [IfxDbContext](../../../../src/Modules/IAM/IFX.Modules.IAM.Infrastructure/Persistence/IfxDbContext.cs) | 一个上下文管理身份、用户、权限和租户表 | 保持一个 IAM 数据所有者和事务边界；不因子域整理拆库 |
| [ResourceAuthorizationService](../../../../src/Modules/IAM/IFX.Modules.IAM.Application/Access/ResourceAuthorizationService.cs) | 混合 HTTP/用户属性、策略选择、OPA、GlobalAdmin 特例和执行拒绝 | 拆成入口上下文适配、IAM 政策编排、平台求值、消费方执行 |
| [DbAbacPolicyResolver](../../../../src/Modules/IAM/IFX.Modules.IAM.Infrastructure/Access/DbAbacPolicyResolver.cs) | 租户→平台→静态回退，部分读取异常后继续回退 | 分离政策选择与存储；区分 NotConfigured、Unavailable、Invalid |
| [IResourceAuthorizationService](../../../../src/Modules/IAM/IFX.Modules.IAM.Application/Ports/Authorization/IResourceAuthorizationService.cs) | 对调用者暴露 OPA resource 基类和 decisionPath | 将 OPA 路径/envelope 收入 provider Adapter |

这是文件级观察，不能代替运行调用链审计。Phase 0 将逐项确认实际注册、生产调用者和遗留未使用代码，并记录当时 HEAD；上述链接在实施重命名后同步更新。

## 3. 目标结构与所有权

```text
src/Platform/
  Authentication/
    IFX.Platform.Authentication.Contracts/
    IFX.Platform.Authentication.Runtime/
    IFX.Platform.Authentication.Infrastructure.Oidc/
    IFX.Platform.Authentication.Infrastructure.Cognito/  # 实际专有 API 所需时
    IFX.Platform.Authentication.Infrastructure.Auth0/    # 实际专有 API 所需时
    IFX.Platform.Authentication.Composition/
  Authorization/
    IFX.Platform.Authorization.Contracts/
    IFX.Platform.Authorization.Runtime/
    IFX.Platform.Authorization.Infrastructure.Opa/
    IFX.Platform.Authorization.Composition/

src/Modules/IAM/
  IFX.Modules.IAM.Contracts/             # 只为真实外部消费者创建
  IFX.Modules.IAM.Domain/
    Identity/ Users/ Access/ Tenancy/
  IFX.Modules.IAM.Application/           # 同样按四个子域组织
  IFX.Modules.IAM.Infrastructure/        # 同样按四个子域组织
  IFX.Modules.IAM.Presentation/          # 同样按四个子域组织
  IFX.Modules.IAM.Composition/
```

- User 的账号事实归 Users；`(Issuer, Subject)` 与 User 的身份映射归 Identity，不能以 email 相同自动合并身份。
- Tenant、Department、TenantMembership 归 Tenancy；Role、RoleGroup、Permission、RoleAssignment 和策略归 Access。
- TenantMembership 表达成员资格；RoleAssignment 表达授权。无角色不等于非成员，撤销角色不等于退出租户。
- 普通租户授予关联有效成员及租户作用域；平台 GlobalRole 使用显式平台作用域，不伪造普通租户成员。
- PrimaryTenantId 是用户偏好/默认选择，不能作为成员资格和授权证据。
- 四个子域仍共享 IAM 的本地事务，可由应用用例协调；子域通过领域方法和明确服务协作，避免任意互改集合。不为内部子域调用增加 HTTP 或跨模块协议。
- `BuildingBlocks.Security` 中成熟运行能力按职责提取；保留的基础类型应小、稳定且符合 G05，不另建 SecuritySharedKernel。

### 3.1 编译期依赖与运行流程

继续采用[严格边界规则](../layerguard-strict-boundaries.zh-CN.md)：Application 定义消费方 Port；外层 Integration Adapter 引用已登记的 provider Contracts；Domain 不引用平台 Runtime/SDK；Host 只通过 Composition 装配。

授权目标调用路径：

```text
业务模块 Application：构建资源事实，调用自己的授权 Port
  → 业务模块外层 Adapter
  → IAM.Contracts 授权入口
  → IAM.Access 应用编排：验证 scope、取得主体事实、选择并组合策略
  → IAM 自有求值 Port → IAM 外层平台 Adapter
  → Platform.Authorization.Contracts → Runtime → OPA Adapter
  ← 返回版本化决定；业务用例在访问/变更前执行结果
```

这是一条进程内调用路径，不要求每次都联网。IAM 管理操作也调用同一 Access 应用能力，但该能力使用底层政策读取 Port，不递归调用自己的授权 HTTP/Contract 入口。平台求值器接收已选策略快照，不反向查询 IAM，避免 IAM ↔ Platform 的同步依赖环。

认证流程由 IAM.Identity 决定本次允许使用的 IdP，平台执行协议并验证身份，再由 IAM 映射本地用户、检查账号和成员资格。浏览器 callback 与 Bearer 请求验证分别盘点，不能假定全部入口经历同一登录流程。

### 3.2 契约与安全上下文

- 认证输出表达已验证外部身份及验证依据；角色授予、成员资格和本地准入由 IAM 决定。
- 平台授权请求表达 subject/resource/action/environment 与受控策略快照；建议结果为 Allow、Deny、Indeterminate，加稳定 reason code、decision id、policy version。
- Indeterminate、缺失可信 scope、缺失必要属性均不授予权限；运维诊断区分正常拒绝和技术失败。
- provider SDK、OPA decisionPath、Rego envelope、EF entity、HttpContext 不进入通用 Contracts。
- 属性 schema 及扩展字段有类型、来源和版本；不以任意 dictionary 绕过 G03/G05 分类和最小化。
- refresh/access token、密码、client secret、PKCE verifier 仅在受控协议/适配边界处理，不进入通用主体 DTO、事件、后台任务和审计日志；有必要的敏感接口单独登记用途、字段分类及生命周期。
- 可信上下文来自入口验证并显式传播到后台执行；不能把请求体中的租户、角色或资源状态直接作为事实。

## 4. 执行阶段

### Phase 0 — 事实基线与迁移决策

交付：变更清单、行为矩阵、身份兼容映射、依赖图与数据盘点；不改业务实现。

- [x] IAM0.1 从源码、DI、ApiHost/Worker、测试和 G03 catalog 盘点实际调用链、provider、API、持久化对象及消费者，标记未使用实现。
- [x] IAM0.2 保存当前登录/SSO、注册、邮件验证、token refresh/revoke/logout、账号停用、租户切换、角色授予和 ABAC 的正反行为基线。
- [x] IAM0.3 建立 `Auth → IAM` 名称映射，分别列出程序集、namespace、模块 manifest、逻辑 owner、schema、migration history、事件标识、队列任务类型、配置键和 API 路径。
- [ ] IAM0.4 盘点真实 User–Tenant、Department、Role/RoleGroup 关联数据，识别重复、孤立、跨租户及无成员角色授予；记录规模与修复规则，不从角色或 PrimaryTenantId 盲目生成成员。
- [x] IAM0.5 明确成员退出、用户/租户停用、已有 session/token 和权限缓存的生效规则；明确 GlobalAdmin、多个 GlobalRole、RBAC/ABAC 组合与例外行为。
- [x] IAM0.6 记录现有门禁/测试结果及工具版本；无法运行标记 blocked 或 pending 并写原因，不继承历史绿色报告。

验收：每个现有功能有目标 owner，每种持久化/外部标识有保留或迁移策略；行为差异和数据歧义均显式登记。待产品决定的事项只阻塞依赖它的行为迁移，不阻塞独立结构工作。

### Phase 1 — Auth 重命名与四子域整理

交付：`Modules/IAM`、调整后的 solution/引用/namespace/DI/测试定位与治理映射。

- [x] IAM1.1 将 Auth 各层及测试项目迁移为 IAM，调整 solution、ProjectReference、扫描入口、反射类型、构建脚本与文档链接。
- [x] IAM1.2 将 Authorization 中的 Tenant/Department 功能归入 Tenancy，其余角色/权限/策略归 Access；Identity、Users 按职责整理，先保留既有数据库映射和业务行为。
- [x] IAM1.3 更新 G03 ownership 源、G04 manifest、G05 来源身份映射及 Plan 04 inventory；再由现有工具生成派生视图，不手改第二套 allowlist。
- [x] IAM1.4 保持一个唯一数据 owner；逻辑模块标识是否更名遵循 IAM0.3，代码名 IAM 与旧 wire/schema 标识的兼容映射不能形成两个所有者。
- [x] IAM1.5 保留 API 路径、权限字符串、既有 issuer/audience、配置键、数据表/schema、migration id/history；检查 EF snapshot 与迁移发现未产生非预期 DDL。
- [x] IAM1.6 对已持久化后台任务及类型名完成兼容演练后再切换程序集，验证 ApiHost、Worker、Migrator 均能装配。

验收：结构与治理门禁通过；基线行为无变化；现有数据库可启动；没有仅因 namespace 变化产生的建表、删表或重复 seed。

### Phase 2 — 提取 Platform.Authentication

交付：provider-neutral 的技术能力、IAM 消费方 Ports/Adapters 与宿主认证适配。

- [x] IAM2.1 按实际调用拆分 IOidcAuthService/IIdentityProvider；标准 OIDC 共用实现，Cognito/Auth0 专有账号 API 保留独立适配，不假定所有 IdP 支持密码注册。
- [x] IAM2.2 提取协议执行、Discovery、token 验证和 provider client；平台不读取 IAM Repository，不决定 PendingUser 或自动建号政策。
- [x] IAM2.3 将 IdP 配置/信任选择保留于 Identity，通过受控配置快照交给协议实现；平台默认 IdP 与租户 IdP 同时存在时不修改共享客户端凭证。
- [x] IAM2.4 迁移浏览器与 Bearer 两类实际入口，保持登录/注册编排、外部身份映射、账号及成员准入在 IAM；协议错误和业务拒绝分别映射。
- [x] IAM2.5 验证 state/nonce/PKCE、issuer/audience、回调地址与登录事务关联；租户尚未认证时不能依赖任意 X-Tenant-Id 直接建立信任。
- [x] IAM2.6 覆盖 refresh/revoke/logout、邮件验证、重复 callback、并发 provisioning 与 IdP 禁用；敏感信息不经通用事件或日志传播。

验收：现有真实 provider 均通过回归；伪造/重放/错误 issuer 等负向测试拒绝；本地身份创建没有迁入 Platform；无旧/新两套主登录链。

### Phase 3 — 提取 Platform.Authorization，先保持政策语义

交付：求值协议、Runtime、OPA Adapter、IAM.Access 编排、HTTP/Worker 上下文适配。

- [x] IAM3.1 将通用条件处理、模板执行和 OPA 技术调用移出 BuildingBlocks；区分“参数解析”与“实际求值”，避免名称掩盖职责。
- [x] IAM3.2 从 ResourceAuthorizationService 拆出主体/环境构建、政策选择、求值与拒绝执行；移除平台 Runtime 对 IHttpContextAccessor 的依赖。
- [x] IAM3.3 IAM.Access 承接政策选择与现有 GlobalRole 语义，先按基线迁移；平台引擎不硬编码 GlobalAdmin 绕过或角色名称。
- [x] IAM3.4 将业务消费者迁移到自己的 Port 与外层 Adapter；资源属性仍由资源模块提供，不把 EF entity 或跨模块查询塞入引擎。
- [x] IAM3.5 保持通用属性协议与 OPA 表示之间的映射；公共契约不出现 OpaResourceAttributesBase、decisionPath 或 SDK。
- [x] IAM3.6 补齐 API、内部命令、后台任务和读取列表的执行覆盖；列表入口的允许不等于每条记录都可读，仍使用模块拥有的受限查询和必要逐资源检查。

验收：结构拆分前后授权结果对账一致；相同可信输入在 HTTP/Worker 得到一致决定；未授权操作不执行；领域状态转换仍独立检查。

### Phase 4 — 明确 Access 政策组合与失效语义

交付：政策语义说明、策略数据分类/迁移、管理校验和错误处理。此阶段是显式行为改进。

- [x] IAM4.1 将政策区分为平台强制约束、可覆盖默认策略和租户自定义策略，逐条分类现有记录；保留原版本以便对账。
- [x] IAM4.2 定义平台约束、RBAC 和适用 ABAC 的组合；默认建议为各必要条件同时满足，租户不能覆盖强制约束。平台管理访问使用具名作用域和显式政策。
- [x] IAM4.3 决定并测试 GlobalAdmin 例外范围、多个 GlobalRole 的组合以及冲突处理；不再依赖角色集合的偶然顺序选第一项。
- [x] IAM4.4 将 NotConfigured、Disabled、Invalid、Unavailable 分开；仅在明确缺省语义下回退，数据库/OPA 失败不自动降级成更宽松政策。
- [x] IAM4.5 管理端限制可编辑模板、属性和操作范围；跨租户引用、扩大授权、删除强制约束等输入有负向验证。
- [x] IAM4.6 定义政策版本、模板版本、缓存键、变更失效和多实例一致性；策略缓存与授权决定缓存分别处理，后者包含相关主体/成员/资源版本或不启用。

验收：每个与旧行为不同的场景有期望说明；旧策略迁移可重复且有对账；缺策略/坏策略/引擎错误均不意外放行。仅通过结构测试不足以结束本阶段。

### Phase 5 — 规范 Users、Tenancy 与 Access 的数据关系

交付：显式 Membership/Assignment 模型或能表达相同不变量的现有关系演进、迁移及对账。不新增其他租户产品功能。

- [x] IAM5.1 根据 IAM0.4 选择扩展现有 join 还是新增 TenantMembership；建立唯一性、租户/部门一致性、状态与角色授予引用，不重复创建同一成员事实。
- [x] IAM5.2 采用 expand/backfill/validate/switch/contract 顺序；无歧义已有 User–Tenant 关系作为来源，孤立角色等歧义单列，不能通过扩大成员范围自动修复。
- [x] IAM5.3 保持平台 GlobalRole 的独立作用域；普通角色与 RoleGroup 授予校验目标成员、角色和部门属于正确租户。
- [x] IAM5.4 拆分 User 内的身份、成员、角色导航操作职责，保留同一 IAM 事务，维护成员加入/退出和初始角色授予的原子性。
- [x] IAM5.5 按 Phase 0 的规则实现退出/停用后的访问失效，包括现有 token/session、成员/权限缓存及后台任务执行时重新检查；不依赖异步清理才能拒绝访问。
- [x] IAM5.6 对 fresh install、旧库升级、重复 backfill、并发授予/退出、主租户切换运行关系数据库测试，完成行数/关联/权限效果对账。

验收：成员与授权事实各有唯一 owner；没有自动新增权限；旧数据可追踪；退出后按定义失效；数据库迁移使用现有受控 Migrator。

### Phase 6 — 装配、消费迁移与治理收口

- [x] IAM6.1 清理遗留 Auth/OPA 暴露与重复服务注册，保留的旧标识只存在于具名兼容清单和历史证据中。
- [x] IAM6.2 ApiHost/Worker 只通过 Composition 装配；IAM Runtime/平台 Runtime 无反向读取其他模块数据，无同步 provider 环。
- [x] IAM6.3 更新 G03 catalog/source/snapshots、G04 manifest、G05 分类/context、Plan 04 query/bypass/inventory 与数据库迁移脚本，生成新证据。
- [x] IAM6.4 新增针对平台实现泄漏、OPA 类型泄漏、未知属性、错误 scope、隐式 HTTP 上下文及同步环的正反验证，接入已有门禁。
- [x] IAM6.5 对移出的 BuildingBlocks.Security 类型逐个核对真实消费者，删除无消费者的过渡代码，不新增被禁止的 *.Abstractions 兼容项目。

验收：新图可从权威输入重建；历史 B4 证据保留，新 HEAD 有独立零违规报告；不通过清空 baseline、扩大通配许可或隐藏项目消除 finding。

### Phase 7 — 回归、发布演练与文档关闭

勾选表示仓库自动化与本地隔离演练完成，不表示目标环境旧二进制、真实滚动发布或生产回退通过；范围见 [P05-S7](../evidence/plan05/P05-S7-release-validation.md)。

- [x] IAM7.1 运行下节验证矩阵，报告用例数、命令、环境、commit、失败/跳过及原因。
- [x] IAM7.2 演练 Migrator、兼容 Worker、API 的发布顺序，以及旧任务、旧数据库、旧配置和 API 客户端兼容。
- [x] IAM7.3 对结构版本回退、行为版本回退和数据库回退分别演练；已产生新模型数据后不假定旧代码可直接运行。
- [x] IAM7.4 更新当前架构、调用图、身份/策略流程、数据库映射与中英文最终实现说明；草案中的目标说明不能冒充现状。
- [x] IAM7.5 在 `evidence/plan05/` 保存阶段报告与总验收；仓库完成与目标环境发布状态分开记录，未执行生产操作标记 pending。

## 5. 验证矩阵与现有入口

| 范围 | 必要验证 | 所属阶段 |
| --- | --- | --- |
| 名称/装配 | solution、DI、扫描、CLI 脚本、API/Worker/Migrator、旧任务类型 | 0–1、6–7 |
| 认证 | 现有 provider 正常登录，错误 issuer/audience/state/nonce、重放、IdP 禁用、刷新/撤销 | 2 |
| 本地身份 | `(Issuer, Subject)` 唯一、同 email 不自动合并、并发建号、停用账号 | 2、5 |
| 授权 | RBAC/ABAC 组合、多个 GlobalRole、强制约束、缺策略/坏策略/错误/超时 | 3–4 |
| 属性与上下文 | 伪造 tenant/role/resource、缺属性、后台无 HTTP、敏感字段不泄漏 | 2–4、6 |
| 资源执行 | 直接资源与列表不越租户；拒绝后无写入；业务不变量独立执行 | 3–5 |
| 数据/缓存 | 成员/角色一致性、退出失效、多实例政策更新、升级/backfill/回退 | 4–5、7 |
| 边界治理 | Contracts 纯度、provider graph、Context 分类、无跨 schema 查询 | 各迁移阶段 |

以下为已存在的仓库入口示例；实施时使用当时 CI 的准确参数和环境，先跑相关测试，最终统一回归。名称迁移同时维护脚本内旧路径，不把命令列表当作已执行证据。

```powershell
dotnet build IFX.sln
dotnet test IFX.sln
./scripts/Invoke-LayerGuard.ps1 -ReportPath artifacts/plan05/layerguard.json
./scripts/Invoke-G03ContractEventGuard.ps1 -Phase 7 -ReportPath artifacts/plan05/g03.json
./scripts/Invoke-G05Verification.ps1 -OutputDirectory artifacts/plan05/g05
./scripts/Test-Plan04Governance.ps1 -StatusPath artifacts/plan05/plan04.json
./scripts/Test-DatabasePendingModelChanges.ps1
```

若修改前端身份、租户或管理接口适配，增加相应前端测试；数据库和 provider 环境不可用时保存可运行的测试及执行阻塞原因，不声明外部集成通过。

## 6. 兼容、发布与回退

| 边界 | 处理策略 | 退出/回退条件 |
| --- | --- | --- |
| API/配置/权限名 | 结构阶段保持稳定；确需改变时单独版本化 | 旧消费者覆盖完成前保留兼容 |
| SQL/schema/migration | 代码更名不触发物理更名，不重写已应用 migration id/history | 升级和 rollback rehearsal 对账通过 |
| G03 owner/事件 | 保持既有 wire identity；代码 owner 映射有唯一来源 | 有真实协议变化才按 G03 升级版本，不复制旧协议形成双 owner |
| Hangfire/序列化类型 | 盘点已入队/重试/定时任务；选择受控排空/重建或有界类型解析迁移 | 覆盖未来定时任务、幂等和重复执行；无法兼容时先停产旧任务，不能静默丢弃 |
| 成员模型 | expand/contract，保留旧字段直到回退窗口结束；过渡写入保持同事务一致 | backfill 与权限对账通过后切换；已收缩模型不直接部署旧二进制 |
| ABAC 行为 | 版本化策略及差异清单；可先旁路计算新决定作对账，但不作为第二个放行通道 | 不以回退重新引入已修复的越权；必要时保持拒绝并修复前进 |
| Runtime 装配 | 单一主执行链，provider 实现由 Composition 切换 | 无默认 Allow/NoOp authorization 作为容错 |

建议提交粒度：P0 基线 → P1 名称与内部归属 → P2 认证提取 → P3 授权结构提取 → P4 政策语义 → P5 成员模型 → P6 治理与清理 → P7 发布证据。每个提交边界保持可构建；先解决序列化兼容再执行会影响旧任务的名称切换。

实施角色：IAM 负责领域/政策；Platform 负责引擎/适配；Database 负责迁移演练；Security 复核信任与失效语义；消费模块负责属性与执行点。具体执行人及环境在 Phase 0 填写，不虚构已审批状态，也不把本文的角色分工作为重复确认日常可逆工作的要求。

## 7. 完成定义与后续事项

- [x] 一个 IAM 模块、四个子域、两个平台能力实际落地；现有功能逐项可追踪。
- [x] IAM 有唯一数据 owner，平台不依赖其内部实现；消费方保持 Port/Adapter 规则。
- [x] 认证信任、本地准入、授权求值、执行点与领域不变量边界可由测试证明。
- [x] 策略组合和成员模型的行为差异有记录、迁移和验证，不隐含于重命名。
- [x] 数据、旧任务、协议与客户端兼容有证据，仓库范围内结构/数据/行为回退边界已演练，目标环境回退 pending。
- [x] 当前 HEAD 的行为测试与治理检查通过，文档和实际代码一致；生产未验证部分明确标识。

未来 Tenancy 若形成独立开通/组织生命周期和多模块复用，再依据 [Plan 04](04-module-boundary-evolution.md) 评估独立模块。独立 AccessControl、租户自带 OPA、其他认证 provider 及通用连接中心均不属于本计划完成条件。

## 8. 关联资料

- [计划索引](README.md)
- [Contracts/Adapters/Events 目标](../target-contracts-adapters-events.zh-CN.md)
- [G01–G05 前置治理](00-prerequisites.md)
- [B4 严格边界](../layerguard-strict-boundaries.zh-CN.md)
- [Plan 04 模块边界与租户查询](04-module-boundary-evolution.md)
- [Platform 独立讨论记录](../platform-capabilities-and-tenant-connections.zh-CN.md)
- [ASP.NET Core Authentication](https://learn.microsoft.com/en-us/aspnet/core/security/authentication/)
- [OPA 决策与执行边界](https://www.openpolicyagent.org/docs)
