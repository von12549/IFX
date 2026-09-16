# Review：06 V3 Stage 化、自包含配置与门禁工程重构计划

> 评审对象：[06-v3-stage-oriented-package-refactor.md](06-v3-stage-oriented-package-refactor.md)（commit `ad3e67d`）
>
> 评审日期：2026-09-16
>
> 评审方式：阅读计划全文，并对照当前 `docs/guards/V3`、`docs/guards/V3_backup`、`docs/guards/V3_ifx` 和 `.github/workflows/v3-ifx-guardrails.yml` 的实际文件核对。
>
> 结论：**方向正确，但在改为 `APPROVED` 前需要先解决文档内矛盾和一个会阻断迁移的门禁问题，并缩小规模、调整执行顺序。**

## 一、文档自身的矛盾（APPROVED 前必须修正）

第 15 节声明 D1–D8 已冻结，但以下三项的"决定"正文与 Answer 不一致：

| 决策 | 正文写的 | Answer | 需同步修改的位置 |
| --- | --- | --- | --- |
| D1 | 保留 self-contained 分发和 `core.lock.json` | 不需要 V3_ifx 单独运行 | §1.7、§5 末段、P2.2、§14 中的 core lock |
| D2 | 冻结为只读 release snapshot | 直接删除，仅保留 V3 源码包 | P8.4、§13 |
| D4 | 一对一配置页可保留受控 Import | 全部只读 | §2.5、§9.2 "是否允许 Import"、P6.5 |

## 二、计划未覆盖、但会直接影响执行的问题

### R1 — 现有 Diff 门禁会阻断本次迁移（最严重）

`V3_ifx/templates/dotnet/GuardTests.cs.in` 中的 `IsProtectedGuardPath` 硬编码了以下路径：

- `.github/CODEOWNERS`
- `.github/workflows/v3-ifx-guardrails.yml`
- `mcp/LayerGuard/`
- `docs/guards/plans/`
- `docs/guards/V3/`
- `docs/guards/V3_backup/`
- `docs/guards/V3_ifx/`

其中删除（`D`）和重命名（`R`）都会直接失败。因此 P8 的每一次目录移动、D2 删除 V3_backup，都无法通过 `v3-pre-diff`。

**建议**：先设计受控迁移机制，例如在 plan.json 中声明经批准的 `protectedMoves`（源 → 目标，并要求内容 hash 一致）。该机制本身也必须作为一次独立的门禁变更走完整流程。

### R2 — 门禁可被 PR 自身削弱

CI 从 PR head 的 checkout 执行 Generate；保护路径又写死在 head 版本的模板中。一个 PR 修改 `IsProtectedGuardPath` 后，会按修改后的规则判定自己，目前只有 CODEOWNERS 审查在拦截。

**建议**：在 P3.2 把保护路径移入 Diff 配置时，明确要求 Diff 从 **base ref** 读取保护路径与 policy，而不是 head。

### R3 — V3 落后于 V3_ifx，不能直接作为 canonical engine

- `GuardTests.cs.in` 中的三项 Diff 加固只存在于 V3_ifx：
  - merge-base 校验（缺失时失败关闭）；
  - 受保护路径删除/重命名检测；
  - 空 changed set 失败。
- `tests/Test-V3.ps1` 两边的 NuGet 源配置不同：V3 使用离线 `NuGet.Offline.Config`，V3_ifx 使用 nuget.org 的 `NuGet.Test.Config`。
- 若直接让 V3_ifx 改用 V3 engine，上述加固会丢失，属于安全回退。

**建议**：在 P2/P3 增加明确步骤——先把通用加固合回 V3，保护路径参数化，再切换 overlay。另外，V3_ifx 中 `scripts/Invoke-V3.ps1`、`Invoke-V3Architecture.ps1`、`Invoke-V3Docs.ps1`、`Invoke-V3Setup.ps1`、`tests/Test-V3Tools.ps1`、`tests/Test-V3ArchUnit.ps1`、`hooks/Invoke-PlanHook.ps1` 与 V3 逐字节相同，可在此步删除并改为调用 `../V3`。

### R4 — LayerGuard 应归属 V3，而非 V3_ifx

`templates/ifx-layerguard/src/` 下的 C# 源码不含任何 IFX 引用，是完全由 policy JSON 驱动的通用能力。按 D1 Answer（新仓库使用 V3 源码包生成门禁）和 D7（能通用化的先进入 V3），Architecture Conformance Gate 应位于 V3，IFX 只提供 `policy/layerguard.json` 等策略输入。否则新仓库无法获得架构门禁。

§8.2 的目标路径和 §17 的"V3 原生替换"定位需要相应调整。

### R5 — LayerGuard 去重比计划估计的简单

