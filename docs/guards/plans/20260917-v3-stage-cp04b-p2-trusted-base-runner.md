# CP04b — Plan 06 P2：trusted-base runner、D18 候选比较与 TCB 候选升级

本 pair 是 [正式 Plan pair](20260916-v3-stage-oriented-package-refactor.md) 检查点 CP04b 的 formal Plan，实施 [Plan 06](06-v3-stage-oriented-package-refactor.md) §11.1、§11.3、§11.5、§12.6 中不依赖 workflow 切换的部分（P2.4、P2.6、P2.7，以及 P2.1、P2.5 的机制与负向控制）。输入为 CP04a 的 root 分离、domain authority registry 与 trust contract `inputs`。

## 1. 目标

1. 提供从 base worktree 启动、以 head 为显式 target 的 trusted-base runner，并验证 base 来源与清洁度；
2. 按 D18 比较 head 与 base 的 domain authority，削弱类变化在 P4 前失败关闭；只有通过比较后，才由 base generator 生成 candidate projection 参与判定；
3. 实现 TCB 候选升级验证与 `change-trusted-base` 预授权协议；
4. 用负向控制证明 head 篡改入口、engine、policy、module、manifest、测试或 MSBuild 继承文件，都不能改变判定型结论或绕过 base-owned validation。

本检查点不修改 workflow 的执行入口，也不启用可信构建隔离（CP04c）；新增测试加入 `v3-cross-platform`，但 13 个 required check 的判定路径不变。

## 2. 实现

新目录 `docs/guards/V3_ifx/trusted-base/`（组件 `tcb.engine.trusted-base`）：

| 文件 | 作用 |
| --- | --- |
| `TrustedBase.psm1` | Git plumbing：`diff --raw -z --no-renames`、tuple、blob 读取；路径包含判断；canonical JSON；JSON Pointer 模板；清除 `GUARD_*` 环境变量的独立 pwsh 进程；TCB 路径映射、head 可执行引用与 validation suite 计算 |
| `Invoke-IFXTrustedBase.ps1` | runner：要求自身所在 worktree 的 HEAD 等于 `-BaseSha`、完全 clean（含 ignored）且与 head、生成根互不包含，head 仓库包含该 commit；Validate/Architecture/Specialized 先运行 D18 比较，通过后把 base 包文件复制到仓库外生成根，由 base `Sync-IFXPolicyInputs.ps1` 从 head authority 重新生成 projection，并确认只改动已登记的 projection target；随后从该副本运行 dispatcher（head 仅为 `-TargetRoot`），运行后再次确认 base worktree clean；Pre 只接受 formal Plan；summary 含 `-GateId` 对应的 trust 类型、保证范围与已知缺口 |
| `Test-IFXDomainAuthorityCandidates.ps1` | D18 比较：按 registry 的默认角色与 pointer 角色遍历 base/head；`target-declaration`、`derived-projection`、`evidence` 允许变化；`governing-policy` 必须相等，随新增或删除的整个声明元素出现/消失除外；`exception-authorization` 只允许收缩；数组按 `arrayKeys` 身份匹配，未声明身份时按位置比较（插入即失败关闭）；authority 被删除、非 JSON、结构类型变化均失败关闭 |
| `Test-IFXTrustedBaseCandidate.ps1` | TCB 候选：从 base worktree 运行；变更路径先按 base manifest 映射，未覆盖的新路径按 head manifest 映射；gitlink、两份 manifest 都未登记的可执行入口、仅由未修改的 head manifest 登记的入口均失败；存在 TCB 变更时要求恰好一条组件集合一致的 base 授权，并核对 head 已删除该授权、changed-path 集合、每条 base/head tuple、validation suite、plan/decision 引用；在独立 worktree 中以 base manifest 中 `base-owned*` 组件的 base 文件覆盖候选后运行 suite 中的脚本条目；对固定 corpus（默认 Validate、HistoricalIntegrity、G03、G04、G05、Plan04）比较 base 与候选的退出码、逐项状态与 summary schema，差异只在授权 `allowedBehaviorDifferences` 列出时允许 |
| `New-IFXTrustedBaseAuthorization.ps1` | 维护命令：由准备好的变更 revision 生成授权记录（不提交） |

**契约与登记**：

- `contracts/authorization.schema.json`：P2 仅启用 `change-trusted-base`，字段为 id、plan、decisions、changedPaths、components、逐路径 base/head tuple、validationSuite、parityContract、allowedBehaviorDifferences；P4 扩展其他 operation；
- `contracts/trusted-base-summary.schema.json`；
- `contracts/authorities.schema.json` 与 `policy/authorities.json` 新增 `arrayKeys`（G03 catalog 的 consumers/infrastructureProtocols/modules/owners/protocols/publicSurface，G04 dependencies），manifest 检查要求每个 `*` 数组都有身份键且在 target 中唯一；
- `stages/diff/authorizations/README.md` 说明两 PR 流程；授权目录下的记录是协议数据，不作为 TCB 变更映射；
- TCB：新增 `tcb.engine.trusted-base`，两份 schema 纳入 `tcb.contracts`，两份测试纳入 `tcb.validation.package-tests`；`commands.json` 新增 `ifx-trusted-base`、`ifx-tcb-candidate`（ci）与 `ifx-trusted-base-authorization`（diff，maintenance）；
- DEPLOYMENT 说明 trusted base 运行方式。

