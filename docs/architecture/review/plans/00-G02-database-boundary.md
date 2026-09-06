# Plan 00 / Gate 02：数据库边界实施计划

> 状态：Architecture Decisions Approved / 待实施
> 上级前置计划：[`00-prerequisites.md`](00-prerequisites.md)
> 上级总计划：[`00-master-plan.md`](00-master-plan.md)
> 运行编排：[`00-G04-deployment-runtime-boundary.md`](00-G04-deployment-runtime-boundary.md) 定义 Migrator → Worker → API、readiness 和回退顺序。
> 前置关系：Gate 01 已定义模块本地事务与 Outbox/Inbox 原子性
> 范围：DB1–DB4、DB9–DB11，以及数据库 ownership、history bootstrap、部署和测试规则
> 前置放行：模块 schema/history/Migrator 边界可独立实施；真实 Outbox/Inbox 表由 E2/E4 通过模块 migration 创建并回交最终证据
> Gate 关闭条件：本计划全部 Phase、Definition of Done 和文档交付均已完成

## 目标

近期继续使用单一 SQL Server / `IFXDb`，但把它治理为五个逻辑独立的模块数据库边界。每个模块独立拥有 DbContext、schema、migration assembly、migration history、连接配置以及本模块的 Outbox/Inbox；生产数据库升级由独立 one-shot Migrator 执行，ApiHost 不再拥有 DDL 职责。

```text
SQL Server
└─ IFXDb
   ├─ auth        -> IfxDbContext         -> auth.__EFMigrationsHistory
   ├─ crm         -> CrmDbContext         -> crm.__EFMigrationsHistory
   ├─ registry    -> RegistryDbContext    -> registry.__EFMigrationsHistory
   ├─ holdings    -> HoldingsDbContext    -> holdings.__EFMigrationsHistory
   └─ transaction -> TransactionDbContext -> transaction.__EFMigrationsHistory
```

共享物理数据库是当前部署选择，不代表模块共享数据 ownership，也不允许通过同库能力绕过 Contracts、Adapters 或 Events。

## 非目标

- [ ] G02-N01 本 Gate 不把五个模块立即拆成五个物理数据库。
- [ ] G02-N02 本 Gate 不实现跨模块数据复制、报表 read model 或未来 Microservice 数据迁移。
- [ ] G02-N03 本 Gate 不设计租户删除后的完整生命周期和孤儿数据处理协议。
- [ ] G02-N04 本 Gate 不为所有模块立即配置独立生产数据库账号；但会建立迁移身份与运行身份的配置边界。
- [ ] G02-N05 本 Gate 不使用跨 schema FK、trigger、stored procedure 或共享 DbContext 强化模块一致性。

## 当前实现基线

| 事实 | 当前状态 | 风险 |
| --- | --- | --- |
| 模块 DbContext | Auth、CRM、Registry、Holdings、Transaction 已独立 | 基础健康 |
| 模块 schema | Entity Configuration 通过 `ToTable(..., schema)` 显式设置 | 新实体漏配时可能进入 `dbo` |
| 默认 schema | 五个 DbContext 均未设置 `HasDefaultSchema` | 缺少最后一道 ownership 防线 |
| 连接配置 | CRM/Registry/Holdings/Transaction 可回退 `DefaultConnection` | 配置边界不清晰 |
| migration history | 五个 DbContext 共用 `dbo.__EFMigrationsHistory` | ownership、权限和未来拆分耦合 |
| legacy adoption | 仅检查一个代表表即 stamp InitialCreate | partial schema 可被误判为完整 |
| Auth squash | 代码 ID 为 `20260317145706`，实际 migration 为 `20260327075710` | 可能重跑 InitialCreate 或破坏 history |
| migration 执行 | 每个 ApiHost 启动时顺序运行全部 Migrator | 多实例竞争、DDL 权限和发布耦合 |
| 容器顺序 | ApiHost 只等待 SQL Server healthy | 可能早于 `sqlserver-init` 完成 |
| migration 测试 | 集成测试移除 Migrator 并使用 EF InMemory | 无法发现真实 SQL/schema/history 问题 |

## 已确认架构决策

