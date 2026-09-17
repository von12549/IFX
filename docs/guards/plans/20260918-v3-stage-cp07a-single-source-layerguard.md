# CP07a — Plan 06 P6.1：LayerGuard 单一源码与 generated 副本删除

本 pair 是 [正式 Plan pair](20260916-v3-stage-oriented-package-refactor.md) 检查点 CP07a 的变更 PR，按 [Plan 06](06-v3-stage-oriented-package-refactor.md) §14 P6.1、D12 与 D26 让 Architecture Conformance Gate 直接构建、测试和扫描 `templates/ifx-layerguard/`，并删除 174 个文件的 `generated/dotnet/LayerGuard/` 副本。它消费 `20260918-v3-stage-cp07a-authorization` 加入的三条正交授权：

- `delete`：`generated/dotnet/LayerGuard` 目录的 protected-removal（174 个路径），记录 source 的 base tree entry；
- `change-trusted-base`：`tcb.engine.architecture-runner`、`tcb.generated.architecture-conformance`、`tcb.manifest` 与 `tcb.validation.package-tests` 的变化；
- `weaken-policy`：`guard-system.json`、`shared/commands.json` 与 `shared/trusted-components.json` 的语义变化。

## 1. 变更

- `scripts/Invoke-IFX.ps1`：
  - solution、engine 项目、测试项目与 fixture 根都取自 `templates/ifx-layerguard/`；
  - Generate 只读，不再写任何文件，也不再以 Generate 模式运行 policy projection 同步，只做 Check；
  - Check 与 Generate 以 `Assert-Source` 取代逐字节副本比较：retired 副本不得再次出现；`LayerGuard.slnx` 声明的项目等于 fixtures 以外的 `.csproj`，测试项目引用 engine；每个源码文件都在 active trusted component 的路径内；`Fixtures.cs` 命名的 fixture 与 fixture 目录一一对应且各含项目；
  - Test、Scan 在构建前同样运行 `Assert-Source`；
  - 过渡期（D26）仍保留 Generate/Check 与 active workflow 调用，P6.4 之前不输出 DEPRECATED。
- 删除 `generated/dotnet/LayerGuard/`（174 个文件）。
- `shared/trusted-components.json`：移除 `tcb.generated.architecture-conformance`。
- `shared/commands.json`：`ifx-architecture` 不再输出 generated 副本，mutability 改为 `writes-artifacts`。
- `guard-system.json`：移除该副本的 compatibility 条目（`compatibility: none`，`removeWhen: P6.1`）。
- `tests/Test-IFXPackage.ps1`：增加 Generate 只读、副本重建、未声明项目、孤立 fixture、manifest 外源码文件五个负向用例。
- 文档：`V3_ifx/README.md`、`architecture/IFX-MIGRATION.md`、`architecture/TECHNICAL.md` 与 `generated/README.md` 改为单一源码描述。
- Plan 06 P6.1 勾选并附证据；plan pair 的 CP07a 标记完成、待 PR 合入。

冻结证据、历史 plan 与 P0 基线（`analysis/ifx/refactor-baseline`）中的路径是历史记录，保持不变。`mcp/LayerGuard` 不在范围内（D26）。

## 2. 验证方式

- build/test、policy binding 与 strict scan：`Test-IFXPackage.ps1` 在隔离副本中从模板构建并运行 LayerGuard 测试（含 `GatePolicyBindingTests`，由 CP07a-prep 的 package root 解析支持），L2.2 负向扫描产生阻断发现，rule ID 漂移与外部 binding 失败；
- 正反 fixture：`Assert-Source` 的 fixture 对应检查与上述五个负向用例；
- CI 调用路径：trusted base runner 的 Architecture 模式（`v3-architecture`）与 CI 中保留的 `Invoke-IFX.ps1` Generate/Check 调用；
- 保护义务：`v3-pre-diff` 报告 protected-removal、trusted-component-change 与 policy-weakening 三类义务各由一条授权恰好覆盖；只消费其中两类的变更失败（本地模拟）；
- 候选验证：CP07a-prep base 的 base-owned validation（模板测试与 `Test-IFXPackage.ps1`）与固定语料 parity 通过。

## 3. 与 Plan 06 文字的差异

| Plan 06 描述 | 实际实现 | 理由 |
| --- | --- | --- |
| P6.1 删除副本并直接构建 | 先由 CP07a-prep 让 base-owned 绑定测试不依赖副本深度，再由本 PR 删除 | 候选验证叠加 base 测试（D26） |
| 删除副本 | 同时保留只读 Generate 与实质 Check，直到 P6.4 与 P11.4/P11.5 | active workflow 调用不在本阶段改动（D26） |

## 4. 回退

恢复副本或旧 runner 会再次改变 `tcb.engine.architecture-runner`、`tcb.manifest` 与已登记 policy，需要新的 `change-trusted-base` 与 `weaken-policy` 授权；在此之前 Check 会因副本重新出现而失败。
