# Plan 01：Contracts / Ports / Adapters 实施基线（B2）

> English: [plan01-contracts-adapters-boundary.en.md](plan01-contracts-adapters-boundary.en.md)
> 状态：B2 完成；Plan 02 / B3、B4 与 Gate Final Closure 保持开放。
> 后续变更：[Plan 06](plans/06-contract-adapter-event-boundary.md) 将公开接口实现移至提供方 Infrastructure Inbound Adapter；下文记录 B2 当时的实施基线。
> 权威治理：[G03 catalog](gates/G03/contract-event-catalog.yaml) · [G05 context boundary](gates/G05/context-sensitive-data-boundary.zh-CN.md) · [B2 evidence](evidence/plan01/B2-status.json)

## 结果

两个真实同步依赖已经迁移为提供方拥有的最小 V1 Contract 与消费方拥有的 Port。CRM/Registry Application 实现业务能力，Infrastructure 只实现本地数据 Port；Transaction.Infrastructure 的 Adapter 是唯一跨模块桥接点。Transaction.Application 不再引用 CRM/Registry Contract 或旧 Abstractions。

`*.Contracts` 只依赖 BCL 与 G05 批准的 `IFX.Platform.Context.Contracts`。它不包含 DI、EF、MediatR、日志或传输实现。ApiHost 仍只调用模块 Composition；模块保持同一业务 release，不产生独立部署承诺。

## 边界与运行语义

- 调用方 Adapter 从可信 `IExecutionContextAccessor` 创建全新 RequestId，继承 CorrelationId，并以当前 OperationId 作为 CausationId；业务代码不能伪造 source、actor 或 tenant。
- 提供方在读取数据前验证 context version、registered consumer、trusted provenance、tenant scope 与 request tenant；然后创建隔离的 provider child scope。
- `not-found`、未批准或关闭返回 `false`；调用方取消继续传播；超时、提供方不可用、协议或 tenant 不一致均 fail closed。
- Contract 只暴露 capability 所需标识与布尔判定。CRM `isApproved` 是已批准的 C3 decision-only 字段，响应期存活且禁止日志记录；C4 暴露为零。

## 迁移映射

| 旧表面 | B2 目标 | 结果 |
| --- | --- | --- |
| `ICrmReader.IsInvestmentAccountKycApprovedAsync` | `IAccountComplianceContract` → Transaction `IAccountCompliancePort` | Active V1；旧 Reader/实现删除 |
| `IRegistryReader.IsClassOpenForSubscriptionAsync` | `IClassSubscriptionAvailabilityContract` → Transaction `IClassSubscriptionAvailabilityPort` | Active V1；旧 Reader/实现删除 |
| CRM/Registry 其他 Reader 方法与 DTO | 无外部消费或提供方内部模型 | 公共表面 Retired/删除 |
| `IHoldingsReader`、`ITransactionReader` 与 DTO | Application-owned query/result model 或无消费 | 公共 Reader/DTO Retired/删除 |
| 四个 `*.Abstractions` 项目中的事件 | Plan 02 / B3 | 明确保留，未宣称完成 |

## 可替换点与验证

Composition 目前注册进程内 Adapter。未来 HTTP/gRPC 实现只需替换 Transaction Port 的外层实现；Transaction Application 与提供方业务规则无需修改。装配测试验证每个 Provider Contract 与 Consumer Port 仅有一个实现。

图示源文件与渲染：[Mermaid](diagrams/plan01-contract-boundary.mmd) · [SVG](diagrams/plan01-contract-boundary.svg) · [PNG](diagrams/plan01-contract-boundary.png)。B2 对 B1 为 103 matched、0 new、13 stale；正式 B2 为 103 matched、0 new、0 stale。字段/上下文/运行传播仍由 G03/G05 专用校验与真实测试负责，LayerGuard 只判断结构边界。

## 新增同步能力检查清单

1. 先在 G03 登记唯一 identity、owner、真实 consumer、字段分类与 Change Record。
2. Provider-owned Contracts 保持 BCL + approved context primitives；Consumer Application 定义自己的 Port。
3. 外层 Adapter 映射 DTO、错误、取消与可信 context；Provider 重新验证 consumer/scope/tenant。
4. 提交 provider contract、consumer compatibility、DI uniqueness、G05 conformance 与 LayerGuard 证据后才可 Active。
