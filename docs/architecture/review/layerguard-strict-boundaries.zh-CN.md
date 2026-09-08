# LayerGuard 严格边界规则（B4）

[English](layerguard-strict-boundaries.en.md) · [B4 证据](evidence/03-b-layerguard-strict-closure.md) · [执行计划](plans/03-layerguard-alignment.md)

## 状态与范围

自 2026-09-09 起，仓库使用 B4 严格策略。39 个受管项目为零 finding、零 waiver；
`mcp/LayerGuard/baselines/b4.json` 没有 entry。`scripts/Invoke-LayerGuard.ps1` 是本地和 CI
统一入口。工具无法完成扫描、Gate 输入缺失或 hash 漂移、出现新 finding、baseline
陈旧/过期，均以非零退出码失败。

LayerGuard 只判断编译期结构：项目引用、传递依赖、using、声明位置、框架/包泄漏、
ownership 与 provider graph。字段分类、运行值、tenant/trace 传播、脱敏、投递、幂等和
replay 语义分别由 G03 catalog/validator 与 G05 schema/security/runtime tests 负责；任一
报告绿色都不能覆盖另一报告失败。

## 项目识别与目标矩阵

| 角色 | 命名 | 可以依赖 |
| --- | --- | --- |
| Domain | `IFX.Modules.*.Domain` | 经批准的 Domain primitives |
| Contracts | `IFX.Modules.*.Contracts`、`IFX.Platform.*.Contracts` | BCL 与 G05 批准的 contract primitives |
| Application | `IFX.Modules.*.Application` | own Domain、own Contracts、批准的 BuildingBlocks/Context primitives |
| Presentation | `IFX.Modules.*.Presentation` | own Application/Domain/Contracts |
| Integration Adapter | 独立 Integration 项目或 `Infrastructure.Integrations` namespace | own Application Port、G03 登记的 provider Contracts |
| Infrastructure | 模块 Infrastructure、平台 `Infrastructure.*` | own Application/Domain/Contracts、受限 Runtime/平台 primitives |
| Runtime | `IFX.Platform.*.Runtime` | Contracts |
| Composition | 模块/平台 Composition | 自有各层与必要平台运行项目 |
| Runtime Host | `IFX.ApiHost`、`IFX.*.Worker` | Composition 与批准的 host primitives |

ownership 来自 G03 权威 catalog 的生成视图，不在 `src/layerguard.json` 复制。Runtime
role 来自 G04 artifacts；Context/Messaging primitive 许可来自 G05。module/platform
`*.Abstractions` 不再识别为 Contracts，且项目名仍被明确禁止。历史 `App.Abstractions`
是 G01/G04 批准的 BuildingBlocks host primitive，不是模块间 Contract 兼容层。

## 核心规则、诊断与修复

| 规则 | 合法例 | 非法例 / 常见诊断 | 修复 |
| --- | --- | --- | --- |
| own/foreign | Application → own Domain | Application → foreign Contracts；`OWNERSHIP-REFERENCE` | 在消费方 Application 定义 Port，在外层 Adapter 调 provider Contract |
| Domain isolation | Domain → BuildingBlocks.Domain | Domain → Contracts；`RING-DIRECTION` | 将公共传输类型移出 Domain 逻辑，Domain 保持独立 |
| provider graph | Adapter → catalog 登记 provider Contracts | 未登记 provider 或同步环；`PROVIDER-CONTRACT`/`PROVIDER-CYCLE` | 更新真实设计及 G03 catalog，不能复制 allow-list 绕过 |
| host boundary | ApiHost → module Composition | ApiHost → Application/Domain；`RING-DIRECTION`/`IMPORT-DIRECTION` | 在 Composition 暴露 host-safe façade/DTO |
| Contracts purity | record/DTO 使用 string、Guid、DateTimeOffset | EF/MediatR/ASP.NET/DI/broker/JWT/ILogger；`RING-PACKAGE*`/`SYMBOL-FORBIDDEN` | 将行为与框架适配移到 Application/Infrastructure |
| declaration placement | `*IntegrationEvent` 位于 provider `Contracts.Events` | Handler/Repository/DbContext 位于 Contracts；`DECLARATION-*` | 移到 Application 或 Infrastructure |
| payload boundary | Event payload 只含批准 primitives | payload 暴露 Domain entity/DbContext；`PAYLOAD-TYPE-FORBIDDEN` | 映射为 provider-owned versioned schema |
| context boundary | Contracts 使用批准的 BCL-only context | Application 使用 HttpContext/Activity runtime accessor；`SYMBOL-FORBIDDEN` | 入口创建可信 context，经 Port/Envelope 传递 |
| legacy naming | `*.Contracts` | 新 `*.Abstractions`；`PROJECT-NAME-FORBIDDEN` | 建 Contracts/Port；不得加兼容规则 |

报告给出 source、target、规则编号、ownership、直接/传递路径和修复位置。传递违规应在
最后一个泄漏 hop 关闭，而不是只删除消费处 using。

## 例外与生命周期

B4 不包含 waiver。若未来确有临时例外，必须包含 owner、风险原因、创建日、到期日和
删除条件，且不超过 G03 默认 90 天。`OWNERSHIP-UNKNOWN`、
`PAYLOAD-TYPE-FORBIDDEN` 等不可豁免类别不能建立 baseline。baseline 条目过期、规则 hash
不匹配、finding 消失但 entry 未删除（stale）都会失败。架构评审应至少每周由 CI schedule
重跑，并在依赖图变化时人工复核。

## 检查流程与证据

执行顺序为：G03 catalog/source reconciliation → 读取并 hash 验证 G03/G04/G05 artifact →
发现项目和 ownership → 构建直接/传递项目图 → 分析源码 import/声明/类型 → 应用规则 →
对账零 entry B4 baseline → 发布独立 LayerGuard 和 Gate semantic 报告。

图示：

- [目标依赖与 ownership 图](diagrams/plan03-layerguard-boundary.mmd) · [SVG](diagrams/plan03-layerguard-boundary.svg) · [PNG](diagrams/plan03-layerguard-boundary.png)
- [检查流程图](diagrams/plan03-layerguard-check-flow.mmd) · [SVG](diagrams/plan03-layerguard-check-flow.svg) · [PNG](diagrams/plan03-layerguard-check-flow.png)
- [迁移到严格模式状态图](diagrams/plan03-layerguard-mode-state.mmd) · [SVG](diagrams/plan03-layerguard-mode-state.svg) · [PNG](diagrams/plan03-layerguard-mode-state.png)

新模块从 [合规模板](templates/layerguard-module-structure/README.md) 开始，不创建旧命名项目。

## 本地验证

```powershell
./scripts/Invoke-LayerGuard.ps1
./scripts/Test-Plan03B4StrictClosure.ps1
```

第一条运行 LayerGuard 工具测试与 B4 仓库扫描；第二条验证零 finding、空 baseline、历史
下降序列、兼容规则移除、依赖图和 CI 严格入口。
