# CP07a-prep — Plan 06 P6.1 前置：Architecture Conformance 绑定测试的 package root 解析

本 pair 是 [正式 Plan pair](20260916-v3-stage-oriented-package-refactor.md) 检查点 CP07a-prep 的变更 PR，依据 D26，为 CP07a（[Plan 06](06-v3-stage-oriented-package-refactor.md) §14 P6.1）的单一源码构建做 expand 步骤。它消费 `20260917-v3-stage-cp07a-prep-authorization` 加入的 `change-trusted-base` 授权；本 PR 不修改已登记 policy。

## 1. 问题

`GatePolicyBindingTests.cs` 以 `BootstrapArchitecture` fixture 目录加固定六级 `..` 推导 package root，这只在 `generated/dotnet/LayerGuard/` 的深度下指向 `docs/guards/V3_ifx`。CP07a 改为从 `templates/ifx-layerguard/` 直接构建后，同一推导会指向 `docs/guards`，策略绑定测试找不到 `policy/layerguard.json`。

该测试属于 base-owned `tcb.validation.architecture-conformance`。CP07a 的候选验证会把 base 版本的测试叠加到候选上，在 `Test-IFXPackage.ps1` 中从模板位置运行，因此修正必须先进入 base。

## 2. 变更

- `GatePolicyBindingTests.cs`（模板与 generated 副本逐字节相同）：package root 优先取 `LAYERGUARD_PACKAGE_ROOT`，否则从 fixture 目录向上寻找第一个含 `policy/layerguard.json` 的目录，找不到时失败；
- `scripts/Invoke-IFX.ps1`：Test 模式设置 `LAYERGUARD_PACKAGE_ROOT` 为 package root，并在结束后恢复；模板与 generated 副本的逐字节比较只在 Check 与 Generate 执行，Test 与 Scan 按 generated 副本现状构建；
- `trusted-base/TrustedBase.psm1`：独立 trusted base 进程不继承 `LAYERGUARD_PACKAGE_ROOT`，调用方不能把测试指向其他 policy。

对当前布局，行为不变：六级推导与向上寻找得到同一目录，runner 传入的也是该目录。

逐字节比较移出 Test/Scan 的原因：本 PR 的候选验证把 base 版本的 `templates/ifx-layerguard/tests/` 叠加到候选上，而 generated 副本不是 base-owned，保留新测试；若 Test 仍先比较两者，base 的 `Test-IFXPackage.ps1` 会把叠加本身报为 `Generated file drift`。CI 的 Check 仍要求两份逐字节相同，副本在 CP07a 删除后该比较也随之消失。

## 3. 验证

- `Invoke-IFX.ps1 -Mode Check`：模板与 generated 副本仍逐字节相同；修改 generated 副本任一字节后 Check 失败；
- 不设置 `LAYERGUARD_PACKAGE_ROOT`、以模板 fixture 为 `LAYERGUARD_FIXTURES_ROOT` 运行 generated 测试项目，10 个 `GatePolicyBindingTests` 全部通过；这正是 CP07a 候选验证中 base 测试的情形；
- `Test-IFXPackage.ps1`、`Test-IFXTrustedBase.ps1 -ArchitectureOnly` 与 `Test-IFXManifests.ps1` 通过。

## 4. 与 Plan 06 文字的差异

| Plan 06 描述 | 实际实现 | 理由 |
| --- | --- | --- |
| P6.1 删除 generated 副本并直接构建 | 先以 CP07a-prep 修正 base-owned 绑定测试的路径解析，并把副本一致性比较限定在 Check/Generate，再由 CP07a 删除副本 | 候选验证叠加 base 测试，旧的固定深度推导会使 CP07a 无法通过（D26，用户批准） |

## 5. 回退

还原本 pair 列出的文件会再次修改 TCB 组件，需要新的 `change-trusted-base` 授权。
