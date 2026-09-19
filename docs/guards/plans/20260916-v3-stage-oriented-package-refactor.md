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
| D16 | 比较器实现顺序（P1.1 补充） | `20260916-v3-stage-d16-comparator-order-by-commit-frequency.json` | §17 D16 |
| D17 | Plan04 阶段校验脚本退役（P1.1 补充） | `20260916-v3-stage-d17-plan04-phase-validator-retirement.json` | §17 D17 |
| D18 | Domain authority 混合信任模型（P2 补充） | `20260917-v3-stage-d18-domain-authority-hybrid-trust.json` | §11.3、§12.6、§17 D18 |
| D19 | Trusted base 首次引入例外与分步启用（P2 补充） | `20260917-v3-stage-d19-trusted-base-first-introduction.json` | §11.6、§17 D19 |
| D20 | 授权记录消费与一次性 break-glass（P3 前补充） | `20260917-v3-stage-d20-authorization-consumption-and-break-glass.json` | §11.5、§11.7、§12.1、§17 D20 |
| D21 | `Test-V3.ps1` NuGet 源统一（P3.3） | `20260917-v3-stage-d21-test-v3-nuget-source.json` | §14 P3.3、D14 |
| D22 | 未消费授权仅在 revocation-only PR 中撤销（P4 补充） | `20260917-v3-stage-d22-revocation-only-authorization-deletion.json` | §12.1、§17 D22、D20 |
| D23 | 保护义务模型、CP06 拆分与绑定报告（P4 补充） | `20260917-v3-stage-d23-protected-change-obligations.json` | §12.2–§12.4、§14 P4、§17 D23 |
| D24 | policy/config 双轨、`weaken-policy` 与 CP06b 拆分（P4 补充） | `20260917-v3-stage-d24-policy-config-dual-track.json` | §12.4、§12.6、§14 P4.3、§17 D24 |
| D25 | D18 domain authority 的 `weaken-policy` 覆盖（P4 补充） | `20260917-v3-stage-d25-domain-authority-coverage.json` | §12.4、§12.6、§14 P4.3、§17 D25 |
| D26 | Architecture Conformance 拆分、Generate/Check 过渡与 `mcp/LayerGuard` 范围（P6 补充） | `20260917-v3-stage-d26-architecture-conformance-split.json` | §14 P6、§17 D26、D12 |
| D27 | Architecture Conformance engine 与 IFX binding 分离、IFX facade 与 expand 步骤（P6.2–P6.3 补充） | `20260918-v3-stage-d27-architecture-conformance-binding-separation.json` | §14 P6、§17 D27、D12、D26 |
| D28 | CI 成本控制与 base 判定的变更范围（Actions 配额） | `20260918-v3-stage-d28-ci-cost-controls-and-change-scope.json` | §10.3、§17 D28、D10、D19 |
| D29 | Architecture Conformance engine 迁入 V3 的路径、命名与测试桥（P6.4 补充） | `20260918-v3-stage-d29-architecture-conformance-v3-relocation.json` | §14 P6.4、§17 D29、D12、D27 |
| D30 | Stage Gate 仓库外生成与 V3 overlay expand/contract 切换（P7 补充） | `20260919-v3-stage-d30-stage-gate-cutover.json` | §14 P7、§17 D1、D3、D6、D9、D14 |

每条记录的 `affectedPaths` 覆盖该决策未来会影响的路径，使后续检查点的 Pre 风险覆盖检查可以直接引用。decision schema 只允许 `summary` 与 `rationale` 两个文本字段，完整论证以 Plan 06 与 Review 为准。

## 3. PR 检查点划分

顺序遵循 Plan 06 §14 的阶段依赖：P5 须在 P2.2 之前完成，P5–P2 构成 §11.6 的受控 bootstrap 窗口。P2 生效前，受保护路径的删除和移动仍会被现有 Diff 门禁拒绝；P4 完成前，不执行任何受保护删除或移动。

