# Plan 06 — 分阶段实施与回交证据

> 后续重构：[Plan 07 实施回交](../plan07/P07-implementation-handback.md) 集中了同步 Contract context runtime 与 IAM client；本文件继续保留 Plan 06 完成时的历史事实。

> 记录日期：2026-09-15；工作树实施，尚未提交。Phase 0 基线见 [P06-S0](P06-S0-baseline.md)。Docker 数据库测试、LayerGuard、G03/G05 与全解方案验证均已完成；本文件不把 repository automation 结果扩大为生产环境验收。

## 源码迁移

| Phase | 已实施并复核的变化 |
| --- | --- |
| 1 | CRM/Registry Application 定义自有查询用例，数据判定仍经各自数据 Port；IAM Application 保留本地授权用例；Registry/Transaction Application 增加不可变内部事实。Registry 关闭类、Transaction 处理交易及确认订单均在原业务成功路径记录事实。 |
| 2 | CRM、Registry、IAM 的公开同步接口改由各自 Infrastructure `Integrations/Inbound` 实现。CRM/Registry 在委托用例前验证 consumer、version、trusted ambient context、scope、actor 与 tenant，再建立 provider child scope；IAM 入口保留本地授权政策与拒绝语义。Composition 中公开接口各只有一个实现。旧 Application 公开 façade 已删除。 |
| 3 | 所有模块 `Infrastructure/Integrations` 均按方向归入 `Inbound` 或 `Outbound/<provider>`；CRM/Registry 数据 Port Adapter 位于 `Outbound/Persistence`。Transaction→CRM/Registry 出站 Adapter 继续实现 Transaction-owned Port。真实进程内链验证了新 RequestId、Correlation/Causation、子 scope、数据 Port 与返回后 scope 恢复。四个模块的 IAM 出站 Adapter 及 IAM 入站测试保持通过。 |
| 4 | Registry/Transaction Application 停止构造公开 V1 事件。Infrastructure 显式 mapper 在 `OutboxParticipant.PrepareAsync` 中构造原 V1 payload，沿用既有 EventType、SchemaVersion、producer、tenant、Envelope、分区与重试路径。未知内部事实抛异常，不能静默丢弃。Holdings V1 入口未改。 |
| 5 | CRM、Registry、IAM、Transaction Application 均移除各自 `*.Contracts.csproj` 直接引用；IAM 对批准的 `IFX.Platform.Context.Contracts` 增加显式引用。LayerGuard 现在拒绝 Application→任意模块 Contracts，保留登记的 shared primitives；Outbound Adapter 必须实现 own Application Port，Inbound Adapter 必须实现 own provider Contract。Windows CRLF 下的 Gate artifact hash 校验先比较原始 bytes，再比较只规范化 CRLF 的文本 hash。 |
| 6 | Plan 01/02 的历史实现口径、总计划、双语目标设计、严格边界说明及目标调用链 Mermaid 源文档已更新；G03/G05 原有 protocol identity、字段、consumer 和 lifecycle 未改。Plan 06 的 G03/G05/LayerGuard/数据库与全量测试证据均保存在本目录。 |

## 迁移后调用与依赖

```text
Transaction.Application Port
  -> Transaction.Infrastructure.Integrations.Outbound
  -> CRM/Registry.Contracts.V1
  -> CRM/Registry.Infrastructure.Integrations.Inbound
  -> CRM/Registry.Application 自有用例
  -> 提供方 Application 数据 Port -> 提供方 Infrastructure 数据 Adapter

CRM/Registry/Holdings/Transaction.Infrastructure IAM 出站 Adapter
  -> IAM.Contracts.V1
  -> IAM.Infrastructure.Integrations.Inbound
  -> IAM.Application.Access.ResourceAuthorizationService

Registry/Transaction.Application 内部事实
  -> 同模块 Infrastructure V1 mapper + OutboxParticipant.PrepareAsync
  -> 原 V1 payload + Envelope + 同本地事务 Outbox
  -> Dispatcher/transport
  -> Holdings.Infrastructure V1 验证/Inbox/quarantine/命令转换
  -> Holdings.Application
```

```text
CRM/Registry/IAM/Transaction.Application -> own Domain, BuildingBlocks, approved Platform.Context.Contracts (where used)
CRM/Registry/IAM/Transaction.Application -X-> own public *.Contracts
Provider.Infrastructure -> own Application + own Contracts
Transaction.Infrastructure.Outbound -> Transaction.Application Port + registered provider Contracts
Holdings.Infrastructure.Inbound -> registered producer event Contracts + Holdings.Application
```

## 已通过的验证

