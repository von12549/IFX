# P05-S7 — Release 验证与总验收

日期：2026-09-12；验证父提交 `91688a92485ca1ec3dc3da953164befe7eead5b5` 加本阶段工作区。阶段提交保留在 Git 历史中，报告不使用自引用提交哈希。分支 `codex/plan05-iam-platform-security`，未 push、未发布目标环境。

## 仓库验收

Plan 05 的一个 IAM 模块、四个子域、两个平台能力已落地。认证机制与本地准入分开，授权技术求值与 IAM 政策组合分开；业务模块保留资源事实、查询过滤和执行点。成员事实、平台角色作用域、政策失败语义及保留的兼容标识有测试和逐阶段记录。

| 阶段 | 提交 | 交付 |
| --- | --- | --- |
| 文档起点 | f29ad32 | Plan 05 和独立 Platform 讨论 |
| P0 | 80c834a | 固定基线与外部待办 |
| P1 | 5e8b20b | IAM 更名、子域与旧任务 alias |
| P2 | 768a950 | Platform.Authentication 与本地身份准入 |
| P3 | f9289cf | Platform.Authorization 与消费 Port/Adapter |
| P4 | b04fca9 | 政策语义 v2、失败关闭与管理约束 |
| P5 | c4e36c7 | 当前成员事实、授予一致性与 IsActive 扩展 |
| P6 | 91688a9 | 单一装配、清理、治理与 CI 收口 |
| P7 | 本报告所在提交 | Release 回归、隔离回退与最终文档 |

| 验证 | 结果 |
| --- | --- |
| Release solution build | 0 errors，19 warnings |
| .NET Release | 1228/1228，21 个程序集，0 failed/0 skipped |
| SQL/数据库程序集 | 120/120，使用 Docker 隔离 SQL Server |
| 前端 | 63/63，11 文件；TypeScript/Vite 生产构建通过 |
| LayerGuard | 190/190 测试；49 受管项目，零违规/零豁免 |
| 治理 | G03 Phase 7、G04 Phase 7、G05 Phase 9、Plan 04、安全边界、迁移安全全部通过 |
| 模型与发布物 | 五个 EF snapshot 无 pending changes；五份幂等 SQL 哈希匹配 manifest；API/Worker 与 Migrator 本地 publish 成功 |

详见 [完整测试记录](phase7-validation.json) 和 [门禁、命令与发布物哈希](phase7-guards.json)。安全门禁报告中的 P05-S6 是该门禁定义阶段，本次在 Phase 7 再次执行。schema release ID 继续使用 Phase 5 引入的 plan05-s5；Phase 6–7 没有新的数据库迁移，不为了文档关闭重写 schema 版本。

环境：Windows、PowerShell、.NET SDK 10.0.303（应用 net8.0）、本机 Docker Desktop / SQL Server Testcontainers；前端 Vitest 4.1.0、Vite 8.0.1。验证日志位于 `artifacts/plan05/phase7/`，为本地生成物；JSON 保存摘要与 SHA-256，未将发布目录和原始日志加入 Git。