| 检查点 | Plan 06 阶段 | 主要内容 | 受保护删除/移动 | §12 授权 PR | 前置 | 状态 |
| --- | --- | --- | --- | --- | --- | --- |
| CP00 | §19 准备 | D1–D15 decision 记录、本 Plan pair、Plan 06 与 Review 入库 | 无 | 不需要 | Plan 06 `APPROVED` | 已完成（PR #29，`abb30e4`） |
| CP01 | P0 | 只读基线：文件分类、调用图与 TCB 初始清单、.NET gate 冻结、漂移登记、继承配置盘点、修改频率、trust contract 分类 | 无 | 不需要 | CP00 | 已完成（PR #30，`d4057d0`） |
| CP02 | P1 | decision 校验、漂移修复、ruleset verifier、P1.5 最小 manifest/TCB skeleton | 无 | 不需要 | CP01 | 已完成（PR #31，`9012250`） |
| CP03 | P5 | V3 `build/` 基线与 lock files、locked restore、import allowlist、输出迁出、隔离验收（bootstrap 窗口开启） | 无 | 不需要（首次引入例外窗口） | CP01；可与 CP02 并行 | 已完成（PR #32，`0270e6f`） |
| CP04a | P2（前置） | 引擎脚本分离 package root 与 target root（行为不变）、domain authority 盘点、D18、authority 角色与 trust contract 输入 schema | 无 | 不需要 | CP02、CP03 | 已完成（PR #33，`c2e42d5`） |
| CP04b | P2 | trusted-base runner、candidate projection 生成与 anti-weakening 比较（P4 前失败关闭）、TCB 候选验证与 parity、`change-trusted-base` 校验、负向控制（未接入 workflow） | 无 | 不需要 | CP04a | 已完成（PR #34，`7b422c9`） |
| CP04c | P2 | 可信构建输出迁出 head 与 base、LayerGuard 测试 target root 修正、CI 激活契约检查、构建隔离负向控制、workflow 退出码修正、D19、break-glass 与保证范围文档（不切换 workflow） | 无 | 不需要 | CP04b | 已完成（PR #35，`dab8243`） |
| CP04d | P2 | workflow 全部 required check 切换为 base runner、`ci/jobs.json` 声明 trusted execution 与 TCB 候选验证生效、关闭 bootstrap 窗口；下一个 PR 验证机制生效 | 无 | 不需要（§11.6 首次引入例外，D19） | CP04c | 已完成（PR #36，`a714716`）；P2.8 验证见 `20260917-v3-stage-p28-trusted-base-verification` |
| CP05a | P2 修复 | Diff 仅接受经 base verifier 确认被本变更消费的授权记录删除（D20）、端到端回归；授权 PR → 修复 PR，修复 PR 合入需一次性 break-glass（§11.7） | 无 | `change-trusted-base`：CP05a-auth → CP05a-change | CP04d | 已完成（PR #40 `86b6150`、#41 `852d22b` 经 break-glass 合入；事后复验 #42 `2c4ed9a`、#43 `95882a6`、#44 关闭；证据 `docs/architecture/review/evidence/guards/break-glass-20260917-cp05a.md`） |
| CP05 | P3 | 通用 Diff 加固合回 V3、保护路径参数化 | 无 | TCB 非等价语义变化需 `change-trusted-base`：CP05-auth → CP05-change | CP05a | 已完成（PR #46 `6e6a21d` → #47 `bb2188b`，第一个常规两 PR TCB 变更） |
| CP06a | P4 | 完整授权 schema、Git 对象验证、保护义务 verifier 与绑定报告、`delete`/`move`/`case-rename`、revocation-only（D22、D23）；`weaken-policy` 与 `.gitattributes` 失败关闭 | 无 | `change-trusted-base`：CP06a-auth → CP06a-change | CP05 | 已完成（PR #48 `17a9652` → #49 `1501c3a`） |
| CP06b1 | P4 | policy/config 注册表（editable policy、trust/meta-policy、derived projection 精确 target、排除授权目录）、零比较器 `policy-weakening` 义务与 `weaken-policy`、`.gitattributes` 根指针通道、head 候选验证（schema、profile、history manifest、projection、monotonicity 声明）、移除旧消费变量（D24；activation exception） | 无 | `change-trusted-base`：CP06b1-auth → CP06b1-change | CP06a | 已完成（PR #50 `8086c96` → #51 `1d073ee`） |
| CP06b2 | P4 | D18 domain authority 覆盖：base verifier 针对明确 PR head SHA 重新计算 `weaken-policy` 覆盖，报告绑定 base/merge-base/head 与 registry/schema hash；此前 D18 blocking findings 失败关闭 | 无 | `change-trusted-base` 与 `weaken-policy`：CP06b2-auth → CP06b2-change（验证 CP06b1 新规则生效） | CP06b1 | 已完成（PR #52 `f6fae63` → #53 `3edb78a`；首个同时消费 `change-trusted-base` 与 `weaken-policy` 的 PR） |
| CP06c | P4 | 临时仓库两 PR 演练（`move`、`weaken-policy`、`change-trusted-base`）与证据、ruleset `strict` 断言证据、`Test-V3.ps1` parity 检查 | 无 | `change-trusted-base`：CP06c-auth → CP06c-change | CP06b2 | 已完成（PR #54 `0c523df` → #55 `1e12167`；证据 `docs/architecture/review/evidence/guards/p4-rehearsal-20260917.md`） |
| CP06d | P4 | 第一次真实受保护删除：D17 四个 Plan04 阶段校验脚本（`delete` 与 `change-trusted-base` 正交授权） | 有 | CP06d-auth → CP06d-change | CP06c | 已完成（PR #56 `b6dfacd` → #57 `7871439`；第一次真实受保护删除） |
| CP07a-prep | P6（前置） | `GatePolicyBindingTests` 的 package root 改为由 runner 传入或向上寻找 policy，使 base-owned 测试可从模板位置运行（D26，expand） | 无 | `change-trusted-base`：CP07a-prep-auth → CP07a-prep-change | CP06d | 已完成（PR #58 `45f53cd` → #59 `8d41d57`） |
| CP07a | P6.1 | 直接构建运行 `templates/ifx-layerguard`，删除 `generated/dotnet/LayerGuard`；Generate 只读、Check 做源码清单、TCB 覆盖、policy 绑定与 fixture 检查 | 有 | `delete`、`change-trusted-base` 与 `weaken-policy`：CP07a-auth → CP07a-change | CP07a-prep | 已完成（PR #60 `79d84f3` → #61 `bd79f0b`；generated 副本 174 个文件删除） |
| CP07b-prep | P6.3（前置） | 显式引用的 IFX facade 项目 `src/LayerGuard.Ifx` 与 base-owned `tests/LayerGuard.Ifx.Tests`，`GatePolicyBindingTests` 迁入；runner 检查精确项目集合与引用（D27，expand） | 有（移动） | `move` 与 `change-trusted-base`：CP07b-prep-auth → D22 撤销过期记录 → CP07b-prep-auth-r2 → CP07b-prep-change | CP07a | 已完成（PR #62 `a70fafa` → #63 `22fb907`；期间按 D22 以 #64 撤销过期记录、#65 重新授权） |
| CP07-ci | §10.3（配额） | CI 成本控制（concurrency 取消、package cache、月度 schedule）与 base 判定的变更范围：records-and-plans 时跳过 head candidate 步骤并让 architecture/quality/database 继承 base 判定 | 无 | `change-trusted-base` 与 `weaken-policy`：CP07-ci-auth → CP07-ci-change | CP07b-prep | 已完成（PR #66 `27d6109` → #67 `73ec9e9`） |
| CP07b | P6.2–P6.3 | IFX 常量作为受 TCB 管控的 IFX binding 代码移出通用 engine（所有权迁移，policy 文件不变），engine 提供 binding 扩展点，IFX binding 与 host 位于 facade 项目，通用测试只用 synthetic fixture，engine 大小写不敏感 IFX 扫描 | 以 verifier 为准 | CP07b-auth → CP07b-change | CP07b-prep | 已完成，待 PR 合入（`20260918-v3-stage-cp07b-authorization` → `20260918-v3-stage-cp07b-engine-binding-separation`） |
| CP07c-prep | P6.4（前置） | engine 的 V3 目标项目与测试路径（`Guards.ArchitectureConformance*`）、通用测试与 fixture 迁入 V3、IFX 专属 binding fixture、跨包 Check（D29，expand） | 有（移动） | 21 条 `move` 与 `change-trusted-base`：CP07c-prep-auth → CP07c-prep-change | CP07b | 已完成（本地验证：候选验证在旧位置恢复 base engine 测试并通过） |
| CP07c | P6.4–P6.6 | 通用 engine 迁入 V3 `Guards.ArchitectureConformance*`，混合型 trust contract，policy composite hash、report、失败类别与 check 名称不变的证明 | 有 | CP07c-auth → CP07c-change | CP07b | 已完成，待 PR 合入（`20260918-v3-stage-cp07c-authorization` → `20260918-v3-stage-cp07c-engine-in-v3`） |
| CP08-prep0 | P7（测试桥） | base-owned manifest/tools 测试先接受 public runner wrapper 与跨平台隔离 analysis reproducibility（D30） | 无 | `change-trusted-base`：CP08-prep0-auth → CP08-prep0-change | CP07c | 本地授权/消费模拟与 candidate verification 已通过 |
| CP08-prep | P7（前置） | IFX overlay、command manifest 与 base-owned validation 切换到 canonical V3；trusted-base 显式传递仓库外 generation root；legacy workflow runner 成为薄 wrapper（D30） | 无 | `change-trusted-base`：CP08-prep-auth-r2 → CP08-prep-change | CP08-prep0 | 本地授权/消费与 candidate parity 已通过（`bda4ae7b` → `32fcf3a7`） |
| CP08 | P7 | Stage Gate 参数化命名、仓库外生成、取消跟踪 `generated/stages`、overlay contract 并删除重复实现（保留声明期内的薄 public wrapper） | 有 | `move`、`delete`、`change-trusted-base`、`weaken-policy`：CP08-auth-r2 → CP08-change | CP08-prep | 本地授权/消费验证均已通过；十条 r2 授权由 `2cbf9e9d` 提供并由 change 一次性消费 |
| CP09 | P8 | manifest 补全、`commands/` 入口、移除 Docs Import、首批四份只读文档、analysis 生命周期 | 有（authored/evidence/report 移动；runtime 输出删除） | registry prep → base compatibility bridge → CP09 r3 auth/change | CP08 | 已完成（本地）：registry prep 与 base compatibility 授权/消费验证通过；CP09 r3 授权 `8e7bb8c6` 绑定 raw candidate `0fa43780`；最终 41 项 protected obligations/15 条授权、8 类 TCB candidate parity、Validate、Docs Check 与 package 聚合测试均通过 |
| CP10 | P9 | 轻量 workflow candidate、Preview/Install/Verify、`required-checks.json`、CODEOWNERS managed block | 无（`ci/jobs.json` 取代时有删除） | 删除 `ci/jobs.json` 时：auth → change；激活另行授权 | CP09 | 完成：base-compat auth `51b84054` → bridge `aeed75e2`；final auth `2553f7dd` → change `c0b32e85`（2026-09-20，本地，未 push/PR） |
| CP11 | P10 | 按 Plan 06 §13 分组物理迁移、V3_backup 删除、兼容 wrapper | 有 | 每个迁移分组 auth → change | CP10 | 进行中：maintenance path bridge `e9d6d0d4` → `8719ae8b`；workflow fixture bridge `0b0bf325` → `91f8041f`；tool relocation r2 auth `eab88251` → change `ff0d711a`（2026-09-20，本地，未 push/PR） |
| CP12 | P11 | 新旧 parity、失败关闭场景、隔离 Bootstrap、真实 PR 激活、旧入口清理与回退演练 | 有 | 清理删除：auth → change；激活需单独实施授权 | CP11 | 未开始 |

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
| 6 | 记录 clean baseline、恢复 commit 和测试证据位置 | 已完成（见 §7） |
| 7 | 再次获得明确的实施授权 | 已完成（用户于 2026-09-16 明确授权实施） |

