# Platform 能力、Provider 与租户连接边界：讨论记录

> 日期：2026-09-12；源码观察基线：`13a0a74`。
> 状态：架构讨论整理与建议，不表示已完成实现，也不是新的实施进度清单。
> 范围：保存本次 Platform 拆分讨论的结论、例子、理由及后续选择；认证与授权的具体实施另见 [Plan 05](plans/05-iam-platform-security-refactor.md)。

## 1. 问题与结论

当前业务模块位于 Modules，跨模块技术能力位于 Platform。后续既有 Messaging、BackgroundJobs 等系统运行能力，也有允许 tenant 使用自己 credential 的外部能力；相同能力仍希望通过统一 Contracts 提供不同实现。

建议继续按能力组织 Platform，进一步分离能力执行、provider 实现和连接管理。暂不按“系统专用／租户使用”把同一能力切成两套，也不按“本地／外部 API”划定业务模块边界。

逻辑职责现在就应明确；目录分组、独立程序集和独立部署按真实需求逐步增加。

## 2. 三个独立维度

| 维度 | 回答的问题 | 示例 | 主要影响 |
| --- | --- | --- | --- |
| 能力与领域归属 | 承担技术机制还是业务规则？ | 邮件投递／交易确认通知 | 模块所有权与依赖 |
| 实现方式 | 如何完成能力？ | 本地、SES、SendGrid、Hangfire、OPA | provider Adapter 与实现项目 |
| 连接归属与使用政策 | 使用谁的账号、资源和凭证？ | 平台连接、租户连接、指定用途连接 | 运行时解析、授权与计量 |

Provider 表示一种实现；Connection 表示该实现的一套账号与配置。一个租户可以拥有多个同 provider 的连接，例如不同发件域或用途。一个平台 provider 实现也可以同时服务平台连接与多个租户连接。

执行作用域与凭证所有权不同：租户用平台默认 SES 发邮件，执行仍属于该租户，不因此获得平台 scope。

“去掉基金、交易概念后仍成立”只说明能力并非核心业务独有，不能单独证明属于 Platform。身份、租户、访问管理也具有领域规则，适合成为支撑业务的 Module。

## 3. Platform 与 Modules 的责任

| 能力 | Platform | Modules |
| --- | --- | --- |
| Messaging | 传输、可靠投递、通用执行机制 | 事件含义、生产/消费业务行为；各模块拥有自己的事务/Outbox/Inbox 数据 |
| BackgroundJobs | 排程、触发、执行适配 | 结算、清理、发送业务通知等具体任务 |
| Email | 邮件投递、provider 错误归一化 | 哪些事件触发通知、给谁发、发送什么内容 |
| Notification | 可复用的渠道分发机制 | 用户偏好、业务模板、通知记录和业务流程，有真实领域需求时建模块 |
| Authentication | 认证协议及 provider 技术执行 | 身份绑定、建号、信任政策、账号准入 |
| Authorization | 通用求值机制与 OPA 等适配 | 角色授予、策略管理与组合；资源模块负责属性和执行点 |

外部 API 并不自动属于 Platform。例如某业务专用对账系统的 Adapter 可以保留在该业务模块 Infrastructure。只有职责本身形成可复用技术能力时，才值得提取为平台服务。

## 4. 建议组织方式

```text
Modules/
  IAM/                          # 另见 Plan 05
  CRM/
  Transaction/
  Integrations/                 # 候选：出现独立连接管理生命周期后建立

Platform/
  Context/
  Messaging/
  BackgroundJobs/
  Notifications/
    ...Contracts/
    ...Runtime/                 # 通用投递与连接路由
    ...Infrastructure.SendGrid/
    ...Infrastructure.Ses/      # 示例，当前并未实现
    ...Composition/
  Authentication/               # Plan 05 拟提取
  Authorization/                # Plan 05 拟提取
```

当前 Notifications 主要承接 Email 时可以继续使用已有名称。只有渠道/通知领域实际扩展时，再决定独立 Email 能力或 Notifications 业务模块。

不立即增加 Foundation、Services 等分组，不固定每项能力必须具有相同项目数。将来目录数量增加时可以分组，但目录分组不能替代编译期边界和数据所有权。

## 5. 连接管理与执行分离

连接管理负责创建、验证、启停、凭证轮换、用途绑定、权限和默认选择；能力执行负责使用已授权连接完成一次操作。两者具有不同生命周期。

当 tenant 可以自助管理这些连接且出现多个消费者时，建议形成 `Modules/Integrations`（或统一选用 Connections 名称）。早期仅有 Email 需求时，先实现邮件连接管理，再根据真实共性抽取。通用模块不集中承担全部第三方业务操作。

候选连接描述：

| 字段 | 含义 |
| --- | --- |
| ConnectionId | 稳定连接标识 |
| OwnerScope / OwnerTenantId | 平台或租户所有权，租户所有权时 tenant 必填 |
| Capability | Email、Storage 等能力 |
| Provider | Ses、SendGrid 等实现标识 |
| CredentialReference | 指向受控凭证存储的引用，不是明文凭证 |
| Status / ConfigurationVersion | 可用状态与配置版本 |

用途到连接的绑定单独表达，不把“一个租户只能有一个 provider”写入接口。provider 特有配置由各自实现验证；通用配置模型不强行统一所有字段。

能力 Runtime 通过明确的连接解析 Port 获取已授权配置；若管理数据由 Integrations 所有，由外层 Adapter 接入，不能直接引用其 Application 或读取其表。装配时登记依赖，不形成管理模块与能力 Runtime 的同步环。

缓存包含连接标识和配置/凭证版本，校验所有权与使用授权。不能只按 provider 缓存带凭证客户端，也不能修改共享客户端凭证来切换租户。

