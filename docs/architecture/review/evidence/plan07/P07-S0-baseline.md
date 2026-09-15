# Plan 07 Phase 0 — Contract Adapter 重复与行为基线

> 记录日期：2026-09-15
> 源码基线：`38af6dbb4c5d401bd95907b2bb15ce3d60bc5581`
> 分支：`feature/architecture-boundary-implementation`
> 状态：Phase 0 完成；本文件记录实施前事实，不代表后续 Phase 已完成。

## 仓库与验证基线

- Phase 0 开始时工作树干净，solution 包含 79 个项目。
- `dotnet test tests/IFX.IntegrationTests/IFX.IntegrationTests.csproj --no-restore --nologo -v:q`：203/203 passed。
- `dotnet test tests/IFX.Platform.ProtocolContracts.Tests/IFX.Platform.ProtocolContracts.Tests.csproj --no-restore --nologo -v:q`：77/77 passed。
- `scripts/Invoke-LayerGuard.ps1`：LayerGuard tests 192/192 passed；strict repository scan passed；基线报告见 [`layerguard-baseline.json`](layerguard-baseline.json)。
- 运行中出现的 NU1603、NU1903、CS8601/CS8604 与 obsolete endpoint warning 已存在于 Plan 06 基线，本 Phase 未修改依赖或代码，不将其误记为 Plan 07 引入。

## 重复实现清单

| 分类 | 基线数量 | 观察 |
| --- | ---: | --- |
| 模块 Integration 中直接构造 `ContractRequestContext` | 5 | 四个 IAM Outbound Adapter 各一处，Transaction 私有 factory 一处 |
| 私有同步 Inbound `Validate` | 2 | CRM/Registry 算法等价，仅异常类型不同；IAM 为内联相似政策 |
| 私有同步 Inbound `CreateChildContext` | 2 | CRM/Registry 仅 provider component 不同 |
| IAM Outbound `ResourceAuthorizationAdapter` | 4 | CRM/Registry/Holdings/Transaction 除模块 Port 与 source component 外同构 |
| Application `ResourceAttributes` | 5 | CRM/Registry/Holdings/Transaction/IAM 字段、nullability 与泛型 Port 约束一致 |
| Transaction fail-closed boolean Contract 调用 | 2 | CRM/Registry 的取消、timeout、Contract/context failure 处理同构 |

Holdings `HoldingsInboundIntegrationEventHandler.Validate(EventEnvelope)` 不属于同步 Contract context 重复。IAM Authentication/Authorization provider adapters 与 CRM/Registry Persistence adapters 也没有经证明可共享的同一算法，均不进入本计划的强制提取范围。

## 冻结的行为矩阵

### Provider Inbound

- CRM/Registry：只允许 `ifx.transaction.v1`，要求 current context version、trusted provenance、ambient actor/scope/tenant 一致和 tenant resource match；验证通过后建立 provider child scope。
- CRM/Registry：consumer/context/tenant 分别映射现有稳定 Contract code；业务 `false` 仍是正常响应；调用方取消继续传播；其他内部异常归一为 `contract_unavailable`。
- IAM：允许 `crm|registry|holdings|transaction`，只接受 user actor；tenant scope 时资源 tenant 必须匹配；失败返回现有 deny response，不改为 CRM/Registry 异常模型；不强制新增 provider child scope。

### Consumer Outbound

- 四个 IAM Adapter：拒绝 runtime parameters；要求 trusted ambient execution context；创建新 RequestId、继承 CorrelationId、以当前 OperationId 为 CausationId；source component 固定为消费模块；完整映射六个 resource 字段；provider deny 转为 `ForbiddenException`。
- Transaction→CRM/Registry：tenant scope/context mismatch fail closed；调用方取消传播；timeout、对应 Contract Exception 和 context failure 返回 `false`。

## 协议与依赖冻结

- Plan 06 的 G03 public API、serialization golden、catalog identity、consumer allowlist 和 G05 context 规则是 Plan 07 的不变输入。
- Provider Contracts 继续只含 V1 接口/DTO/错误；Application 继续拥有业务用例和模块 Port；具体 Inbound/Outbound Adapter 继续存在于模块 Infrastructure。
- 新的 Context Runtime 不得依赖模块；新的 IAM Client 不得依赖任何消费模块或 IAM Application/Infrastructure，并且不得被 Domain/Application 引用。
- 本计划不修改 Integration Event、Outbox/Inbox、数据库 schema、IAM policy、业务判断、传输或发布边界。