§19 前置条件全部完成，实施从 CP01（P0）开始。该授权覆盖本计划 P0–P11 的实施；CI 激活（P11.4）与任何远端 ruleset 写入仍需单独授权。

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

## 7. Clean baseline 与恢复点

记录日期：2026-09-16。以下事实均通过 Git 与 GitHub API 只读核实。

### 7.1 恢复 commit

| 项 | 值 |
| --- | --- |
| 恢复 commit | `d2663392db1bacd34dd866917c45b7cdf3ede7cc`（PR #28 合入集成分支 `codex/guards-principles-plan` 的 merge commit，2026-09-16T05:15:56Z） |
| 父 commit | `98af67ab57b5a4e40dda70b5bfb03f36ea4135a0`（集成分支前一状态）、`6df2e11adc85033550ef504aad14945848936419`（PR #28 head） |
| root tree | `c744f9c128337122bce92574bbacfa2505163c96` |
| 默认分支 `main` | `ecb03726a6c67208d25e7988695c53f6326d77c0`，本重构不以其为 base，不受影响 |

CP00 分支（`codex/v3-stage-oriented-package-refactor`）相对恢复 commit 只新增或修改 `docs/guards/plans/`、`docs/guards/V3_ifx/decisions/history/` 与 `.claude/`；门禁实现、profile、policy、workflow、CODEOWNERS、`mcp/LayerGuard/` 与构建配置均与恢复 commit 逐字节一致（`git diff d266339 HEAD` 排除上述三处后为空）。

