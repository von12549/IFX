# CP07b-prep — Plan 06 P6.3 前置：IFX facade 项目与 IFX policy binding 测试迁移

本 pair 是 [正式 Plan pair](20260916-v3-stage-oriented-package-refactor.md) 检查点 CP07b-prep 的变更 PR，依据 D27 为 CP07b（[Plan 06](06-v3-stage-oriented-package-refactor.md) §14 P6.2–P6.3）的 engine/IFX binding 分离做 expand 步骤。它消费 `20260918-v3-stage-cp07b-prep-authorization` 加入的两条正交授权：

- `move`：`tests/LayerGuard.Tests/GatePolicyBindingTests.cs` → `tests/LayerGuard.Ifx.Tests/GatePolicyBindingTests.cs`，覆盖该受保护路径的 protected-removal；
- `change-trusted-base`：`tcb.build.package-local`、`tcb.engine.architecture-conformance`、`tcb.engine.architecture-runner`、`tcb.validation.architecture-conformance` 与 `tcb.validation.package-tests` 的变化。

本 PR 不修改已登记 policy；policy 文件与 composite hash 输入逐字节不变。

## 1. 问题

CP07b 要把 IFX policy binding 从通用 engine assembly 中分离。候选验证会用 base 版本覆盖 base-owned 的 `templates/ifx-layerguard/tests/`，包括只引用 engine 的 `LayerGuard.Tests.csproj` 与直接调用 `Analyzer.Analyze` 的 `GatePolicyBindingTests.cs`。若 base 仍是 CP07a，这些测试会在没有 binding 的 engine 上运行并失败。因此 IFX binding 测试必须先通过一个在分离前后路径和入口都不变的 IFX facade 访问 gate。

## 2. 变更

- 新增 `src/LayerGuard.Ifx/LayerGuard.Ifx.csproj` 与 `IfxArchitectureConformance.Analyze(path, configPath)`：分离前转发到 engine；CP07b 起承载 IFX binding 并保持同一路径与入口；
- 新增 base-owned `tests/LayerGuard.Ifx.Tests/`，只显式引用 IFX facade；`GatePolicyBindingTests.cs` 从 `tests/LayerGuard.Tests/` 迁入，断言不变，只把 `Analyzer.Analyze` 换成 facade，并在本地解析 fixture 根；`tests/LayerGuard.Tests/` 不再含 IFX binding 测试；
- `LayerGuard.slnx` 声明四个项目；
- `scripts/Invoke-IFX.ps1`：
  - Check 要求 solution 恰好是 engine、IFX facade、engine 测试与 IFX 测试四个项目，每个项目的 project reference 恰好是预期集合（engine 无引用；facade 与 engine 测试引用 engine；IFX 测试只引用 facade），拒绝通配符引用；
  - restore 与 test 步骤显式列出四个项目，锁文件、effective properties 与 pre-/post-build import allowlist 覆盖每个项目；
- `build/locks/`：新增 `LayerGuard.Ifx` 与 `LayerGuard.Ifx.Tests` 的 reviewed lock（`-LockMode Update` 生成，包版本与既有测试项目相同）；
- `tests/Test-IFXPackage.ps1`：新增 facade 缺失、solution 声明意外项目、IFX 测试绕过 facade、通配符引用四个负向用例，并检查新项目的 pre-build import 报告；
- 文档：`V3_ifx/README.md` 与 `architecture/IFX-MIGRATION.md`。

未使用通配符 `ProjectReference`（D27）。

## 3. 验证方式

- `Invoke-IFX.ps1 -Mode Check` 通过；`-Mode Test` 中 engine 测试 182 个、IFX binding 测试 10 个全部通过，严格扫描通过；
- `Test-IFXPackage.ps1` 通过，包括新增负向用例；
- `v3-pre-diff` 报告 1 个 protected-removal 与 1 个 trusted-component-change 义务，分别由 `move` 与 `change-trusted-base` 恰好覆盖；只消费其中一条的变更失败（本地模拟）；
- 候选验证：CP07a base 的 base-owned validation（叠加 base 测试后，旧位置的 `GatePolicyBindingTests` 在未分离的 engine 上仍通过）与固定语料 parity 通过。

## 4. 与 Plan 06 文字的差异

| Plan 06 描述 | 实际实现 | 理由 |
| --- | --- | --- |
| P6.2–P6.3 参数化并分离 IFX binding | 先以 CP07b-prep 建立显式引用的 IFX facade 并迁移 IFX binding 测试，再由 CP07b 分离 | 候选验证以 base 测试覆盖候选测试（D27，用户批准） |
| runtime role、IFX project/type names 移入 IFX policy/fixtures | CP07b 移入受 TCB 管控的 IFX binding 代码，policy 文件不变 | 所有权迁移而非 policy 外部化，保持 composite hash（D27） |

## 5. 回退

还原本 pair 会再次移动受保护测试并修改 TCB 组件，需要新的 `move` 与 `change-trusted-base` 授权。
