# CP04a — Plan 06 P2 前置：package root 与 target root 分离、domain authority registry

本 pair 是 [正式 Plan pair](20260916-v3-stage-oriented-package-refactor.md) 检查点 CP04a 的 formal Plan，为 [Plan 06](06-v3-stage-oriented-package-refactor.md) §14 P2（Trusted Base Guard Execution）做前置准备，并落实 D18（§11.3、§12.6）。输入为 CP02 的 manifest/TCB 与 CP03 的构建基线。

## 1. 目标

P2 要求 workflow 之后的完整调用链来自 base，head 只作为显式 target。当前判定链脚本从自身位置推导仓库根，同一个根既用来读门禁包配置，也用来读被检查的代码与 domain authority，因此无法从仓库外的 base 副本运行。本检查点：

1. 在不改变原位行为的前提下，把包代码/配置与 target 数据的读取根分开；
2. 盘点 detector 读取的 domain authority，按 D18 登记角色，并在 trust contract 中声明每个 Gate 的输入与来源；
3. 用包外副本对照原位运行证明分离完整，并由 manifest 检查阻止未登记的读取复发。

本检查点不接入 trusted-base runner、不做 candidate projection 或 anti-weakening 比较（CP04b），不修改 workflow 的执行入口（CP04c）。

## 2. 实现

**Root 分离**（原位默认值不变）：

| 组件 | 变更 |
| --- | --- |
| `specialized/scripts/*.ps1`（37 个） | target 根优先取 `GUARD_TARGET_ROOT`，否则沿用原推导；`Test-AbstractionsRetirement.ps1` 从包内读取 `policy/layerguard.json` |
| `Invoke-IFXSpecialized.ps1` | 新增 `-TargetRoot`，运行期间设置并恢复 `GUARD_TARGET_ROOT` |
| `Invoke-IFXQuality.ps1`、`Invoke-IFXPackageAudit.ps1` | 新增 `-TargetRoot`／支持 `GUARD_TARGET_ROOT` |
| `Invoke-IFXAssemblyGuard.ps1` | 未指定 `-PolicyPath` 时从包内读取 `policy/layerguard.json` |
| `Invoke-IFXHistoricalIntegrity.ps1` | 未指定 `-ManifestPath` 时从包内读取 `history/manifest.json`，证据文件从 target 读取 |
| `Invoke-IFXCiContract.ps1` | 未指定 `-JobsPath` 时从包内读取 `ci/jobs.json`，workflow 从 target 读取 |
| `Invoke-IFXManifestCheck.ps1` | manifest、schema 与判定链脚本从检查器所在的包仓库读取，workflow 与 domain authority 从 target 读取 |
| `Invoke-V3.ps1`（V3 与 V3_ifx，保持相同） | 新增 `-GenerationRoot`：生成工程可位于 target 之外的可信副本中，未指定时仍要求位于 `-TargetRoot` 下 |
| `Invoke-IFXGuardrails.ps1` | 区分包仓库与 target：Validate/Pre/Diff 传入 `-GenerationRoot`，profile views 在包仓库检查，Specialized/Quality 传入 `-TargetRoot` |

**Domain authority registry（D18）**：

- `policy/authorities.json` 新增 `domainAuthorities`：36 个 authority，每项含 `id`、`path`、`defaultRole` 与按 JSON Pointer 覆盖的 `pointerRoles`（`*` 匹配任意成员或下标）。例如 G03 catalog 默认 `target-declaration`，`/approvalPolicy`、`/waiverPolicy`、`/protocols/*/lifecycle` 等为 `governing-policy`，`/waivers`、`/fieldExceptions` 为 `exception-authorization`；
- 新增 `contracts/authorities.schema.json`；
- `stage.schema.json`（V3 与 V3_ifx，保持相同）的 trust contract 新增必填 `inputs`（`authority:<id>`／`package:<路径>`／`target:<路径>`，来源为 `base`、`head-candidate`、`derived-candidate`、`head-target`）与可选 `detectors`；
- 13 个 Gate 全部声明 `inputs`；G03、G04、G05、Plan04、Database 声明 `detectors`，并把原先错误指向 `V3_ifx/policy/g0x/` 的 `policy` 描述改为 head candidate authority。

**Manifest 检查新增规则**：