### 7.2 门禁相关对象 ID（恢复 commit）

| 路径 | 类型 | object ID |
| --- | --- | --- |
| `docs/guards` | tree | `8b64f2fcecb591d0ebc9929b1de386d3338ffeda` |
| `docs/guards/V3` | tree | `026bad5af343d74031b7410180de74adebb9a981` |
| `docs/guards/V3_backup` | tree | `026bad5af343d74031b7410180de74adebb9a981`（与 V3 相同） |
| `docs/guards/V3_ifx` | tree | `fa326bed7d65c9b4424a898cfb6da9846f1a6688` |
| `.github/workflows` | tree | `3f345cba646da9112deb10bf0ab4984dceacade3` |
| `.github/CODEOWNERS` | blob | `3b36962f22e2aeb3782cb7ff1b9788bd5430f42a` |
| `mcp/LayerGuard` | tree | `79f33367698312262fa7eeec2a49a314fafa2100` |
| `Directory.Build.props` | blob | `7e552f72fbb78404396eb07db4ba9f2b113578d7` |
| `Directory.Packages.props` | blob | `d7234caf898e75045101ae0f269af80e8430f219` |
| `docs/Directory.Packages.props` | blob | `5f9708a97f38de5ec3174674b50ebba430ba9504` |
| `.gitattributes` | blob | `f03c45f29ecd37e5f333c6cef0d4d83f6b6cdbd1` |

