# CP03 — Plan 06 P5 V3 package-local 构建基线与输出迁出

本 pair 是 [正式 Plan pair](20260916-v3-stage-oriented-package-refactor.md) 检查点 CP03 的 formal Plan，实施 [Plan 06](06-v3-stage-oriented-package-refactor.md) §14 P5（P5.1–P5.7）与 D14。输入为 CP01 的 `build-inheritance.json` 与 CP02 的 TCB manifest。

## 1. 目标

让两个可信 .NET 门禁工程（Stage Gate 与 Architecture Conformance/LayerGuard）只从 V3 包内的构建与安全基线构建：固定 SDK 与包源、显式导入基线、关闭目录发现、locked restore、导入 allowlist，输出不再写入 `docs/guards`，并证明 V3 在隔离目录中可独立运行。

本阶段位于 Plan 06 §11.6 的受控 bootstrap 窗口：P2 尚未启用 trusted base 执行，因此本检查点由现有 CI、隔离测试与负向控制验证，P2 以本检查点合入后的 base 关闭窗口。

## 2. 实现

**V3 `build/`**：

| 文件 | 作用 |
| --- | --- |
| `V3.Build.props` | `NuGetAudit`（all/moderate）、`NU1603;NU1903;NU1904` 为错误、关闭 CPM、启用 lock 并按工程名定位 lock 文件 |
| `NuGet.config` | 仅 nuget.org，`packageSourceMapping` 全部映射到该源 |
| `global.json` | `10.0.100` + `rollForward: latestFeature`（本地 10.0.303、CI `10.0.x` 均满足） |
| `GuardBuild.psm1` | 统一的 restore/build/test/run 入口与校验 |
| `probe/Probe.csproj` | 只用于读取 .NET 根目录，不构建 |
| `locks/README.md` | V3 默认 lock 根说明 |

**`GuardBuild.psm1` 行为**：

- 所有 `dotnet` 调用在 `build/` 下执行，使 `global.json` 生效；
- 全局属性关闭 `Directory.Build.props/targets`、`Directory.Packages.props`、`Directory.Solution.props/targets` 与用户级通配导入，并以 `CustomBeforeMicrosoftCommonProps` 显式导入 `V3.Build.props`；
- `--artifacts-path` 把 bin/obj 放到 `artifacts/build/<package>/<gate>/`；
- restore 前要求 lock 存在（`-LockMode Locked`，默认），restore 后要求 lock 规范化内容不变并恢复原字节，逐项核对 lock 与 `project.assets.json`（包集合与 sha512）以及全局包目录的 `.nupkg.metadata` content hash；
- 核对有效属性（基线已导入、审计强度、警告即错误、CPM 关闭、lock 路径、未发现任何 `Directory.*.props`）；
- 构建前用 `msbuild -pp`、构建后用 MSBuild 导入日志提取实际导入文件，只允许 .NET 根目录、`V3.Build.props`、工程 obj 下的 `*.nuget.g.props/targets` 与 lock 中的包；报告写入 `artifacts/guards/<package>/build/<gate>/`。

**接入**：

- `Invoke-V3.ps1`（V3 与 V3_ifx 两份，保持相同）：生成的 Stage Gate 经模块 restore/test；新增 `-LockMode`、`-LockRoot`；目标工程（head）构建保持原样，属于执行型输入；
- `Invoke-IFX.ps1`：LayerGuard 解决方案经模块 restore/test/build，扫描用 `dotnet run --no-build`；新增 `-LockMode`、`-LockRoot`；
- IFX reviewed locks：`docs/guards/V3_ifx/build/locks/{GuardV3.Tests,LayerGuard,LayerGuard.Tests}.packages.lock.json`；
- LayerGuard 测试 `Fixtures.cs`（模板与生成副本）：fixture 根可由 `LAYERGUARD_FIXTURES_ROOT` 指定，`Invoke-IFX.ps1` 设置为生成副本的 `tests/fixtures`；未设置时保持原相对路径（`mcp/LayerGuard` 不受影响）；
- 测试夹具（`Test-V3`、`Test-V3ArchUnit`、`Test-V3Tools`，V3 与 V3_ifx 各一份）改用夹具内 lock 根与 `-LockMode Update`，不会触碰 reviewed locks；
- `Test-IFXPackage.ps1` 夹具复制 V3 `build/`，并断言包源码树无 `bin/obj`、三份导入报告通过；
- 新增 `docs/guards/V3/tests/Test-V3BuildBaseline.ps1`，加入 `v3-cross-platform` 两个平台；
- TCB：`tcb.build.package-local` 由计划改为 active（V3 `build/` 与 V3_ifx `build/`），删除不再影响可信构建的 `tcb.build.host-inherited`，新增 `tcb.validation.v3-package-tests`；manifest 检查器把 `.psm1` 与 V3 `build/`、`tests/` 纳入判定链扫描；
- DEPLOYMENT（V3 与 V3_ifx）补充构建基线与 lock 更新流程。