- registry 通过 schema，ID 与路径唯一，路径位于 domain authority 根下且在 target 中存在，每个 pointer 至少匹配一处且不重复默认角色；
- 包内引擎脚本（不含 `tests/`、`analysis/`）中每个 domain authority 路径字面量都已登记；每个 projection/binding 的 source 都已登记；
- `authority` 输入的来源必须与角色一致（`derived-projection` → `derived-candidate`，其余 → `head-candidate`）；`package` 输入必须存在于包内且来源为 `base` 或 `derived-candidate`；`target` 输入来源为 `head-target`；
- 声明 `derived-candidate` projection 的 Gate 必须同时声明其 source authority；
- 有 `detectors` 的 Gate：detector 静态读取闭包中的 authority 必须全部声明，声明的 authority 必须被读取。

**测试与接入**：

- `tests/Test-IFXManifests.ps1` 新增 11 个负向用例（未登记读取、未声明读取、声明未读取、来源错误、未知引用、projection 缺 source、缺 `inputs`、pointer 不匹配、非法角色、projection source 未登记），检查器改为从夹具内副本运行；
- `tests/Test-IFXCiContract.ps1` 显式传入夹具的 `-JobsPath`；
- 新增 `tests/Test-IFXTargetRootSeparation.ps1`：把包复制到仓库外临时目录，target 为当前 HEAD 的 git worktree（保留历史，删除全部包代码与配置），对 Validate、Pre、HistoricalIntegrity、G03、G04、G05、Plan04 比较包外与原位的退出码和逐项 check 状态；两个负向控制分别证明“detector 从自身位置推导 target”和“通过 target 读取包配置”会失败。已加入 `v3-cross-platform`（Linux 与 Windows）；
- TCB：新增 `tcb.policy.authority-registry`；`tcb.validation.package-tests` 纳入新测试；
- DEPLOYMENT（V3 与 V3_ifx）说明 root 分离、`-GenerationRoot` 与 registry。

## 3. 与 Plan 06 文字的差异

| Plan 06 描述 | 实际实现 | 理由 |
| --- | --- | --- |
| §11.3（D18 修订）trust contract 列出 authority 的角色 | `inputs` 只列引用与来源，角色由 registry 单一拥有 | 避免同一事实两处登记；§11.3 文字已同步 |
| P2.4 summary 报告每个 Gate 的保证范围 | 本检查点只落实输入声明 | summary 变化与 trusted-base runner 一并在 CP04b 实施 |
| — | detector 读取闭包为静态字面量分析 | 运行时拼接的路径不在本 lint 范围内；包外等价测试覆盖实际读取，CP04b 的 base runner 进一步以 target 剥离运行兜底 |

## 4. 验证

本地（Windows，SDK 10.0.303）：

| 项 | 结果 |
| --- | --- |
| `Invoke-IFXGuardrails` Validate、Architecture、HistoricalIntegrity、Specialized G03/G04/G05/Plan04（原位） | 通过 |
| `Test-IFXTargetRootSeparation.ps1`：7 个模式包外与原位一致，2 个负向控制失败 | 通过 |
| `Test-IFXManifests.ps1`（27 个用例，新增 11 个） | 通过 |
| Test-IFXPre、Test-IFXAuthorityProjection、Test-IFXHistoricalIntegrity、Test-IFXSpecializedContracts、Test-IFXCiContract、Test-CutoverPreservation、Test-IFXPackage、Test-IFXAssemblyGuard | 通过 |
| V3_ifx 与 V3 的 Test-V3、Test-V3ArchUnit、Test-V3Tools；V3 Test-V3BuildBaseline | 通过 |
| Test-IFXTools（workflow 变更后已刷新 `analysis/ifx/INVENTORY.md` 与 `inventory.json`） | 通过 |
| `New-RefactorBaseline.ps1 -Check` | 通过 |
| 本 pair 的 Pre | advisory |

Specialized Database 与 Quality 未在本地运行（需要 Docker SQL Server 与完整 solution/前端构建），由对应 CI job 验证；两者只增加了默认等价的 `-TargetRoot`／环境变量入口。

Linux 路径与行为由 CI `v3-cross-platform-ubuntu-latest` 验证；13 个 required check 名称不变。

## 5. 回退

还原本 pair 列出的文件即可；所有新增参数都有与原行为一致的默认值，registry 与 trust contract `inputs` 只被 manifest 检查读取。本检查点不删除、不移动受保护路径。
