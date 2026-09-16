# CP02 — Plan 06 P1 决策校验、漂移修复、CI 契约与最小 manifest

本 pair 是 [正式 Plan pair](20260916-v3-stage-oriented-package-refactor.md) 检查点 CP02 的 formal Plan，实施 [Plan 06](06-v3-stage-oriented-package-refactor.md) §14 P1（P1.1–P1.5）。输入为 CP01 的 [P0 基线](../V3_ifx/analysis/ifx/refactor-baseline/README.md)。

## 1. 目标

校验 D1–D15 并补充 P0 发现的决定；修复 P0.5 登记的迁移前漂移并让 CI 阻止其复发；建立 workflow、`ci/jobs.json` 与 ruleset 的只读契约校验；在不移动现有目录的前提下建立 P2 所需的最小 manifest、TCB schema 与兼容规则。不改变任何 required check 名称，不删除或移动受保护路径。

## 2. P1.1 决策校验

| 检查 | 结果 |
| --- | --- |
| D1–D15 记录的 `id` 与文件名一致 | 15/15 |
| schema（`decision.schema.json`） | 15/15 有效 |
| 每条 `affectedPaths` glob 至少匹配一个已跟踪文件 | 全部匹配 |
| 与 P0 事实对照 | D2（V3 与 V3_backup 树相同）、D9（全部入口来自 head）、D10（受保护清单）、D12（IFX binding 位置）、D14（构建继承）均与基线一致；D13 的比较器顺序参考数据与 P0.9 不一致 |

补充决定：

- **D16**：比较器按 commit 修改次数排序，首批为 `profiles/ifx/rules`、`profiles/ifx/project-map`（细化 D13）。
- **D17**：4 个不可达的 Plan04 阶段校验脚本不接入门禁，P4 后通过授权删除。依据：3 个在基线上失败（授权产物 hash 已变化），4 个默认改写 `docs/architecture/review/evidence/plan04/` 冻结证据（运行后已还原，未提交任何证据变化），能力已由 `Test-Plan04Governance.ps1` 覆盖。

## 3. P1.2 漂移处理

| ID | 处理 | CI 防复发 |
| --- | --- | --- |
| DRIFT-01 | 重新渲染 `profiles/ifx/views/`（PROJECT_MAP、TECH_STACK） | `Invoke-IFXGuardrails -Mode Validate` 新增 `profile-views` |
| DRIFT-02 | 重新执行 Analyze/Review；把 `analysis/ifx/ARCHITECTURE.md`、`TECHNICAL.md` 的结构化块与区域/命令表同步为当前 profile；Review 结果为 0 个 profile 差异、0 个未映射项目，状态仍为 `DRAFT`/`needs-review`（未宣称人工评审） | 不做 CI 门禁：比较的是运行时产物，每个 csproj/workflow 变更都会触发；由 P8.6 迁出仓库解决。本地 `Test-IFXTools` 覆盖 |
| DRIFT-03 | 重新执行 DEPLOYMENT 记录的完整流程并通过；DEPLOYMENT 补充新校验、新测试与 Test-IFXTools 的运行前提 | 流程中的关键项已由 Validate 与 CI 测试覆盖 |
| DRIFT-04 | `IFX-MIGRATION.md` 改为引用 `duplicates.json`，不再写死文件数 | — |
| DRIFT-05 | 删除不匹配任何文件的 `SourceConfig` area；重新生成 `generated/stages/project-map.json` 与视图 | 删除后，`src/` 直下新增文件会因 unmapped 在 Pre 失败关闭 |
| DRIFT-06 | 新增 `ci/Invoke-IFXCiContract.ps1` | Validate 新增 `ci-contract`；`Test-IFXCiContract` 进入 `v3-architecture` |
| DRIFT-07 | `v3-historical-integrity` 触发声明改为 `pull-request-and-main`，与 workflow 实际行为一致 | `ci-contract` 校验触发语义 |
| DRIFT-08 | `Test-V3ArchUnit.ps1`（V3 与 V3_ifx 两份，保持相同）在 fixture 根写入关闭 CPM 的 `Directory.Packages.props`；`Test-IFXTools` 随 DRIFT-01/02 修复通过 | `Test-V3ArchUnit` 进入 `v3-architecture` |
| DRIFT-09 | 由 D17 决定退役 | 删除等待 P4 |
| DRIFT-10 | 不在 P1 处理 | P3、P7 |