## 3. 与 Plan 06 文字的差异

| Plan 06 描述 | 实际实现 | 理由 |
| --- | --- | --- |
| §5 `build/V3.Packages.props` 门禁工程包版本 | 未建立；版本由现有 PackageReference 声明、由 lock 文件固定 | 集中版本文件需要修改模板与生成副本，而 lock 已提供版本与 content hash 的权威记录 |
| P5.2 门禁工程显式 import 基线 | 通过全局属性 `CustomBeforeMicrosoftCommonProps` 显式导入 | 同样是显式、非目录发现的导入，且不改变 csproj 字节，模板/生成副本与测试夹具保持一致 |
| P5.3 / §11.2 构建后 binlog 复核 | 使用 `MSBUILDLOGIMPORTS` 诊断日志中的 `Importing project` 记录 | 不引入额外的 binlog 解析依赖，记录的是同一组实际导入 |
| P5.3 locked restore | 由模块强制 lock 存在、不变、与 assets/包 hash 一致 | 实测 NuGet `--locked-mode` 在 lock 缺失或被篡改时仍然成功并重写 lock |
| P5.4 runtime analysis 输出迁出 | 保留到 P8.6 | 迁出会改变 Analyze/Review 命令与 Test-IFXTools 的契约，P8.6 专门负责 |
| §8.3 `Test-V3.ps1` 不再依赖复制 `docs/Directory.Packages.props` | 门禁构建已不依赖该文件（隔离测试证明）；V3_ifx `Test-V3.ps1` 中的复制语句保留 | 该分叉在 P3.3 统一 |

## 4. 验证

本地（Windows，SDK 10.0.303）：

| 项 | 结果 |
| --- | --- |
| `Invoke-IFXGuardrails -Mode Validate`、`-Mode Architecture` | 通过（LayerGuard 192 个测试 + 严格扫描，locked） |
| V3 Generate/Check、`Invoke-V3 -Mode Test`（locked） | 通过 |
| IFX Generate/Check | 通过 |
| Test-IFXPre、Test-IFXAuthorityProjection、Test-IFXSpecializedContracts、Test-IFXHistoricalIntegrity、Test-CutoverPreservation、Test-IFXPackage、Test-IFXAssemblyGuard、Test-IFXCiContract、Test-IFXManifests、Test-IFXTools | 通过 |
| V3_ifx 与 V3 的 Test-V3、Test-V3ArchUnit、Test-V3Tools | 通过 |
| `Test-V3BuildBaseline.ps1`：隔离运行、缺失 lock、篡改 content hash、lock 缺包、导入削弱审计的文件、allowlist 外导入、源码树无输出 | 通过 |
| `New-RefactorBaseline.ps1 -Check` | 通过 |
| 运行后 `docs/guards` 下 `bin/obj` | 无 |
| 三份 IFX 导入报告 | 全部 pass，0 违规 |

Linux 路径与行为由 CI `v3-cross-platform-ubuntu-latest` 验证；13 个 required check 名称不变。

## 5. 回退

还原本 pair 列出的文件；删除 `docs/guards/V3/build/` 与 `docs/guards/V3_ifx/build/` 后，脚本恢复为原先的 `dotnet restore/test/run` 调用。本检查点不删除、不移动受保护路径。
