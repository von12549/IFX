# G02 模块数据库边界

> 状态：G02 Phase 0–9 已实施；最终关闭等待 Plan 02 E2/E4 回交证据及 Phase 10 批准。
> English version: [database-boundary.en.md](database-boundary.en.md)
> 决策记录：[ADR-G02-001](ADR-G02-001-module-database-ownership.md)

## 1. 边界模型

IFX 近期保留一个 SQL Server 和一个物理 `IFXDb`，但形成五个逻辑数据库边界。每个模块独立
拥有 DbContext、schema、连接键、migration assembly 和 schema 内 history table。共用服务器只是
部署优化，不代表可以共享表或事务。

| 模块 | DbContext | Schema | 连接键 | Migration history |
| --- | --- | --- | --- | --- |
| Auth | `IfxDbContext` | `auth` | `AuthDatabase` | `auth.__EFMigrationsHistory` |
| CRM | `CrmDbContext` | `crm` | `CrmDatabase` | `crm.__EFMigrationsHistory` |
| Registry | `RegistryDbContext` | `registry` | `RegistryDatabase` | `registry.__EFMigrationsHistory` |
| Holdings | `HoldingsDbContext` | `holdings` | `HoldingsDatabase` | `holdings.__EFMigrationsHistory` |
| Transaction | `TransactionDbContext` | `transaction` | `TransactionDatabase` | `transaction.__EFMigrationsHistory` |

模块不得使用其他模块 DbContext，也不得直接读写其他模块表。禁止跨 schema FK、EF navigation、
join、trigger 和 stored procedure。同步访问经 Contract 和消费方 Port/Adapter，异步传播经可靠 Event。
Outbox/Inbox 跟随所属模块 DbContext 和 schema，不建立共享 Messaging DbContext。Plan 02 E2/E4 负责
创建真实表并回交最终关系数据库证据。

参见[数据库架构 Mermaid 源文件](diagrams/database-architecture.mmd)和
[已渲染 SVG](diagrams/database-architecture.svg)。

## 2. 决策与物理分库接缝

| 决策 | 规则 |
| --- | --- |
| G02-D01–D07 | 物理共库、严格 schema ownership、默认 schema、独立连接键，以及 schema 内 history/Outbox/Inbox。 |
| G02-D08–D15 | 显式 fail-closed history bootstrap、完整 fingerprint、精确 ownership mapping、事务规范化、dry-run、恢复点和只读 legacy history。 |
| G02-D16–D20 | One-shot Migrator、确定性 manifest 顺序、数据库 application lock、首错即停和 roll-forward。 |
| G02-D21–D25 | Expand/Contract、migration/runtime 身份分离、确定 Compose 顺序、真实 SQL Server 矩阵和只读 readiness。 |
| G02-D26 | 经批准的隔离 Docker 演练只关闭实施验证；生产执行由 G04/Release Operations 重新批准和留证。 |

当前各模块连接键可以都解析到 `IFXDb`。未来物理拆分时，运维只改变选定模块的连接目标并迁移该
模块拥有的 schema；Application 和 Domain 不变。拆分前，任何物理同库假设都必须由 Contracts/Events
替代，并显式设计报表、备份和恢复方案。

## 3. History Bootstrap

Bootstrap 在写入前分类：

- `fresh`：没有 owned schema/history，正常执行 pending migrations；
- `current shared`：每条已知 shared history 精确归属一个模块，并保留原 ProductVersion 复制；
- `known legacy`：只有完整 schema fingerprint 匹配才允许 canonical adoption，包括 Auth pre-squash
  IDs 和错误 squash alias；
- `current module`：schema-local histories 已与 manifest 一致；
- `unknown`、mixed、partial 或 fingerprint mismatch：fail closed，禁止自动 stamp。

数据库级 application lock 覆盖 bootstrap 和完整升级。Bootstrap 规范化在事务内执行；各模块
migration 不包进一个全局事务。成功后重跑应无变化。旧 `dbo.__EFMigrationsHistory` 若存在，首次
兼容窗口只读保留；删除必须另行批准。

参见[Bootstrap 状态机源文件](diagrams/history-bootstrap.mmd)和
[已渲染 SVG](diagrams/history-bootstrap.svg)。

## 4. Migrator Manifest 与命令

版本化 manifest 结构如下：

```json
{
  "formatVersion": 1,
  "physicalDatabase": "IFXDb",
  "modules": [{
    "moduleName": "Auth",
    "dbContext": "fully.qualified.DbContext",
    "schema": "auth",
    "historyTable": "__EFMigrationsHistory",
    "connectionKey": "AuthDatabase",
    "order": 10,
    "dependsOn": [],
    "migrations": [{ "migrationId": "...", "productVersion": "8.0.0", "sourceSha256": "..." }]
  }]
}
```

所有模式使用同一个不可变 artifact 和五个模块连接配置：