后续检查点可用 `git rev-parse <commit>:<path>` 与上表比对，判断某路径是否仍处于基线状态。

### 7.3 基线测试证据

| 项 | 值 |
| --- | --- |
| Workflow run | [V3 IFX Guardrails #35055279816](https://github.com/von12549/IFX/actions/runs/35055279816)（`pull_request`，attempt 1，2026-09-16T04:21:28Z，conclusion `success`） |
| 被测 commit | PR #28 merge ref `5154f9cbbf0dd3102b79b759a6f62e282b4ad197`；其 root tree 为 `c744f9c128337122bce92574bbacfa2505163c96`，与恢复 commit 完全相同，即 CI 验证的正是恢复 commit 的内容 |
| Required checks | 13/13 `SUCCESS`：`v3-pre-diff`、`v3-architecture`、`v3-quality-solution`、`v3-quality-assembly`、`v3-quality-frontend`、`v3-specialized-g03`、`v3-specialized-g04`、`v3-specialized-g05`、`v3-specialized-plan04`、`v3-specialized-database`、`v3-historical-integrity`、`v3-cross-platform-ubuntu-latest`、`v3-cross-platform-windows-latest` |
| Ruleset | `23459908`（IFX V3 Required Checks），`strict: true`，作用于默认分支与 `codex/guards-principles-plan` |
| 证据位置 | 该 run 的 13 个 artifact，名称为 `<check>-5154f9cbbf0dd3102b79b759a6f62e282b4ad197`，内容为 `artifacts/guards/v3-ifx` 下的 summary、report 与日志 |
| 证据有效期 | 全部 artifact 于 **2026-12-15T04:21:29Z** 过期 |

**证据保全**：artifact 过期时间早于本计划预计完成时间。CP01（P0.1）必须在过期前下载各 check 的 summary/report（`v3-quality-frontend` 的 48 MB 构建产物除外），纳入 P0 基线记录并记录其 SHA-256；此后以仓库内记录为准。

### 7.4 恢复方式

- **整体回退**：以恢复 commit 的路径内容为准，`git checkout d2663392db1bacd34dd866917c45b7cdf3ede7cc -- <paths>` 取回受影响路径，并以独立 PR 合入。
- **选择性恢复**：按 §7.2 的 object ID 逐路径比对后，只恢复偏离基线的路径。
- **门禁约束**：P4 生效前，恢复 PR 若需删除新增的受保护路径，会被现有 Diff 拒绝；P4 生效后，恢复中的受保护删除、移动或 TCB 非等价变化同样需要 §12 授权。若门禁自身故障导致无法合入恢复 PR，只能使用 Plan 06 §11.7 的仓库外 break-glass。
- 每个检查点的 pair 应记录其合入 commit，作为该检查点之后的细粒度恢复点；P11.6 的 selective restore 演练以本节为起点。
