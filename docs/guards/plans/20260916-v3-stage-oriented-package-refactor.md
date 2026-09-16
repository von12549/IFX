# V3 Stage 化门禁包重构 — 正式 Plan pair

本 Plan pair 把已批准的 [Plan 06](06-v3-stage-oriented-package-refactor.md)（r4，`APPROVED`）绑定到 V3 formal Plan 契约，供 Pre 与 Diff 校验使用。设计、阶段细节、验收标准与风险控制以 Plan 06 为唯一权威；评审记录见 [Plan 06 Review](06-v3-stage-oriented-package-refactor.review.md)。本文件只负责：

- D1–D15 decision 记录索引；
- P0–P11 的 PR 检查点划分；
- Plan 06 §19 正式执行前置条件的完成状态；
- 本检查点（CP00）的范围与验证。

## 1. 与 V3 formal Plan 契约的关系

现有 Diff 门禁要求每个 PR **恰好改动一个** `*.plan.json`，并按精确路径比对 changed set。因此：

- 本 pair（`20260916-v3-stage-oriented-package-refactor`）是整个重构计划的总入口，其 sidecar 的 `plannedPaths` 只覆盖 **CP00**。
- CP01 起每个检查点建立自己的 pair，命名为 `YYYYMMDD-v3-stage-cpNN-<slug>.md/.plan.json`，在 Markdown 中引用本 pair 与 Plan 06 对应阶段，并在 `decisionPaths` 中引用适用的 D1–D15 记录。
- 检查点需要 Plan 06 §12 授权时，授权 PR 与变更 PR 各自拥有独立 pair，命名分别以 `-auth` 与 `-change` 结尾。
- 检查点内的精确路径在该检查点的 pair 中冻结；本文件不预先列举。

## 2. Decision 记录

D1–D15 在正式执行准备阶段首次创建（Plan 06 §19 第 2 项），P1.1 只负责校验与补充。记录当前位于 `docs/guards/V3_ifx/decisions/history/`；Plan 06 §5 的目标位置 `shared/decisions/` 在 P10 物理迁移时通过 §12 授权移动。

| 决策 | 主题 | 记录文件 | Plan 06 |
| --- | --- | --- | --- |
| D1 | V3_ifx 分发边界 | `20260916-v3-stage-d01-v3-ifx-distribution-boundary.json` | §17 D1 |
| D2 | V3_backup 退役 | `20260916-v3-stage-d02-v3-backup-retirement.json` | §17 D2 |
| D3 | 不跟踪 Stage Gate 生成源码 | `20260916-v3-stage-d03-untracked-stage-gate-source.json` | §17 D3 |
| D4 | 生成 Markdown 只读 | `20260916-v3-stage-d04-read-only-generated-markdown.json` | §17 D4 |
| D5 | 激活文件安装方式 | `20260916-v3-stage-d05-activation-install-modes.json` | §17 D5 |
| D6 | 稳定命名 | `20260916-v3-stage-d06-stable-naming.json` | §17 D6 |
| D7 | 迁移单位与顺序 | `20260916-v3-stage-d07-migration-unit-and-order.json` | §14、§17 D7 |
| D8 | 历史完整性 Stage 归属 | `20260916-v3-stage-d08-historical-integrity-stage.json` | §17 D8 |
| D9 | Trusted Base Guard Execution | `20260916-v3-stage-d09-trusted-base-guard-execution.json` | §11、§17 D9 |
| D10 | 受保护变更授权 | `20260916-v3-stage-d10-protected-change-authorization.json` | §12、§17 D10 |
| D11 | 轻量 workflow 模板 | `20260916-v3-stage-d11-lightweight-workflow-template.json` | §10、§17 D11 |
| D12 | Architecture Conformance 所有权 | `20260916-v3-stage-d12-architecture-conformance-ownership.json` | §8.2、§17 D12 |
| D13 | Policy/config 双轨验证与单调性 | `20260916-v3-stage-d13-policy-config-monotonicity.json` | §12.4、§17 D13 |
| D14 | package-local 构建基线与可信构建隔离 | `20260916-v3-stage-d14-package-local-build-baseline.json` | §8.3、§11.2、§17 D14 |
| D15 | Trusted Base Component 候选升级 | `20260916-v3-stage-d15-trusted-base-component-upgrade.json` | §11.5、§17 D15 |

每条记录的 `affectedPaths` 覆盖该决策未来会影响的路径，使后续检查点的 Pre 风险覆盖检查可以直接引用。decision schema 只允许 `summary` 与 `rationale` 两个文本字段，完整论证以 Plan 06 与 Review 为准。

## 3. PR 检查点划分

顺序遵循 Plan 06 §14 的阶段依赖：P5 须在 P2.2 之前完成，P5–P2 构成 §11.6 的受控 bootstrap 窗口。P2 生效前，受保护路径的删除和移动仍会被现有 Diff 门禁拒绝；P4 完成前，不执行任何受保护删除或移动。

