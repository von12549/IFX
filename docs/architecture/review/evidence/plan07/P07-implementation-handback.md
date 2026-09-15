# Plan 07 — Contract Adapter 公共运行组件实施回交

> 完成日期：2026-09-15
> 迁移基线：`38af6dbb4c5d401bd95907b2bb15ce3d60bc5581`
> 分支：`feature/architecture-boundary-implementation`
> 结果：Phase 0–6 repository implementation complete；G03/G05 lifecycle 状态未改变。

## 实施结果

| Phase | 结果 |
| --- | --- |
| 1 | 新增 `IFX.Platform.Context.Runtime`，集中同步 Contract 的 fail-closed context validation、provider child context、outbound request context 和强类型 component identity。Runtime 只引用 Context Contracts 与 BuildingBlocks Application context。 |
| 2 | CRM/Registry/IAM Inbound Adapter 改为选择不可变 policy 并委托公共 validator；CRM/Registry 继续建立 provider child scope，IAM 继续使用拒绝响应且不新增 child scope。Holdings EventEnvelope 验证保持独立。 |
| 3 | 五份等价 `ResourceAttributes` 收敛为 BuildingBlocks Security primitive；新增 provider-owned `IFX.Modules.IAM.Client`，集中 IAM V1 DTO/context/call/deny 映射。五个模块自有 Application Port 均保留。 |
| 4 | CRM/Registry/Holdings/Transaction IAM Adapter 成为固定 consumer identity 的薄 Port 实现。Transaction→CRM/Registry 使用公共 outbound factory；两个布尔调用共享只捕获 typed protocol/context/timeout 异常的内部 helper。 |
| 5 | DI 生命周期固定为 validator/outbound factory/client scoped、provider factory singleton。LayerGuard 新增 `Client` ring，只允许 Infrastructure/Composition 使用；五个结构测试保护依赖闭包、context 构造唯一性和模块 Port 接缝。 |
| 6 | 双语边界说明、同步调用图、LayerGuard 说明、计划索引和本回交均更新到最终源码结构。 |

## 重复点迁移前后

| 检查项 | Phase 0 | 完成后 |
| --- | ---: | ---: |
| 模块 Integration 直接构造 `ContractRequestContext` | 5 | 0 |
| CRM/Registry 私有 context validation 算法 | 2 | 0；只保留 failure→本 Contract 语义映射 |
| CRM/Registry 私有 provider child context 算法 | 2 | 0 |
| 重复 IAM V1 context/DTO/call/deny 实现 | 4 | 1 个 provider-owned client |
| Application `ResourceAttributes` 定义 | 5 | 1 个批准的非版本化 Security primitive |
| Transaction 布尔调用异常壳 | 2 | 1 个 Infrastructure 内部 typed helper |

唯一的模块内 `Validate(EventEnvelope)` 仍位于 Holdings event inbound handler。它验证 producer、schema、tenant、Inbox/quarantine 语义，不属于同步 Contract runtime。

## 最终依赖与装配

```text
Consumer.Application
  → own IResourceAuthorizationService
  → Consumer.Infrastructure ResourceAuthorizationAdapter (fixed identity)
  → IAM.Client
       → IAM.Contracts.V1
       → Platform.Context.Runtime
       → BuildingBlocks.Security
  → IAM.Infrastructure Inbound Adapter
  → IAM.Application policy

Provider.Contracts
  ← Provider.Infrastructure Inbound Adapter
       → Platform.Context.Runtime validator/factory
       → Provider.Application use case
```

- Solution 从 79 增至 81 个项目，仅新增 Context Runtime 与 IAM Client。
- `IFX.Platform.Context.Runtime` 没有模块依赖；`IFX.Modules.IAM.Client` 没有消费模块或 IAM Application/Infrastructure 依赖。
- CRM、Registry、Holdings、Transaction Infrastructure 引用 IAM Client，不再直接引用 IAM Contracts。
- Application/Domain 没有引用模块 Contracts、IAM Client、Context Runtime 或 foreign Infrastructure。
- 每个消费模块继续注册唯一 `IResourceAuthorizationService → ResourceAuthorizationAdapter`；公开 provider Contract 继续只有一个 Inbound Adapter 实现。

## 协议与安全对账

- 相对迁移基线，`src/**/Contracts` 没有文件变更；V1 public signature、serialization shape、identity、consumer allowlist 和稳定错误码未改变。
- Inbound 继续按 consumer → version/scope → provenance/ambient actor/scope/tenant → resource tenant 顺序 fail closed；验证发生在 Application/data Port 前。
- IAM consumer identity 由四个具体 Adapter 固定，不能从请求、资源或配置覆盖。缺失/不可信 context、runtime parameters 和 provider deny 均返回固定外部语义；provider denial reason 不外泄。
- RequestId 每次创建，CorrelationId 继承，CausationId 使用调用方当前 OperationId；CRM/Registry provider child context 创建新 OperationId 并保留调用链。
- 调用方取消继续传播；Transaction 的 timeout、typed Contract failure 和 typed context failure 继续映射为 `false`，没有 catch-all 或异常消息前缀判断。
- 本次没有修改 DbContext、实体、migration、Outbox/Inbox、EventEnvelope 或事件 transport，因此无需数据库 migration，也无需重复数据库故障注入；完整 DatabaseBoundary 与 solution tests 仍已运行。

## 自动化证据

| 验证 | 结果 |
| --- | --- |
| Protocol Contracts | 85/85 passed（基线 77，新增 8 个 Context Runtime 测试） |
| IntegrationTests | 211/211 passed（基线 203，新增 IAM Client 行为与 5 个结构守卫） |
| 完整 `IFX.sln` build | 81 projects，0 errors；既有 NU1603/NU1903 warnings 保持 |
| 完整 `IFX.sln` tests | 1,269/1,269 passed |
| LayerGuard tool tests | 192/192 passed |
| LayerGuard strict scan | 51 governed projects，0 findings，Plan 07 baseline 0 entries |
| G03 catalog/source reconciliation | passed |
| G03 LayerGuard governance | passed |
| G05 Phase 9 context boundary | passed |

生成证据：

- [`layerguard-phase5.json`](layerguard-phase5.json)
- [`layerguard-final.json`](layerguard-final.json)
- [`layerguard-unbaselined.json`](layerguard-unbaselined.json)
- [`dependency-graph.json`](dependency-graph.json)
- [`g03-contract-event-catalog.json`](g03-contract-event-catalog.json)
- [`g03-layerguard-governance.json`](g03-layerguard-governance.json)
- [`g05-context-boundary.json`](g05-context-boundary.json)

## 最终扫描

- `src/Modules/Auth` 不存在，solution/project reference 不包含退休 Auth 项目。
- Transaction 私有 `ContractRequestContextFactory` 已删除，没有旧 helper、字符串型 `contract_` 异常识别、重复 `ResourceAttributes` 或模块 Integration 直接 context 构造。
- 新项目均在 solution 中；工作树没有构建生成的未跟踪源码目录。
- G03/G05 仍按现有 Gate 文档保持各自 lifecycle 状态；本计划只完成 repository conformance，不代替外部审批或生产证据。