- [x] G02-D01 近期保留单一 `IFXDb`，以模块 DbContext 和 schema 形成逻辑数据库边界。
- [x] G02-D02 schema 是模块数据 ownership 边界，模块只拥有本 schema 内的对象。
- [x] G02-D03 禁止跨模块 FK、DbContext navigation、跨 schema join/trigger/procedure 和直接表访问。
- [x] G02-D04 每个 DbContext 设置 `HasDefaultSchema`，并以模型测试验证所有 relational entity 的 schema。
- [x] G02-D05 每模块必须使用独立连接配置键，即使当前连接值均指向 `IFXDb`。
- [x] G02-D06 Outbox/Inbox 归所属模块 DbContext 和 schema，不建立共享 Messaging DbContext。
- [x] G02-D07 每个模块使用本 schema 内的 `__EFMigrationsHistory`。
- [x] G02-D08 使用显式一次性 History Bootstrap，不在长期运行的 ApiHost 中自动猜测数据库状态。
- [x] G02-D09 Bootstrap 明确支持 fresh、current shared、known legacy 和 unknown/partial 四种状态。
- [x] G02-D10 Auth canonical InitialCreate ID 为 `20260327075710_InitialCreate`，兼容旧 migration 集及错误 squash ID。
- [x] G02-D11 legacy adoption 必须通过完整 schema fingerprint，不能只检查一个代表表。
- [x] G02-D12 Bootstrap 更新使用受控事务，整个升级任务使用数据库级互斥。
- [x] G02-D13 旧 `dbo.__EFMigrationsHistory` 在兼容窗口内只读保留，不长期双写。
- [x] G02-D14 migration ownership 由 assembly/build manifest 产生，不依赖手写全局 ID 或 ProductVersion。
- [x] G02-D15 history 切换前支持 dry-run 和恢复点，切换后执行 schema/history/pending-migration 验证。
- [x] G02-D16 建立独立 `IFX.DatabaseMigrator` one-shot executable/image。
- [x] G02-D17 生产 ApiHost 不执行 migration，只做只读 schema compatibility/readiness 检查。
- [x] G02-D18 使用显式模块 migration manifest 和稳定执行顺序，不依赖 DI 注册顺序。
- [x] G02-D19 对整个 `IFXDb` upgrade job 获取数据库级 application lock。
- [x] G02-D20 模块 migration 之间不建立全局大事务；失败即停止，修复后 roll-forward。
- [x] G02-D21 schema 发布采用 Expand/Contract，应用回滚不等同于数据库回滚。
- [x] G02-D22 migration identity 与 runtime identity 的连接配置和 secret ownership 分离。
- [x] G02-D23 将 DB10 纳入本 Gate，Compose 顺序为 SQL healthy → init → migrator → ApiHost。
- [x] G02-D24 使用真实 SQL Server Testcontainers 建立 migration 测试矩阵。
- [x] G02-D25 readiness 只读验证 required migrations，不执行 schema 修复或 DDL。

## 目标 ownership 矩阵

| 模块 | Schema | DbContext | Connection key | History | 消息表 |
| --- | --- | --- | --- | --- | --- |
| Auth | `auth` | `IfxDbContext` | `AuthDatabase` | `auth.__EFMigrationsHistory` | `auth.OutboxMessages` / `auth.InboxMessages`（按实际角色创建） |
| CRM | `crm` | `CrmDbContext` | `CrmDatabase` | `crm.__EFMigrationsHistory` | `crm.OutboxMessages` / `crm.InboxMessages` |
| Registry | `registry` | `RegistryDbContext` | `RegistryDatabase` | `registry.__EFMigrationsHistory` | `registry.OutboxMessages` / `registry.InboxMessages` |
| Holdings | `holdings` | `HoldingsDbContext` | `HoldingsDatabase` | `holdings.__EFMigrationsHistory` | `holdings.OutboxMessages` / `holdings.InboxMessages` |
| Transaction | `transaction` | `TransactionDbContext` | `TransactionDatabase` | `transaction.__EFMigrationsHistory` | `transaction.OutboxMessages` / `transaction.InboxMessages` |

## History Bootstrap 状态机

```text
                         +------------------+
                         | inspect database |
                         +---------+--------+
                                   |
               +-------------------+-------------------+
               |                   |                   |
             fresh         current shared          legacy
               |               history                 |
        normal migrate       exact copy          fingerprint
               |                   |             + normalize
               +-------------------+-------------------+
                                   |
                           module histories
                                   |
                              run pending
                                   |
                                validate

unknown / partial / fingerprint mismatch --> fail closed, no automatic stamp
```

## 生产部署流程