| 检查点 | Plan 06 阶段 | 主要内容 | 受保护删除/移动 | §12 授权 PR | 前置 |
| --- | --- | --- | --- | --- | --- |
| CP00 | §19 准备 | D1–D15 decision 记录、本 Plan pair、Plan 06 与 Review 入库 | 无 | 不需要 | Plan 06 `APPROVED` |
| CP01 | P0 | 只读基线：文件分类、调用图与 TCB 初始清单、.NET gate 冻结、漂移登记、继承配置盘点、修改频率、trust contract 分类 | 无 | 不需要 | CP00 |
| CP02 | P1 | decision 校验、漂移修复、ruleset verifier、P1.5 最小 manifest/TCB skeleton | 无 | 不需要 | CP01 |
| CP03 | P5 | V3 `build/` 基线与 lock files、locked restore、import allowlist、输出迁出、隔离验收（bootstrap 窗口开启） | 无 | 不需要（首次引入例外窗口） | CP01；可与 CP02 并行 |
| CP04 | P2 | Trusted base 执行、可信构建隔离、trust contract、TCB 候选升级协议、负向控制（关闭 bootstrap 窗口） | 无 | 不需要（§11.6 首次引入例外，须写入 decision） | CP02、CP03 |
| CP05 | P3 | 通用 Diff 加固合回 V3、保护路径参数化 | 无 | TCB 非等价语义变化需 `change-trusted-base`：CP05-auth → CP05-change | CP04 |
| CP06 | P4 | 完整授权 schema、Git 对象验证、policy/config 双轨与零比较器、两 PR 演练 | 无 | TCB 变化需 `change-trusted-base`：CP06-auth → CP06-change | CP05 |
| CP07 | P6 | LayerGuard 去重、IFX binding 剥离、engine 进入 V3、trust contract | 有 | 按变更拆分：删除生成副本、binding 剥离、engine 移动各自 auth → change | CP06 |
| CP08 | P7 | Stage Gate 参数化命名、仓库外生成、取消跟踪 `generated/stages`、overlay 切换并删除重复副本 | 有 | 取消跟踪与删除副本：auth → change | CP07 |
| CP09 | P8 | manifest 补全、`commands/` 入口、移除 Docs Import、首批四份只读文档、analysis 生命周期 | 可能（analysis 运行输出迁出） | 涉及受保护移动/删除时：auth → change | CP08 |
| CP10 | P9 | 轻量 workflow candidate、Preview/Install/Verify、`required-checks.json`、CODEOWNERS managed block | 无（`ci/jobs.json` 取代时有删除） | 删除 `ci/jobs.json` 时：auth → change；激活另行授权 | CP09 |
| CP11 | P10 | 按 Plan 06 §13 分组物理迁移、V3_backup 删除、兼容 wrapper | 有 | 每个迁移分组 auth → change | CP10 |
| CP12 | P11 | 新旧 parity、失败关闭场景、隔离 Bootstrap、真实 PR 激活、旧入口清理与回退演练 | 有 | 清理删除：auth → change；激活需单独实施授权 | CP11 |

拆分原则：

- 以可独立验证和回退的检查点为单位，不机械拆成微型 PR（D7）；
- 一个检查点内若同时存在授权需求不同的变更，按授权边界拆分为多个 PR；
- 每个检查点完成后更新本文件的状态列或在其 pair 中记录完成证据；
- 13 个 required check 名称在全部检查点保持不变（Plan 06 §10.3）。

## 4. Plan 06 §19 前置条件状态

| # | 前置条件 | 状态 |
| --- | --- | --- |
| 1 | Plan 06 经针对性核对并改为 `APPROVED` | 已完成（commit `9c381e8`） |
| 2 | 首次创建 D1–D15 decision 记录并纳入 `decisionPaths` | CP00 完成 |
| 3 | 建立正式 Plan pair 并给出 PR 检查点划分 | CP00 完成（本 pair 与 §3） |
| 4 | sidecar 列出精确 planned paths、area IDs、rule IDs、commands 和 decisions | CP00 sidecar 完成；CP01 起由各检查点 pair 负责 |
| 5 | 运行 Pre 并确认 risk、area、rule 和 command 关联完整 | CP00 以本 sidecar 运行 Pre（见 §6） |
| 6 | 记录 clean baseline、恢复 commit 和测试证据位置 | 待完成：CP01 开始前记录 |
| 7 | 再次获得明确的实施授权 | 待用户授权 |

第 6、7 项完成前，不开始 CP01（P0）。

## 5. CP00 范围

**包含**：

- `docs/guards/V3_ifx/decisions/history/` 下 15 个 decision 记录；
- 本 Plan pair；
- 已提交到本分支的 Plan 06 与 Review；
- 已提交到本分支的 Claudalytics 停用清理（`.claude/hooks/` 两个脚本删除、`.claude/settings.json` 与 `.claude/settings.local.json` 移除遥测、hook 与插件配置）。该清理与重构无关，但已位于同一分支，为使 Diff 通过而显式声明；不涉及风险触发路径。

**不包含**：任何门禁脚本、模板、profile、policy、workflow、CODEOWNERS、ruleset、required check 或目录结构变化。

## 6. 验证

| 验证 | 命令 | 期望 |
| --- | --- | --- |
| Pre | `pwsh docs/guards/V3_ifx/scripts/Invoke-IFXGuardrails.ps1 -Mode Pre -PlanPath docs/guards/plans/20260916-v3-stage-oriented-package-refactor.plan.json` | 通过：路径已映射，area、risk、command 与 decision 覆盖完整 |
| Diff | CI `v3-pre-diff`，base 为集成分支 `codex/guards-principles-plan` | changed set 只包含 planned paths，无受保护删除 |
| Package | `ifx-package-test`（CI `v3-architecture` 与 `v3-cross-platform-*`） | 通过 |

集成分支 base 为 `codex/guards-principles-plan`（`d266339`）。