`scripts/Invoke-IFX.ps1` 的 Generate/Check 本质就是把 `templates/ifx-layerguard` 复制到 `generated/dotnet/LayerGuard` 再逐文件比较。两个目录除本地 `bin/obj` 外完全一致，P5.3 的 parity 证明可以大幅简化：删除生成副本、改为直接构建运行唯一源码即可。

### R6 — Stage Gate 命名违反验收标准 #3

§8.1 把 `IFX.Guards.StageGate.Tests` 放在 V3 通用生成器产物中，违反"通用 V3 engine/template 中不存在 IFX 路径、项目名或 policy 硬编码"。应改为由 profile 的 project ID 参数化生成，例如 `{ProjectId}.Guards.StageGate.Tests`。

### R7 — D3（不跟踪生成源码）的影响面需写全

- `V3_ifx/generated/stages` 目前被 Git 跟踪，其中还包含 `profiles/ifx` 的 JSON 副本。
- workflow 的 `v3-pre-diff` 与 `v3-cross-platform` job，以及 `Invoke-IFXGuardrails.ps1 -Mode Diff`，都把 Generate 输出写回源码树的 `docs/guards/V3_ifx/generated/stages`。
- 落实 D3 必须同时把这些输出路径改到 `artifacts/`，并更新 `.gitignore` 与 Check 逻辑。

## 三、规模：元数据层偏重

现状规模：

- V3：41 个 tracked 文件；
- V3_ifx：537 个 tracked 文件，其中 348 个是 LayerGuard 的 template/generated 双份；
- PowerShell 实现合计约 1.8k 行。

计划将新增 `guard-system.json`、每个 Stage 一份 `stage.json`、`commands.json`、`docs-map.json`、`activation.json`、generated asset manifest 及其 schema，外加 workflow 生成器和 9 份聚合 Markdown。治理层体量可能超过被治理内容，且自身也会漂移，而漂移恰是本计划要解决的问题。

建议精简：

1. **workflow 不做生成器。** 当前 workflow 仅 285 行，且 GitHub 只读取 `.github/workflows`。保留手写 YAML 为权威，V3 只提供只读 Verify，检查：
   - job name 与 `required-checks.json`、远端 ruleset 一致；
   - 仅调用 `commands/` 下的公共入口；
   - 不直接调用 `tests/` 或内部脚本。

   这同时解决 `ci/jobs.json` 未受校验的问题。模板/Install 流程（D5）仅保留给 CODEOWNERS managed block，或作为新仓库示例。
2. **消除 `stage.json` 与 `commands.json` 的字段重叠。** 两者都声明 entryPoint、inputs、outputs，应只保留一处权威，另一处引用。
3. **生成 Markdown 不需要逐源 SHA-256 表。** Check 重新渲染并逐字节比较已能发现过期；逐源 hash 只会增加合并冲突。保留来源路径与角色即可，最多加一个合成 hash。
4. **聚合文档数量先压缩。** 9 份可先收敛为 OVERVIEW、COMMANDS、CI、POST 四份，有实际需求再拆。

## 四、执行顺序：先拿确定收益，再评估完整框架

当前顺序把最容易获得的收益压在 P5/P8 之后。建议先做以下独立小 PR，每个都由现有 CI 兜底：

1. **`bin/obj` 移出源码树**：在 `docs/` 下增加 `Directory.Build.props`，设置 `ArtifactsPath` 指向 `artifacts/build`。改动小，与目录结构无关。
2. **LayerGuard 去重**：删除 `generated/dotnet/LayerGuard`，直接从唯一源码构建运行（见 R5）。
3. **加固合回 V3**：保护路径参数化并从 base ref 读取，删除 V3_ifx 中与 V3 重复的脚本（见 R2、R3）。
4. **受保护路径迁移机制**：解决 R1，这是后续删除与移动的前提。
5. **删除 V3_backup**：其内容与 V3 逐字节相同，历史由 git tag 保留。
6. **修复已知漂移**：处理 P0.5 列出的项，并加入 workflow ↔ required checks 的 Verify。

完成后重复与垃圾已基本清理，再重新评估 P3/P6/P7 的完整框架是否仍值得全部实施。物理目录迁移（P8）放到最后。

注意：`v3-pre-diff` 要求每个 PR 恰好改动一个 `*.plan.json`。PR 拆得越细，plan pair 与保护路径豁免的开销越大，拆分粒度需计入该成本。

## 五、其他补充

- **把 required check 名称写成全程不变量。** 当前 13 个 check、ruleset `23459908`，包括 matrix 展开后的 `v3-cross-platform-ubuntu-latest` 与 `v3-cross-platform-windows-latest`。任何改名都应作为单独授权的变更。
- **增加验收标准**：从 V3 在空白 fixture 仓库执行 Bootstrap，得到可运行的门禁。这是 D1 Answer 真正需要证明的能力，现有第 13 节未覆盖。
- **§17 作为独立后续计划是合理的。** 若按 R4 将 Architecture Conformance Gate 放入 V3，该节的"V3 原生替换"定位需同步调整。