```text
CI artifacts
  ├─ ApiHost
  ├─ IFX.DatabaseMigrator
  ├─ module migration manifest
  └─ reviewable SQL scripts
            |
            v
backup / restore point
            |
database preflight + application lock
            |
history bootstrap (only when required)
            |
Auth -> CRM -> Registry -> Holdings -> Transaction
            |
schema/history validation
            |
deploy compatible Worker consumers
            |
Worker Ready
            |
deploy ApiHost producers
            |
readiness + smoke tests
```

## Phase 0 — 完成数据库资产盘点与迁移基线

- [ ] **Phase 0 完成**：数据库对象、migration、history 和部署路径均有可复查基线。

- [ ] G02-0.1 枚举五个 DbContext、全部 entity/table/index/constraint、schema 和 migration assembly。
- [ ] G02-0.2 生成当前 migration manifest，记录模块、MigrationId、ProductVersion、顺序和 migration source hash。
- [ ] G02-0.3 扫描所有跨 schema FK、view、trigger、procedure、raw SQL 和直接表访问，并记录结果。
- [ ] G02-0.4 盘点所有环境的连接配置键、目标数据库、数据库身份和 DDL/DML 权限。
- [ ] G02-0.5 盘点 fresh、EnsureCreated、pre-squash、错误 Auth squash、current shared history 等已知数据库状态。
- [ ] G02-0.6 保存生产/测试数据库的匿名化 schema 与 history 样本，禁止把 secret 或业务数据提交到仓库。
- [ ] G02-0.7 建立 migration 风险分级，标记 destructive DDL、长时间 backfill、锁表和不可逆操作。

## Phase 1 — 强化模块 schema 与连接配置边界

- [ ] **Phase 1 完成**：每个 DbContext、实体和配置都具有明确且可验证的模块 ownership。

- [ ] G02-1.1 为 auth、crm、registry、holdings、transaction 建立唯一模块 schema 常量。
- [ ] G02-1.2 在每个 DbContext 的模型配置中调用 `HasDefaultSchema(ModuleSchema.Name)`。
- [ ] G02-1.3 保留必要的显式 `ToTable(..., schema)`，并统一改用模块 schema 常量。
- [ ] G02-1.4 添加模型测试，断言所有 entity、owned type、join table、sequence 和数据库对象属于预期 schema。
- [ ] G02-1.5 移除 CRM/Registry/Holdings/Transaction 对 `DefaultConnection` 的隐式回退。
- [ ] G02-1.6 对缺失、空白和无效模块连接配置实施 fail-fast，并避免在日志中输出 secret。
- [ ] G02-1.7 添加静态/数据库检查，禁止模块 migration 创建其他模块 schema 中的对象。
- [ ] G02-1.8 为未来物理分库验证配置接缝：改变单模块连接值不要求修改 Application/Domain。

## Phase 2 — 建立模块独立 Migration History

- [ ] **Phase 2 完成**：五个 DbContext 使用独立 history，已有数据库可安全、幂等地切换。

- [ ] G02-2.1 为每个 DbContext 配置 `MigrationsHistoryTable("__EFMigrationsHistory", ModuleSchema.Name)`。
- [ ] G02-2.2 设计并实现 History Bootstrap preflight 和 `--dry-run`，在写入前输出状态分类与变更计划。
- [ ] G02-2.3 使用当前 migration assembly/build manifest 将旧 shared history 精确归属到模块。
- [ ] G02-2.4 在目标 schema 中创建兼容 EF Core 的 history table，并保留原 ProductVersion。
- [ ] G02-2.5 在受控事务内复制/规范化模块记录，保证失败不留下半迁移 history。
- [ ] G02-2.6 对整个 bootstrap/upgrade 获取 SQL Server database-level application lock，并设置明确超时。
- [ ] G02-2.7 未知 ID、重复 ownership、partial schema 或 fingerprint mismatch 必须 fail closed。
- [ ] G02-2.8 切换后验证每个 history 只包含本模块 ID，且各 DbContext pending migrations 符合预期。
- [ ] G02-2.9 旧 `dbo.__EFMigrationsHistory` 进入只读兼容期；建立归档/删除条件但不在首次切换删除。
- [ ] G02-2.10 证明重复执行 bootstrap 是无变化的幂等操作。

## Phase 3 — 修复 Auth Squash 与 Legacy Adoption