```powershell
dotnet build IFX.sln --configuration Release --no-restore
dotnet test IFX.sln --configuration Release --no-restore --logger trx --results-directory artifacts/plan05/phase7/full-final
./scripts/Export-Plan05TestEvidence.ps1 -ResultsDirectories artifacts/plan05/phase7/full-final -OutputPath docs/architecture/review/evidence/plan05/phase7-validation.json -Phase P05-S7
./scripts/Invoke-LayerGuard.ps1 -ReportPath artifacts/plan05/phase7/layerguard.json
./scripts/Invoke-G03ContractEventGuard.ps1 -Phase 7 -ReportPath artifacts/plan05/phase7/g03.json
./scripts/Invoke-G04DeploymentRuntimeGuard.ps1 -Phase 7 -ReportPath artifacts/plan05/phase7/g04.json
./scripts/Invoke-G05ContextBoundaryGuard.ps1 -Phase 9 -ReportPath artifacts/plan05/phase7/g05.json
./scripts/Test-Plan04Governance.ps1 -StatusPath artifacts/plan05/phase7/plan04.json
./scripts/Test-Plan05SecurityBoundary.ps1 -ReportPath artifacts/plan05/phase7/security.json
./scripts/Test-MigrationSafetyPolicy.ps1 -NoBuild -Configuration Release -ReportPath artifacts/plan05/phase7/migration-safety.json
./scripts/Test-DatabasePendingModelChanges.ps1 -NoBuild -Configuration Release
./scripts/New-DatabaseMigrationArtifacts.ps1 -OutputDirectory artifacts/plan05/phase7/release -NoBuild -Configuration Release
dotnet publish src/ApiHost/IFX.ApiHost/IFX.ApiHost.csproj --configuration Release --no-restore --output artifacts/plan05/phase7/publish/api /p:UseAppHost=false
dotnet publish src/DatabaseMigrator/IFX.DatabaseMigrator/IFX.DatabaseMigrator.csproj --configuration Release --no-restore --output artifacts/plan05/phase7/publish/migrator /p:UseAppHost=false
# Frontend working directory: src/Frontend/IFX.FrontEnd
npm run test:run
npm run build
```

所有实际验证命令最终成功。首次前端日志重定向受 sandbox 限制，测试尚未开始；按既有授权提升后执行通过。构建警告包括既有 AutoMapper 12.0.1、Microsoft.Extensions.Caching.Memory 8.0.0 的 NuGet 安全告警、Cognito 包版本解析、nullable 与已弃用 password-login 提示；未在本次重构中升级依赖。此前阶段的失败和修复留在各阶段证据中，不由最终绿色结果覆盖。

## 发布与回退演练范围

新增三个真实 SQL 用例：旧 schema 上新 manifest 拒绝启动；升级后旧 manifest 拒绝未知迁移，显式兼容 allowlist 才通过结构检查；隔离库无新状态时 Down/reapply 保留 UserTenants 与 PrimaryTenantId；租户停用后，旧形状成员查询仍看到关系，而当前 active 条件拒绝，重复迁移保留停用状态。

这里最后两项由结构回退和行为回退两个用例覆盖，readiness 前后矩阵为一个用例，共三个。旧 Hangfire cleanup 两种 assembly qualification 用例现在执行反序列化后的方法并检查参数与调用次数。现有 Migrator 五 owner matrix、API/Worker 单一装配、HTTP/Worker 事实刷新和 API 路由测试同时回归。

运行手册规定：目标审计与兼容版本准备 → 受控 Migrator apply/validate → 兼容 Worker → API/readiness → 流量。当前证据验证构件、真实隔离数据库与兼容判定，没有执行目标旧二进制或真实滚动升级。兼容 allowlist 只证明结构范围，不证明旧授权行为安全。生产不自动 Down；已产生停用状态时保留拒绝并修复前进，不回退到过时 claims/全局绕过/OPA 失败放行。

## 外部完成条件

| 待办 | 状态与交付要求 |
| --- | --- |
| IAM0.4 目标数据 | pending；执行只读成员/政策审计，保存规模、歧义修复与权限对账 |
| 真实 IdP | pending；Cognito/Auth0/OIDC 正负联调；既有 Auth0 password-login 未实现路径不计为通过 |
| 协议准入 | 两个新授权协议仍 Proposed；取得具名 G03 批准及敏感认证协议验收 |
| 旧任务与滚动部署 | pending；盘点队列/重试/定时任务，验证真实兼容 Worker 和旧二进制策略 |
| 运维验收 | pending；目标 DB 权限/RLS、性能/SLO、备份恢复时间、发布/回退签署 |

OIDC 一次性事务仍是进程内存；多实例需粘性会话或共享存储。Bearer 准入只传递已验证 issuer/subject，未声称完整 MFA 传播。对现有 token/context 的失效承诺是“下一授权检查”，不是即时取消执行中的操作。

当前中英文说明：[中文](../../iam-platform-security.zh-CN.md)、[English](../../iam-platform-security.en.md)，当前图和 README 已同步。Platform 自带凭证/连接中心讨论独立保留为后续设计，没有把该讨论当作已实现功能。