- `dotnet build src/ApiHost/IFX.ApiHost/IFX.ApiHost.csproj --no-restore --nologo -v:q`：0 error。
- `dotnet build tests/IFX.DatabaseBoundary.Tests/IFX.DatabaseBoundary.Tests.csproj --no-restore --nologo -v:q`：0 error；只证明 SQL 测试可编译。
- `dotnet test` 的受影响 Application 测试：CRM 34、Registry 43、IAM 263、Transaction 50，均 0 failed。
- `dotnet test tests/IFX.IntegrationTests/IFX.IntegrationTests.csproj --no-restore --nologo -v:q`：203 passed、0 failed，包含提供方入口验证、IAM、DI 唯一性、真实进程内同步链、事件映射与未知事实拒绝、Holdings 入站路径、项目依赖检查、Integrations 方向目录守卫，以及已退役 Auth 目录/引用防回归守卫。
- `dotnet test tests/IFX.Platform.ProtocolContracts.Tests/IFX.Platform.ProtocolContracts.Tests.csproj --no-restore --nologo -v:q`：77 passed、0 failed，覆盖 V1 schema/context/Event Envelope conformance。
- `dotnet test ... --filter FullyQualifiedName~Plan02ReliableMessagingSqlServerTests`：8 passed、0 failed，覆盖 Registry/Transaction 业务行与 Outbox commit/rollback，以及 Holdings Inbox 幂等、quarantine、ack-loss 等数据库路径。
- `scripts/Invoke-LayerGuard.ps1`：192/192 LayerGuard tests passed（含 Windows CRLF binding 回归）；真实源码 0 violation，Plan 06 baseline 为 0 entry、0 new、0 stale。报告：[layerguard.json](layerguard.json)。
- `scripts/Invoke-G03SourceReconciliation.ps1` 与 `scripts/Invoke-G03ContractEventGuard.ps1 -Phase 9`：passed。重建的同步 API snapshot 与 serialization golden 和权威文件无 diff；报告：[source reconciliation](g03-source-reconciliation.json)、[Phase 9](g03-phase9-guard.json)。G03 closure 仍为 `pre-ready`。
- `scripts/Invoke-G05ContextBoundaryGuard.ps1 -Phase 9`：passed；报告：[G05 context boundary](g05-phase9-context-boundary.json)。
- `scripts/Invoke-G05Verification.ps1`：`IFX.sln` build 0 error；migration safety、LayerGuard、G05 cumulative checks 均通过；全解方案 1251/1251 tests passed，其中 DatabaseBoundary 122/122。汇总：[verification-summary.json](g05-verification/verification-summary.json)。
- 删除 `src/Modules/Auth` 后再次执行 `dotnet build IFX.sln --no-restore`：0 error，构建结束后目录仍不存在；扫描 79 个实际 csproj，全部 `ProjectReference` 可解析且没有 Auth 项目引用。随后新增的防回归测试已随 202 个 IntegrationTests 通过。
- Integrations 目录归一化后再次执行 `dotnet build IFX.sln --no-restore`：0 error；LayerGuard 192/192、IntegrationTests 203/203、Plan 02 定向 SQL 8/8 均通过。Plan 02 C5 路径兼容门禁结果为 `repository-passed-release-rehearsal-pending`，Plan 04 projection policy 为 `repository-passed-no-reporting-product-claimed`，保持各自既有外部验收状态。
- `git diff --check`：exit 0。G03 catalog、同步 API snapshot、serialization golden、G05 context protocol 的 Git blob hash 与 Phase 0 完全一致，分别为 `d16ad9738aa02e1cc99f2ad53e1d288809389a9f`、`457a501a7a7524f47b8dcda071956e34719cf3cd`、`1bb65f88676ff736ab9656810677f5e0a31892f6`、`f0f3601a4fd108d13b24521596b2ac8b89c5e085`。

## 边界与后续治理

1. 本记录不变更已有 Active/Proposed lifecycle，也不代表生产环境安全或发布验收。G03 审计仍为 `pre-ready`；live IdP、生产 telemetry 与 named approvals 继续由既有 Gate owner 负责。
2. 同一进程中的 `SourceComponent` 是受控代码路径的 allowlist 声明，不是模块身份凭证。当前入口额外核对 trusted ambient context 的 actor、scope 与 tenant；若引入不可信插件或网络载体，必须先在传输/宿主边界验证调用者身份并构造可信上下文。
3. 遗留的未跟踪 `src/Modules/Auth` 已清理。`IFX.sln` 仅包含 IAM 项目；79 个实际 csproj 的全部 `ProjectReference` 均可解析且没有 Auth 引用。新增集成守卫，若旧目录或项目引用再次出现会使测试失败。代码中的旧 `IFX.Modules.Auth.Application` 字符串仅用于已持久化 Hangfire job 的 IAM 类型别名兼容，不是程序集/项目依赖，也不会创建目录。

既有 NuGet `NU1603`（AWSSDK 解析到 3.7.402）及 `NU1903`（AutoMapper、MemoryCache advisories）仍在输出中，本次未改依赖版本。