**测试**（加入 `v3-cross-platform`）：

- `tests/Test-IFXDomainAuthorityCandidates.ps1`：21 个用例（未变、纯格式、新增声明及其 owner、按身份重排、声明内容变化、新增依赖、收缩 bypass；catalog mode、协议 lifecycle、模块 owner、waiver、field exception、bypass 新增或延期、依赖 criticality、runtime allowedRoles、整文件 policy、reviewedMigrations、重复身份、删除 authority、非法 JSON）；
- `tests/Test-IFXTrustedBase.ps1`：在仓库外的临时 clone 中把当前包提交为 base，另建 base worktree，28 个用例：
  - 来源：正常运行与 summary、base SHA 不符、base 不 clean、base worktree 位于 head 内；
  - §11.1 负向控制：head 篡改 dispatcher、module 与 `commands.json`（原位运行通过、trusted 运行失败），篡改 engine，篡改 history manifest policy（原位通过、trusted 失败），根 `Directory.Build.props`/`Directory.Packages.props` 注入不改变 Validate；
  - §12.6：head 新增 waiver 在生成 projection 前失败；新增 consumer 时 base 旧 projection 拒绝、candidate projection 通过并重新生成 `policy/g03/catalog.json`；
  - §11.5：无 TCB 变更与 head 等于 base 均通过；未授权 engine 变更、head manifest 移除组件、workflow 引用未登记脚本、未授权 lock file 变更均失败；授权的等价变更通过；授权未消费、head 与授权不符、engine 与自身测试同时削弱、削弱 engine 并删除测试、改变 summary contract、改变 verdict 均失败。

## 3. 与 Plan 06 文字的差异

| Plan 06 描述 | 实际实现 | 理由 |
| --- | --- | --- |
| §11.1 整条调用链来自 base worktree | runner 从 base worktree 启动；dispatcher 及其调用链从生成根中的 base 包副本运行，副本与 base 的差异限定为已登记 projection target | base worktree 必须保持只读与 clean；D18 candidate projection 必须在 head 与 base 之外生成，副本的其余文件与 base tree 一致 |
| §11.5 纯 tuple 等价移动按 `move` 处理 | 所有 TCB 路径的 tuple 变化都需要 `change-trusted-base`；`move` 在 P4 实现 | P2 只启用 `change-trusted-base`，保守地把移动也视为语义变化 |
| §12.2 `change-trusted-base` 在 manifest 变化时记录 base/head manifest hash | manifest 文件本身作为 `tcb.manifest` 的变更条目记录 base/head tuple（objectId 即 blob hash） | 与其他路径使用同一机械核对 |
| §11.5 validation suite | 只执行形如 `docs/guards/**.ps1` 的脚本条目；其他条目（required check 名、带参数命令）记为 external，由对应 CI job 与 parity 覆盖 | 条目格式沿用 CP02 manifest |
| §12.6 `derived-projection` 由 base generator 重新生成 | 包内 projection（`policy/g03`、`g04`、`g05`）由 runner 重新生成；target 中的 derived 文件（G03 governance input、snapshots、G04 runtime manifest、Plan04 lock）仍由对应 Gate 的 detector 核对一致性，其 `governing-policy` 字段参与比较 | 这些 generator 本身就是 Gate detector |
| P2.5 head MSBuild 继承注入 | 本检查点以 Validate 验证；Architecture 实际构建下的注入控制随 CP04c 可信构建隔离启用 | 构建输出迁出 head 属于 CP04c |

## 4. 验证

本地（Windows，SDK 10.0.303）：

| 项 | 结果 |
| --- | --- |
| `Test-IFXTrustedBase.ps1`（28 个用例，约 2 分钟） | 通过 |
| `Test-IFXDomainAuthorityCandidates.ps1`（21 个用例） | 通过 |
| `Test-IFXManifests.ps1`（29 个用例，新增 2 个 arrayKeys 用例） | 通过 |
| `Invoke-IFXGuardrails` Validate、Architecture、HistoricalIntegrity、Specialized G03/G04/G05/Plan04 | 通过 |
| Test-IFXTargetRootSeparation、Test-IFXCiContract、Test-IFXPre、Test-IFXAuthorityProjection、Test-IFXHistoricalIntegrity、Test-IFXSpecializedContracts、Test-CutoverPreservation、Test-IFXPackage、Test-IFXAssemblyGuard | 通过 |
| V3_ifx 与 V3 的 Test-V3、Test-V3ArchUnit、Test-V3Tools；V3 Test-V3BuildBaseline | 通过 |
| Test-IFXTools（workflow 变更后已刷新 `analysis/ifx/INVENTORY.md` 与 `inventory.json`） | 通过 |
| `New-RefactorBaseline.ps1 -Check` | 通过 |
| 本 pair 的 Pre | advisory |

Specialized Database 与 Quality 未在本地运行，由对应 CI job 验证；本检查点未修改其判定路径。Linux 由 CI `v3-cross-platform-ubuntu-latest` 验证；13 个 required check 名称不变。

## 5. 回退

删除 `trusted-base/`、两份新 schema、授权目录 README 与两份新测试，还原 registry `arrayKeys`、TCB manifest、commands、stage 命令列表、workflow 与文档。现有判定路径不依赖本检查点新增的代码。