## 4. P1.3 CI 契约校验

`ci/Invoke-IFXCiContract.ps1` 为只读校验：

- workflow 解析：job、显式 check 名称、matrix 内联列表展开、`needs` 引用、job 级 `if`、`pull_request` 与 `push` 到 `main` 触发；
- `ci/jobs.json`：与展开后的 check 名称双向一致、ID 唯一、`requiredCheckCount` 相等、全部 blocking、触发声明与 job 条件一致（`pull-request` ↔ `github.event_name == 'pull_request'`；`pull-request-and-main` ↔ 无条件）；
- ruleset（`-RulesetJsonPath` 或 `-Remote`，仅 GET）：ID/名称、`active`、`strict`（同时作为 Plan 06 §12.3 比较端点的前提）、required context 与声明双向一致。

`Test-IFXCiContract.ps1` 覆盖 15 个正反例。远端核对结果：42 项检查全部通过，记录于 `analysis/ifx/refactor-progress/cp02-ci-contract-remote.json`。远端核对不进入 CI（需要 GitHub API），按需手动执行。

## 5. P1.4 兼容规则与 P1.5 最小 manifest

**schema**（V3 与 V3_ifx `contracts/` 各一份，内容相同，P7.5 去重）：`guard-system`、`stage`、`commands`、`trusted-components`。字段 owner 遵循 Plan 06 §6：`stage.json` 与 `commands.json` 均 `additionalProperties: false`，不能声明对方拥有的字段。

**V3_ifx 实例**：

- `guard-system.json`：`role: overlay`，`engine.status: forked-until-p7`；`compatibility` 定义兼容期（到 P11.5）、deprecation 输出格式、内部路径不提供 wrapper、删除条件，以及 12 个旧路径条目；
- `shared/commands.json`：14 个命令（public 7、internal 4、maintenance 3）；
- `stages/{bootstrap,analysis,pre,post,diff,ci}/stage.json`：13 个 required check 各由一个 gate 声明，trust contract 取自 P0.10；
- `shared/trusted-components.json`：由 P0.3 `tcb.json` materialize，`tcb.manifest` 由计划改为 active 并自保护；P1 新进入判定链的 `Invoke-V3Docs.ps1`、`Invoke-IFXCiContract.ps1`、`Invoke-IFXManifestCheck.ps1` 与新测试已归入组件。

P0 `tcb.json` 把 manifest 计划路径写为 V3 `shared/`；由于当前 TCB 组件全部是 V3_ifx 路径，IFX 实例放在 V3_ifx `shared/`（overlay），V3 自身实例在 V3 engine 被 CI 执行后（P3/P7）建立。

`scripts/Invoke-IFXManifestCheck.ps1` 校验：schema、原始文档上的字段 owner、stage/command 双向引用、stage 依赖与文档存在、每个 required check 恰有一个 gate、TCB 路径存在且不重叠、manifest 自保护、判定链脚本（workflow 入口及其引用，不跟随测试）全部在 TCB 内、gate 命令入口在 TCB 内、兼容条目指向现存路径。`Test-IFXManifests.ps1` 覆盖 16 个正反例。

## 6. 验证

本地（Windows，SDK 10.0.303）：

| 项 | 结果 |
| --- | --- |
| `Invoke-IFXGuardrails -Mode Validate`（含 `profile-views`、`ci-contract`、`manifest-check`） | 通过 |
| V3 Generate/Check、IFX Generate/Check | 通过 |
| Test-IFXPre、Test-IFXAuthorityProjection、Test-IFXSpecializedContracts、Test-IFXHistoricalIntegrity、Test-CutoverPreservation、Test-IFXPackage、Test-IFXAssemblyGuard、Test-V3 | 通过 |
| Test-IFXCiContract、Test-IFXManifests、Test-V3ArchUnit（V3 与 V3_ifx）、Test-V3Tools、Test-IFXTools | 通过 |
| `New-RefactorBaseline.ps1 -Check` | 通过（P0 记录未受影响） |
| Pre（本 pair） | 通过 |
| `Invoke-IFXCiContract.ps1 -Remote` | 通过 |

CI：`v3-architecture` 新增 `Test-IFXCiContract`、`Test-IFXManifests`、`Test-V3ArchUnit`；job 名称与 13 个 required check 不变。

## 7. 回退

还原本 pair 列出的文件即可；本检查点不删除、不移动任何文件。恢复点为 CP01 合入后的集成分支。
