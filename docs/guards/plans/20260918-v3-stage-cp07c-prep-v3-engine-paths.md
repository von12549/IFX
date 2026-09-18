# CP07c-prep — Plan 06 P6.4 前置：Architecture Conformance engine 的 V3 目标路径与测试桥

本 pair 是 [正式 Plan pair](20260916-v3-stage-oriented-package-refactor.md) 检查点 CP07c-prep 的变更 PR，依据 D29 为 CP07c（[Plan 06](06-v3-stage-oriented-package-refactor.md) §14 P6.4）的 engine 迁移做 expand 步骤。它消费 `20260918-v3-stage-cp07c-prep-authorization` 加入的授权。

## 1. 问题

候选验证会用 base 版本覆盖 base-owned 测试。当前 base-owned 的 `tests/LayerGuard.Tests/LayerGuard.Tests.csproj` 位于 V3_ifx 并引用 `../../src/LayerGuard/LayerGuard.csproj`；engine 迁入 V3 后该引用消失，被覆盖回来的测试将无法编译，忽略它们就等于放弃 base-owned 验证。因此必须先建立一个跨迁移不变的 V3 项目路径与测试路径。

## 2. 变更

- 新增 V3 目标路径 `docs/guards/V3/stages/post/gates/architecture/dotnet/`：
  - `Guards.ArchitectureConformance/`：engine 的最终项目名与路径；本检查点内它引用仍在 V3_ifx 的 engine（过渡桥），CP07c 把源码移入本项目并删除该引用；
  - `Guards.ArchitectureConformance.Tests/`：通用 engine 测试迁入，只引用上述 V3 项目；
  - `fixtures/`：通用 synthetic fixture 迁入；
- `tests/LayerGuard.Tests/`：保留为已声明的空项目。CP07c-prep 自身的候选验证会把上一 base 的 engine 测试恢复到该路径，它们必须仍能在本包内编译并运行；base-owned 归属已改为 V3 路径，因此 CP07c 的候选验证恢复的是 V3 上的测试，可直接编译到迁移后的 engine。CP07c 删除该空项目；
- IFX policy binding 测试改用本包自有的最小 IFX fixture `tests/LayerGuard.Ifx.Tests/fixtures/IfxBinding/`（`IFX.Modules.Sample.*`、`IFX.ApiHost`），不再依赖通用 fixture；runner 通过 `LAYERGUARD_IFX_FIXTURES_ROOT` 传入；
- `scripts/Invoke-IFX.ps1`：源码集合、精确项目集合与引用、TCB 覆盖、IFX 标识扫描与 fixture 检查都跨两个包按仓库路径进行；restore/test 显式列出六个项目；
- `shared/trusted-components.json`：engine 组件增加 V3 engine 项目路径，base-owned 测试组件增加 V3 测试与 fixture 路径；
- `build/locks/`：新增两个 V3 项目的 reviewed lock；
- `tests/Test-IFXPackage.ps1`：fixture 复制 V3 engine 树，检查新项目的 import 报告，孤立 fixture 负向用例指向 V3 fixture 路径；
- `tests/Test-IFXManifests.ps1`：fixture 复制 `docs/guards/V3/stages`；
- 文档：`V3_ifx/README.md` 与 `architecture/TECHNICAL.md`。

C# namespace 仍为 `LayerGuard`，作为内部兼容面而不是稳定门禁身份（D29）。

## 3. 验证方式（桥的实际证明）

- `Invoke-IFX.ps1 -Mode Test`：184 个 engine 测试从 **V3 测试项目**运行并通过，10 个 IFX binding 测试用本包 fixture 通过，严格扫描通过；
- `Invoke-IFX.ps1 -Mode Check`：跨包源码清单、精确项目集合与引用、TCB 覆盖、IFX 标识扫描、通用与 IFX fixture 检查通过；
- `Test-IFXPackage.ps1`（含负向）、`Test-IFXManifests.ps1`、`Test-IFXTrustedBase.ps1` 通过；
- 候选验证：base（CP07b）的 base-owned engine 测试被恢复到 `tests/LayerGuard.Tests/` 并在该空项目中编译、运行通过——这正是桥要证明的「迁移前」一侧；
- CP07c 将证明「迁移后」一侧：base（本 prep）的 base-owned 测试位于 V3 路径、只引用 V3 项目，在 engine 源码迁入后仍编译并通过。

## 4. 与 Plan 06 文字的差异

| Plan 06 描述 | 实际实现 | 理由 |
| --- | --- | --- |
| P6.4 通用 engine 迁入 V3 | 先由 CP07c-prep 建立 V3 项目/测试/fixture 路径与过渡桥，再由 CP07c 迁移源码 | 候选验证覆盖 base-owned 测试，必须先有跨迁移不变的项目路径（D29，用户要求） |
| V3_ifx 只保留 policy、baseline、binding 与 IFX fixtures | 本 prep 已迁出通用测试与 fixture，engine 源码在 CP07c 迁出 | 分两步以保持每步可验证 |

## 5. 回退

还原本 pair 会把通用测试与 fixture 移回 V3_ifx，属于受保护路径移动与 TCB 变更，需要新的授权。
