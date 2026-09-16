# CP01 — Plan 06 P0 基线冻结与完整分类

本 pair 是 [正式 Plan pair](20260916-v3-stage-oriented-package-refactor.md) 检查点 CP01 的 formal Plan，实施 [Plan 06](06-v3-stage-oriented-package-refactor.md) §14 P0（P0.1–P0.10）。设计与验收以 Plan 06 为准。

## 1. 目标

在不改变任何门禁实现、profile、policy、workflow、ruleset、required check 或目录结构的前提下，冻结重构前的事实基线：文件分类、调用图与初始 TCB、.NET gate、漂移、V3/V3_ifx 分叉、ruleset、构建继承、修改频率与 trust contract，并在基线 CI artifact 过期前归档其证据。

## 2. 范围

**包含**：

- `docs/guards/V3_ifx/analysis/ifx/refactor-baseline/`：
  - 生成记录：`inventory.json`、`duplicates.json`、`call-graph.json`、`tcb.json`、`v3-divergence.json`、`change-frequency.json`；
  - 人工记录：`dotnet-gates.json`、`drift.json`、`ruleset.json`、`build-inheritance.json`、`trust-contracts.json`、`local-results.json`；
  - 基线 CI run `35055279816` 的 JSON 证据与 `ci-evidence/manifest.json`；
  - 生成器 `tools/New-RefactorBaseline.ps1`、归档规则 `tools/archive-ci-evidence.py` 与汇总报告 `README.md`；
- Plan 06 §14 P0 checklist 与结果；
- 正式 Plan pair §3 检查点状态列；
- 本 pair。

**不包含**：修复 P0.5 登记的漂移（P1.2）、建立 verifier（P1.3）、任何受保护路径的删除或移动。

## 3. 结果摘要

详见 `refactor-baseline/README.md`。

| 项 | 结果 |
| --- | --- |
| 文件分类 | 820/820，未分类 0 |
| 可执行文件 | 70：public 27、internal 38、unreferenced 5；判定链 50 个全部归入 TCB |
| 初始 TCB | 17 个 component（15 个现有、2 个计划） |
| CI 证据 | 13/13 success，1277 个 solution 测试 0 失败，69 份 JSON 归档 |
| 本地运行 | 17 项中 14 项通过；3 项失败均不在 CI 中运行（DRIFT-01、DRIFT-08） |
| 漂移 | DRIFT-01–10，DRIFT-07 已核实；范围外 NOTE-01（`mcp/LayerGuard` 第三份副本） |
| V3/V3_ifx | 23 相同、12 分叉（2 个含通用加固）、6 个仅 V3、502 个仅 V3_ifx |
| 修改频率 | 按 commit 计首批比较器为 `profiles/ifx/rules`、`profiles/ifx/project-map`；修正 Plan 06 §12.4 的 r3 参考数据 |
| trust contract | 判定型 6、混合型 2、执行型 5 |

**对后续阶段的直接影响**：

- 全部 CI job 的第一个可执行入口来自 PR head，V3 包没有被 CI 执行（P2、P3、P7）；
- 门禁工程依赖根 `Directory.Build.props` 的审计与 `docs/Directory.Packages.props` 的 CPM 隔离，且无 `global.json`、`NuGet.config`、lock file（P5）；
- `Test-V3ArchUnit.ps1` 已因 NU1008 失败，P5 的 package-local 基线是其修复路径。

## 4. 验证

| 验证 | 命令 | 结果 |
| --- | --- | --- |
| 基线记录可复现 | `pwsh -NoProfile -File docs/guards/V3_ifx/analysis/ifx/refactor-baseline/tools/New-RefactorBaseline.ps1 -Check` | 通过 |
| Pre | `pwsh -NoProfile -File docs/guards/V3_ifx/scripts/Invoke-IFXGuardrails.ps1 -Mode Pre -PlanPath docs/guards/plans/20260916-v3-stage-cp01-p0-baseline.plan.json` | 见提交记录 |
| Diff | CI `v3-pre-diff`，base 为 `codex/guards-principles-plan` | changed set 只包含 planned paths |
| Package | `ifx-package-test` | 本地通过（`local-results.json`） |

## 5. 回退

本检查点只新增记录文件并更新计划文档；回退为删除 `refactor-baseline/` 并还原两个计划文件。恢复点为集成分支 `abb30e4`（CP00 合入）。
