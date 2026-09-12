# Plan 05 实施证据

| 阶段 | 说明 | 状态 |
| --- | --- | --- |
| P05-S0 | [事实基线与迁移决策](P05-S0-baseline.md)、[固定源码清单](phase0-inventory.json) | 仓库基线通过：1108 项测试、189 项 LayerGuard 测试；目标数据未审计 |
| P05-S1 | [IAM 结构与兼容迁移](P05-S1-iam-structure.md) | 1110 项测试、189 项 LayerGuard 测试、五个 EF snapshot 和治理门禁通过 |
| P05-S2 | [认证提取与本地准入](P05-S2-authentication.md) | 1142 项 .NET、23 项前端、190 项 LayerGuard 测试及构建/门禁通过；真实 IdP 联调待执行 |
| P05-S3 | [授权结构提取](P05-S3-authorization.md) | 1177 项 .NET、190 项 LayerGuard 测试；49 项目零违规，治理门禁通过 |
| P05-S4 | [政策语义 v2](P05-S4-policy-semantics.md) | 1203 项 .NET、190 项 LayerGuard 测试及治理通过；目标政策审计待执行 |
| P05-S5 | [成员事实与授权失效](P05-S5-membership.md) | 1212 项 .NET、190 项 LayerGuard 测试；117 项 SQL/数据库测试及门禁通过；目标审计待执行 |
| P05-S6 | [装配与边界收口](P05-S6-boundary-closure.md) | 1225 项 .NET、190 项 LayerGuard 测试；新增安全门禁通过，协议批准待定 |
| P05-S7 | [Release 验证与总验收](P05-S7-release-validation.md) | 1228 项 .NET、63 项前端、190 项 LayerGuard 测试；Release 构建/发布包、120 项数据库测试及门禁通过；目标验收 pending |

计划唯一进度清单位于 [Plan 05](../../plans/05-iam-platform-security-refactor.md)。本目录分别记录仓库验证、目标环境证据和未完成事项；历史失败不会由后续绿色结果覆盖。