多租户控制面与实际请求执行的区分可参考 [Microsoft 多租户控制面架构](https://learn.microsoft.com/en-us/azure/architecture/guide/multitenant/approaches/control-planes)。这是一项设计参考，不要求独立部署控制面。

## 6. Email 示例：从全局 provider 到按连接执行

本次讨论中的“平台默认 SES、tenant 使用 SendGrid”是目标示例，不是仓库现状。当前 [AddNotifications](../../../src/Platform/Notifications/IFX.Platform.Notifications.Composition/NotificationsServiceCollectionExtensions.cs) 注册全局 settings 和共享 SendGrid client。

目标执行路径：

```text
业务用例：发送内容 + 可信执行 scope + 用途
  → 消费方 Port / 外层 Adapter
  → Email Contract
  → 按用途及政策解析有权使用的 Connection
  → 按 Provider 选择实现，按 Connection 获取配置/凭证
  → 外部服务
```

启动时注册可用实现，每次执行时解析连接。调用者通常不选择 SDK 或传 API Key；需要显式 ConnectionId 时，执行端仍校验 scope、用途和连接使用权。

| 场景 | 可采用的路由政策 |
| --- | --- |
| 平台运维告警 | 使用平台指定连接 |
| 租户交易通知 | 使用该租户的用途绑定连接 |
| 租户未配置 | 根据产品政策使用平台默认连接，或返回未配置 |
| 租户已配置但发送失败 | 返回失败或重试；是否切换连接是独立政策 |
| 租户显式禁用某用途 | 按禁用语义处理，不能当成未配置自动回退 |

“无配置时默认”与“故障后 failover”不同。故障切换可能改变发件身份、费用和投递结果；超时不代表未接受，跨 provider 重试可能重复发送。切换需要记录已尝试连接和可用的幂等/对账依据，不能承诺所有 provider 具备相同幂等能力。

## 7. 统一 Contracts：统一语义，而不只是类型

当前 [IEmailService](../../../src/Platform/Notifications/IFX.Platform.Notifications.Contracts/IEmailService.cs) 已屏蔽 SDK，但模板实现将 [TemplateId 直接传给 SendGrid](../../../src/Platform/Notifications/IFX.Platform.Notifications.Infrastructure.SendGrid/SendGridEmailService.cs)。增加第二个 provider 时，还需要处理：

- 平台逻辑模板标识映射到连接/provider 模板，或先统一渲染再发送；外部模板 ID 不直接成为业务语义。
- 区分服务商接受请求与最终送达，后者可能需要回执。
- 批量、模板、附件等非共有能力通过小接口、能力声明或明确 Unsupported 表达。
- 归一化错误时保留 NotConfigured、Disabled、Rejected、Unavailable、Unsupported 等有用差异。
- Contracts 不包含 SDK、DbContext、DI 和明文凭证；字段按现有 G03/G05 管理。

统一 Contracts 不意味着任意两个实现都能无条件互换；替换范围由契约承诺的语义和 conformance tests 决定。

## 8. 后台执行与上下文

当前邮件已有 [AuthEmailJobScheduler](../../../src/Modules/Auth/IFX.Modules.Auth.Composition/AuthEmailJobScheduler.cs) 后台调度路径。增加 tenant 连接时，需要任务显式保存可信作用域、用途以及必要的连接引用，执行时解析凭证。

连接在排队后可能变化，需要按用途决定：固定 ConnectionId，还是执行时使用最新绑定；重试是否固定原路由也应明确。配置轮换、禁用、删除和 tenant 停用均有执行规则，缺失上下文不能自动变成平台操作。

任务不存储 client secret/API Key。授权与连接可用性在执行时重新检查；审计记录 tenant、用途、connection、provider、关联 ID 和结果，避免记录凭证及不必要的邮件正文。

## 9. IdP 与 ABAC 的特殊归属

IdP 不只是一个外部连接：它决定接受谁签发的身份。凭证保存和轮换可以共用连接机制，信任的 issuer/audience、租户绑定、身份映射和 provisioning 政策仍归 IAM.Identity。

认证发生时还可能没有可信 tenant 上下文，不能直接复用 Email 的“当前 tenant → provider”规则。认证流程关联、信任配置和后续成员资格分别校验。

ABAC 通用求值属于 Platform.Authorization；政策管理、角色例外、强制约束及租户可定制范围属于 IAM.Access。资源属性与业务不变量仍归资源模块。允许租户编辑授权策略，不等于允许租户选择任意不受信任的求值器。

这些边界的实施任务仅在 [Plan 05](plans/05-iam-platform-security-refactor.md) 维护，本讨论不复制进度清单。

## 10. 推进建议与暂缓事项

建议先以 Email 验证“统一契约 + 多 provider + 多连接 + 明确作用域”的完整流程，再根据第二个真实消费者抽取连接管理共性。届时单独建立实施计划，覆盖数据模型、凭证存储、后台路由、回退政策、测试及部署。

暂缓：按系统/租户分裂两套 Email、通用 ExecuteIntegration 大接口、没有消费者的 provider 项目、目录改动驱动的微服务拆分，以及只为未来可能需求而建立复杂控制面。

开始 Email 实施前需确定的平台默认 provider、缺省与故障回退政策、发件域/模板归属、凭证存储方式和任务连接绑定时点，属于产品与运行决策，不由本讨论假定已经确定。

## 11. 关联资料

- [架构评审索引](README.md)
- [IAM 与平台安全执行计划](plans/05-iam-platform-security-refactor.md)
- [严格依赖边界](layerguard-strict-boundaries.zh-CN.md)
- [模块边界与提取治理](plans/04-module-boundary-evolution.md)
