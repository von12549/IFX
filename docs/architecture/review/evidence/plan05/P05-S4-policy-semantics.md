# P05-S4 — IAM 政策语义 v2

父提交：`f9289cf`；日期：2026-09-12。此阶段有明确授权行为变化，未部署目标环境。

## 分类与组合

| 分类 | 来源与所有权 | 组合方式 |
| --- | --- | --- |
| mandatory constraints | IAM 代码 v2：可信执行来源、已认证主体、actor 一致性、受支持操作、租户 scope 一致性 | 始终先检查；管理 API 无法删除或覆盖 |
| overridable default | 已有 Platform row 中不含 GlobalRoleIncludes 的政策；仅成功确认缺省后使用已登记静态默认 | Tenant row 可替代默认；不能替代 mandatory/RBAC |
| tenant custom | 原 Tenant row；不重新创建或扩大成员资格 | mandatory AND RBAC AND 所选 ABAC |
| platform role grant | 原 Platform row 的显式 GlobalRoleIncludes 条件 | 仅 platform scope；具名 RBAC 范围 AND 所有适用角色政策 |

没有新增数据库列或重写既有政策。`Scope`、`ConditionsJson` 和行 ID 原样保留；运行时分类带 `iam-v2` 内容版本。只读脚本 [policy classification audit](../../../../../scripts/sql/plan05-policy-classification-audit.sql) 输出每行分类、原始哈希和版本，用于目标环境发布前对账。SQL 测试对全体已迁移 seed 执行分类并核对行数，目标真实数据的同一审计仍 pending。

模板内容与解析后的条件共同进入求值摘要；平台结果携带 decision id、reason code 和 policy version。日志仅记录该安全决定元数据，不记录主体、资源属性或政策参数。

## 相对 v1 的差异

| 场景 | v2 期望 |
| --- | --- |
| Tenant ABAC 允许，但缺 RBAC | 拒绝，内部命令与 HTTP 一致 |
| 自己的 user/read profile | 明确的已认证用户 grant，仍检查租户边界和 ABAC |
| GlobalAdmin 在 tenant scope | 仍需租户 RBAC/ABAC，不以全局角色绕过 |
| GlobalAdmin 在 platform scope | 对受支持操作的具名平台管理 grant；主体、scope 和领域不变量仍检查 |
| Support/Auditor | 仅既定 IAM 只读操作范围；不因持有任意 GlobalRole 放行所有权限 |
| 多个适用 GlobalRole | 去重、固定顺序求取政策；所有适用政策必须允许；一个明确拒绝优先，不受输入顺序影响 |
| 找不到任何适用政策 | `policy_not_configured`，拒绝 |
| 已有禁用政策 | `policy_disabled`，不回退默认 |
| 坏 JSON、未知条件、缺参数、歧义选择 | `policy_invalid`，不能丢弃坏条件后继续 |
| 数据库不可用 | `policy_unavailable`，不能降级到更宽松默认 |
| OPA 不可用、关闭或坏响应 | Indeterminate，拒绝；Phase 3 的 fail-closed 修正保留 |
| 租户修改平台 scope/模板或任意参数 | 管理用例拒绝；平台政策写入要求 PlatformAdmin |
| 从内部调用全局角色管理/平台政策读取 | 经过应用授权边界，不能只依赖 HTTP endpoint filter |

政策删除仍可恢复既定默认；代码强制约束不作为可删除行存在。缓存策略明确为：**不启用跨请求政策缓存和决定缓存**。各实例每次读取当前提交的政策；读取存储失败就拒绝。遗留 invalidate 调用保留为管理用例兼容接口，其下已无缓存。

## 验证与发布界限

测试与门禁记录见 [phase4-validation.json](phase4-validation.json)、[phase4-guards.json](phase4-guards.json)。原始日志/TRX 位于 `artifacts/plan05/phase4/`。覆盖 mandatory/RBAC、角色顺序与冲突、平台内部入口、错误政策、跨实例读取版本、SQL JSON 空格差异、禁用、重复 selector 和只读分类对账。

初次测试中的旧缓存/准入预期、SQL seed 默认政策断言，以及一处 namespace 编译遗漏均已显式修正；失败记录保留。此阶段不声称用户/成员缓存失效已完成，该职责进入 Phase 5。

两个新授权协议继续为 Proposed；未虚构正式审核批准。上线前应先对目标政策运行只读分类，对照上表验证受影响角色，并部署可用的 OPA。回退不得通过恢复 fail-open 或角色越租户绕过来掩盖差异；必要时保持拒绝并修复前进。结构、旧任务、数据库及配置回退演练在 Phase 7 汇总。