```powershell
./scripts/Invoke-DatabaseMigrator.ps1 -Mode preflight -ReportPath artifacts/preflight.json
./scripts/Invoke-DatabaseMigrator.ps1 -Mode dry-run  -ReportPath artifacts/dry-run.json
./scripts/Invoke-DatabaseMigrator.ps1 -Mode apply    -ReportPath artifacts/apply.json
./scripts/Invoke-DatabaseMigrator.ps1 -Mode validate -ReportPath artifacts/validate.json
./scripts/New-DatabaseMigrationArtifacts.ps1 -OutputDirectory artifacts/database-migrator
```

Dry-run 报告记录 `Mode`、时间、`Result`、`FailurePoint`、错误及 bootstrap plan；每模块包含 schema、
是否创建 history table、待插入行和 pending migration IDs。批准前 `CanApply` 必须为 true。退出码为：
`0` 成功、`2` 配置、`10` preflight、`20` lock、`30` 模块 migration、`40` validation failure。

## 5. 生产部署与恢复

先冻结不可变 API/Worker/Migrator images、release/migration/artifact manifests 及已审核 SQL。架构、
数据库和运维批准后依次：preflight/dry-run；验证备份或恢复点；获取锁；必要时 bootstrap；执行
Auth → CRM → Registry → Holdings → Transaction；validate；先部署兼容 Worker consumers，再部署
API producers；最后观察 readiness、smoke tests 和兼容窗口。ApiHost 只在 validation 后启动，并通过
`/health/database` 无 DDL 检查数据库；聚合 `/health/ready` 仍可反映外部依赖。

参见[生产流程源文件](diagrams/production-migration-flow.mmd) /
[SVG](diagrams/production-migration-flow.svg)、[失败恢复源文件](diagrams/failure-recovery.mmd) /
[SVG](diagrams/failure-recovery.svg)和 [Expand/Contract 源文件](diagrams/expand-contract.mmd) /
[SVG](diagrams/expand-contract.svg)。

遇到 lock timeout、commit outcome unknown、模块失败或 validation failure 时：停止新版本，保留报告和
histories，从新连接分类，修复后使用同一已审核 artifact 安全重跑。首个失败后不执行后续模块，禁止自动
EF `Down`。恢复/数据库回退仅用于 roll-forward 无法满足事故目标的例外情况，必须具备已验证恢复点、
演练脚本、明确数据损失和架构/数据库/运维批准。旧镜像只有在其 release manifest 认定当前 schema
兼容时才可回退。

## 6. 常见错误与禁止模式

| 信号 | 含义与动作 |
| --- | --- |
| Unknown/duplicate migration ownership | Manifest 或数据库不安全；修复 artifact/state，禁止 stamp。 |
| Partial schema/fingerprint mismatch | 保留状态并调查；禁止自动 legacy adoption。 |
| Application-lock timeout | 查明当前 owner；不能只为继续发布就终止未知会话。 |
| 模块 migration failure | 冻结 API/Worker 发布，诊断后从记录的 partial state roll forward。 |
| Validation/readiness failure | 即使 migration 返回成功也继续阻断新应用。 |
| Advanced incompatible schema | 不得回退到该应用镜像。 |

禁止：runtime/API migration、在持久环境使用 `EnsureCreated`、手工编辑 history、自动 `Down`、跨 schema
DDL/访问、共享 Messaging DbContext、未经审核的 destructive SQL、在证据中保存 secret/业务行，以及
把镜像回退当成数据库回退。

运行细节参见[上线手册](../../evidence/gates/G02/G02-phase8-rollout-runbook.md)和
[失败恢复手册](../../evidence/gates/G02/G02-phase6-recovery-runbook.md)。

## 7. 规则到证据映射

| 规则 | 强制/证据 |
| --- | --- |
| 模块默认 schema 及全部 relational object 归属正确 | `ModuleSchemaOwnershipTests`、`SqlServerMigrationMatrixTests`、G02 guard |
| 独立连接键和物理分库接缝 | `ModuleConnectionConfigurationTests`、配置启动验证 |
| Schema-local history 和精确 bootstrap mapping | `HistoryBootstrap*Tests`、真实 SQL Server shared/legacy matrix |
| Auth canonical/legacy adoption 使用完整 fingerprint | `AuthLegacyAdoption*Tests`、partial-state failure matrix |
| Manifest 完整性和确定顺序 | `DatabaseMigratorManifestTests`、CI artifact generation check |
| Lock、首错停止、重跑和 validation | SQL Server concurrency/failure matrix 及结构化报告 |
| Runtime 无 DDL，API migration 路径不存在 | Phase 8 permission report、`SchemaCompatibilityTests`、G02 static guard |
| Required schema 采用只读 readiness | `/health/database`、`SchemaCompatibilityHealthCheckTests` |
| Destructive/Contract 变化必须审核 | Migration safety policy 及架构/数据库/运维批准 |
| 禁止跨模块编译/数据访问 | LayerGuard B0.5、数据库 metadata assertions、人工 SQL review |
| 真实模块 Outbox/Inbox ownership 和原子性 | Plan 02 E2/E4 回访 G01/G02（待完成） |

证据索引从 [G02 evidence 目录](../../evidence/gates/G02/)开始；受控演练记录在
[rollout-evidence.json](../../evidence/gates/G02/phase8-docker-rehearsal/rollout-evidence.json)。