- [ ] **Phase 3 完成**：所有已知 Auth 历史状态都可安全规范化，未知状态不会被自动覆盖。

- [ ] G02-3.1 将 Auth canonical ID 修正为真实的 `20260327075710_InitialCreate`。
- [ ] G02-3.2 为 14 个 pre-squash IDs 建立受版本控制的 legacy manifest。
- [ ] G02-3.3 将错误 ID `20260317145706_InitialCreate` 定义为仅用于识别和修复的 legacy alias。
- [ ] G02-3.4 建立 Auth baseline schema fingerprint，覆盖关键表、列、PK、FK、unique constraints 和 indexes。
- [ ] G02-3.5 只有 fingerprint 完整匹配时才允许把 legacy/EnsureCreated 状态 adopt 为 canonical migration。
- [ ] G02-3.6 将 legacy history 删除、canonical 插入和验证放入同一个受控事务。
- [ ] G02-3.7 移除长期运行 Migrator 中“检查单表后自动 stamp”的逻辑。
- [ ] G02-3.8 为正确 current、14-ID legacy、错误 alias、partial legacy 和重复运行分别建立测试。

## Phase 4 — 建立 IFX.DatabaseMigrator 与模块 Manifest

- [ ] **Phase 4 完成**：独立 Migrator 可以确定性地升级并验证整个 IFXDb，而不启动 Web Host。

- [ ] G02-4.1 创建独立 `IFX.DatabaseMigrator` executable 和对应容器镜像/发布 artifact。
- [ ] G02-4.2 Migrator 只加载数据库升级所需服务，不启动 HTTP、后台任务、消息消费或业务宿主。
- [ ] G02-4.3 定义 manifest schema：ModuleName、DbContext、Schema、HistoryTable、ConnectionKey、Order/DependsOn 和 migration catalog。
- [ ] G02-4.4 以稳定顺序执行 History Bootstrap → Auth → CRM → Registry → Holdings → Transaction → validation。
- [ ] G02-4.5 检测缺失模块、重复顺序、循环 DependsOn、重复 MigrationId 和 manifest/assembly 不一致。
- [ ] G02-4.6 支持 preflight、dry-run、apply 和 validate 模式，并使用明确 exit code。
- [ ] G02-4.7 输出结构化日志和每模块报告：before/after version、applied IDs、duration、result 和 failure point。
- [ ] G02-4.8 不在协调器中定义模块表；每个模块 migration 仍归本模块 Infrastructure ownership。

## Phase 5 — 从 ApiHost 移除生产 DDL 并建立部署编排

- [ ] **Phase 5 完成**：数据库升级是独立发布步骤，ApiHost 只使用已验证 schema。

- [ ] G02-5.1 从生产 ApiHost startup 移除 `IAppMigrator` 执行路径。
- [ ] G02-5.2 为需要本地便利的迁移提供显式命令，不允许 API 隐式修改 schema。
- [ ] G02-5.3 在 CI 生成版本匹配的 Migrator artifact、module manifest 和每模块 idempotent SQL script。
- [ ] G02-5.4 数据库阶段固定为 preflight/backup → migrator → validation；随后按 Gate 04 执行 Worker consumers → API producers → readiness/smoke test。
- [ ] G02-5.5 使用独立 migration connection/secret；运行连接不承担 DDL 职责。
- [ ] G02-5.6 实现只读 schema compatibility/readiness，验证当前应用 required migrations 已存在。
- [ ] G02-5.7 数据库存在更新但向后兼容 migration 时允许旧实例继续运行，以支持 Expand/Contract 滚动发布。
- [ ] G02-5.8 修改 `docker-compose.yml` 与 NAS Compose：SQL healthy → init completed → migrator completed → ApiHost。
- [ ] G02-5.9 migration job 失败时阻断 ApiHost 新版本启动，且不会由 restart policy 无限热重试。
- [ ] G02-5.10 将每模块 required/compatible schema version 输出到 Gate 04 Release/Module Manifest，供 API 与 Worker 只读 readiness 校验。

## Phase 6 — Expand / Contract、失败与回退策略

- [ ] **Phase 6 完成**：部分升级、应用回退和 destructive migration 均有明确安全路径。

- [ ] G02-6.1 建立 Expand → deploy/read/write transition → backfill → Contract 的发布模板。
- [ ] G02-6.2 对 drop、rename、non-null、类型缩窄和大规模 backfill 强制架构/DB 审核。
- [ ] G02-6.3 禁止模块失败后自动执行 Down；默认停止部署、修复并 roll-forward。
- [ ] G02-6.4 明确部分模块已升级时的状态报告、ApiHost 阻断条件和安全重跑方式。
- [ ] G02-6.5 应用版本回退前验证 schema 向后兼容，禁止假设镜像回退等于数据库回退。
- [ ] G02-6.6 对确需数据库回退的 migration 生成并人工审核脚本，提前验证数据损失与恢复点。
- [ ] G02-6.7 建立 migration lock 超时、进程终止、连接中断和 validation failure 的恢复手册。
- [ ] G02-6.8 每次生产升级保存 manifest、SQL、日志、结果与批准记录，形成审计链。

## Phase 7 — 建立真实 SQL Server Migration 测试矩阵

- [ ] **Phase 7 完成**：fresh、upgrade、legacy、partial、并发和权限路径均有自动化测试。

- [ ] G02-7.1 使用现有 `Testcontainers.MsSql` 建立隔离的 SQL Server 2022 migration fixture。
- [ ] G02-7.2 测试 empty database → latest，验证五个 schema、history、表、约束和零 pending migrations。
- [ ] G02-7.3 测试 shared `dbo` history → module histories，验证精确复制与旧表只读保留。
- [ ] G02-7.4 测试 Auth 14-ID legacy、正确 canonical、错误 squash alias 和 mixed/partial 状态。
- [ ] G02-7.5 测试完整 EnsureCreated fingerprint 可显式 adopt，缺表/列/index 时 fail closed 且不改 history。
- [ ] G02-7.6 测试 previous release → latest，验证数据保留、Expand/Contract 兼容和重跑幂等。
- [ ] G02-7.7 测试两个 Migrator 并发执行，验证全局锁、等待/超时和单一执行者。
- [ ] G02-7.8 注入模块 N 失败，验证后续模块不执行、报告准确且修复后可继续。
- [ ] G02-7.9 测试 model ownership 与数据库 metadata，确保没有实体、history 或 FK 越过模块 schema。
- [ ] G02-7.10 测试 migration identity 可执行 DDL，runtime identity 只能完成所需 DML/readiness。
- [ ] G02-7.11 向 E2/E4 提供可复用 schema ownership 和 fresh/upgrade migration assertions；Event 实施真实 Outbox/Inbox migration 后回交测试报告作为最终关闭证据。
- [ ] G02-7.12 在 CI 运行 build、pending-model 检查、migration matrix 和 SQL artifact 生成。

## Phase 8 — 渐进上线与兼容窗口

- [ ] **Phase 8 完成**：真实环境已切换至模块 history 和独立 migration job，旧路径安全退出。

- [ ] G02-8.1 在可恢复的非生产数据库完整演练 preflight、bootstrap、migrate、validate 和 rerun。
- [ ] G02-8.2 对生产数据库执行 dry-run，人工核对状态分类、history mapping、fingerprint 和变更清单。
- [ ] G02-8.3 创建并验证备份/恢复点后运行一次性 history bootstrap。
- [ ] G02-8.4 部署独立 Migrator job，并在 ApiHost 发布前完成全部模块 validation。
- [ ] G02-8.5 观察一个约定兼容窗口，确认 migration、readiness、业务读写和部署回退行为稳定。
- [ ] G02-8.6 关闭 ApiHost runtime migration 开关，删除普通启动路径中的 DDL 权限。
- [ ] G02-8.7 将旧 shared history 标记为 archived/read-only；删除必须另行审批且不作为首次 Gate 关闭要求。
- [ ] G02-8.8 清理单表自动 stamp、硬编码 ProductVersion 和旧错误 canonical ID 逻辑。

## Phase 9 — 架构与规则文档化

- [ ] **Phase 9 完成**：数据库边界、迁移机制、部署和恢复规则已形成可维护的中英文图文基线。

- [ ] G02-9.1 创建中文设计文档 `docs/architecture/review/gates/G02/database-boundary.zh-CN.md`。
- [ ] G02-9.2 创建对应英文文档 `docs/architecture/review/gates/G02/database-boundary.en.md`，保持决策编号一致。
- [ ] G02-9.3 文档解释物理共库与逻辑分库、schema ownership、禁止跨 schema 访问及未来分库接缝。
- [ ] G02-9.4 创建数据库边界架构图，展示模块、DbContext、schema、history、连接和 Outbox/Inbox ownership。
- [ ] G02-9.5 创建 History Bootstrap 流程图和状态机，覆盖 fresh/current/legacy/unknown/partial。
- [ ] G02-9.6 创建 production migration deployment 流程图，展示 CI artifact、lock、执行顺序、validation 和 ApiHost gate。
- [ ] G02-9.7 创建失败恢复状态图，覆盖 partial upgrade、lock timeout、migration failure、rollback 与 roll-forward。
- [ ] G02-9.8 创建 Expand/Contract 时序图，说明旧/新应用版本和 schema 的兼容窗口。
- [ ] G02-9.9 Mermaid 源文件与可直接查看的 SVG/PNG 一并保存，并完成渲染检查。
- [ ] G02-9.10 文档包含 manifest schema、命令示例、dry-run 输出、常见错误、禁止模式和运行手册。
- [ ] G02-9.11 将每条数据库规则映射到 model test、migration test、CI check、readiness 或人工审批。
- [ ] G02-9.12 更新架构索引、Gate Plan 和 TODO 反向链接，并完成中英文一致性审查。

## Phase 10 — Gate 关闭与 Plan 00 交接

- [ ] **Phase 10 完成**：Gate 02 已批准关闭，并为 Contracts/Event 实施提供稳定数据库边界。

- [ ] G02-10.1 对照 DB1–DB4、DB9–DB11 附上 ADR、代码、migration、测试、部署和文档证据。
- [ ] G02-10.2 在 [`00-prerequisites.md`](00-prerequisites.md) 勾选 Gate 2 相关事项，仅在全部实施和文档完成后操作。
- [ ] G02-10.3 确认 Gate 01 的本地事务规则与本 Gate 的 DbContext/schema ownership 完全一致。
- [ ] G02-10.4 向 Event 子计划交付每模块 Outbox/Inbox 表归属、migration 与测试接缝。
- [ ] G02-10.5 将数据库账号最小权限、租户生命周期、跨模块 read model 和未来物理分库继续保留在 TODO。
- [ ] G02-10.6 记录 waiver、owner、到期日和删除条件，并由架构、数据库和运维负责人批准 Gate 关闭。

## Definition of Done

- [ ] G02-DD01 五个模块具有独立 DbContext、schema、connection key、migration assembly 和 schema 内 history。
- [ ] G02-DD02 数据库不存在未批准的跨模块 FK、navigation、join、trigger、procedure 或直接写入。
- [ ] G02-DD03 Auth legacy、错误 squash ID、shared history 和 EnsureCreated adoption 均安全且可重复处理。
- [ ] G02-DD04 `IFX.DatabaseMigrator` 独立执行、全局互斥、失败阻断、可重跑并输出完整报告。
- [ ] G02-DD05 生产 ApiHost 不执行 DDL，只读 readiness 能识别 required migration 缺失。
- [ ] G02-DD06 Compose 和生产部署均保证 database/init/migrator/Worker/API 的确定顺序，并与 Gate 04 consumer-first 编排一致。
- [ ] G02-DD07 真实 SQL Server migration matrix、故障测试、build 和架构检查全部通过。
- [ ] G02-DD08 中英文说明、架构图、流程图、状态图和规则验证映射全部完成并审核。

## 回退原则

- [ ] G02-R01 首次 history 切换不删除旧 `dbo.__EFMigrationsHistory`，保留审计与恢复依据。
- [ ] G02-R02 Bootstrap 写入必须可整体回滚；unknown/partial 状态不得自动修复。
- [ ] G02-R03 模块 migration 失败后停止并优先 roll-forward，不自动跨模块执行 Down。
- [ ] G02-R04 应用回退前验证 schema compatibility；destructive database rollback 必须使用已审核脚本和恢复点。
- [ ] G02-R05 任何生产回退都记录数据库状态、已执行 MigrationId、数据影响、恢复验证和再次发布条件。

## 参考

- [ ] G02-REF01 EF Core：自定义 Migration History Table，并明确已迁移数据库的 history 更新由应用负责：<https://learn.microsoft.com/en-us/ef/core/managing-schemas/migrations/history-table>
- [ ] G02-REF02 EF Core：生产 migration scripts、bundles、runtime migration 风险和独立部署身份：<https://learn.microsoft.com/en-us/ef/core/managing-schemas/migrations/applying>
