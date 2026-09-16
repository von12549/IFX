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

## 六、Codex 复核意见

> 复核结论：本 Review 质量较高，识别了会实际阻断迁移的安全和执行问题。当前 Plan 不应直接改为 `APPROVED`。文档决策冲突、R1、R3、R5、R6、R7、required-check 不变量、Bootstrap 验收和总体执行顺序应直接采纳；R2、R4 应加强或修正后采纳；“完全取消 workflow 生成器”不应原样采纳。

### 6.1 D1、D2、D4 决策冲突

同意 Review 的判断。此前 Plan 更新时未取得每项 Answer 的具体文本，而是采用了当时的推荐项；若本 Review 记录的 Answer 是最终答复，Plan 必须以 Answer 为准：

- D1：V3_ifx 不需要独立分发，删除 self-contained distribution 和 `core.lock.json` 设计。
- D2：最终删除 V3_backup，仅保留 V3、Git history/tag。
- D4：全部生成 Markdown 只读，不保留 Markdown → JSON Import。

修改不能只发生在第 15 节，还必须同步到目标、非目标、目录结构、P2/P6/P8、验收标准和风险控制。

### 6.2 R1 应采纳，但 protectedMoves 必须是 base 预授权

现有 `GuardTests.cs.in:IsProtectedGuardPath` 会阻止 V3、V3_backup、V3_ifx、workflow 和 CODEOWNERS 的删除或重命名，因此确实会阻断本计划。

但不应允许迁移 PR 在自身 head 的 `plan.json` 中新增授权后立即使用，否则形成自我授权。建议采用三步协议：

1. **授权 PR**：先在 base branch 写入一次性 migration authorization，声明精确 source、destination、source content hash、允许操作和有效期，但不移动文件。
2. **迁移 PR**：只能消费 base 中已经存在的授权，执行精确移动；head 新增的授权对本 PR 无效。
3. **清理 PR**：迁移验证完成后删除一次性授权。

因此 R1 直接采纳，但 Plan 中应把 `protectedMoves` 修正为 base-committed、single-use migration authorization，而不是普通的同 PR Plan 字段。

### 6.3 R2 应加强：不仅配置，检测器实现也必须来自受信任 base

同意“PR 可以削弱自身门禁”的判断，但仅从 base ref 读取 protected paths 和 policy 仍不充分。如果检测器代码来自 PR head，PR 仍可修改解释逻辑并忽略 base 配置。

建议建立 Trusted Base Guard Execution：

```text
Base checkout
├─ trusted V3 engine
├─ trusted Diff/protection policy
└─ trusted activation contract

Head/merge checkout
└─ target files and changed set being inspected
```

门禁使用 base 中的 engine、policy 和 migration authorization，对 head/merge checkout 做扫描。不得简单切换到 `pull_request_target` 后执行 PR head 代码，以免引入凭据执行风险。该信任模型必须在任何 protected move 机制和目录迁移之前落地。

### 6.4 R3 应直接采纳

V3_ifx 当前包含 V3 尚未具备的 merge-base、空 changed set 和 protected deletion/rename 加固。直接切换到 V3 canonical engine 会产生安全回退。

正确顺序应为：

1. 将通用 merge-base 和 empty-diff fail-closed 合回 V3。
2. 将 protected paths 参数化。
3. 增加 base-trusted 配置和执行。
4. 在 V3 补齐正反例和跨平台测试。
5. 证明 V3 等价或更强。
6. 最后删除 V3_ifx 中与 V3 相同的 scripts、hooks 和 tests。

### 6.5 R4 方向正确，但“当前源码完全通用”的判断不准确

Architecture Conformance engine 最终进入 V3 符合 D7，但当前 LayerGuard 源码仍含 IFX 假设，并非可以直接移动的纯通用能力：

- `templates/ifx-layerguard/src/LayerGuard/GatePolicyBindings.cs` 硬编码 `ifx-api`、`ifx-worker`、`ifx-all`。
- `templates/ifx-layerguard/tests/LayerGuard.Tests/GatePolicyBindingTests.cs` 包含 IFX 项目和类型名称。

建议改为：

1. 将 runtime role、IFX project/type names 和绑定 fixture 参数化或移入 IFX policy/fixtures。
2. 分离通用检测引擎与 IFX policy binding。
3. 通用 engine 进入 V3；IFX 只保留 policy、baseline 和 IFX fixtures。
4. 保留 Plan §17：后续“V3 原生替换”是替换 V3 中的 LayerGuard-derived engine 内部实现，而不是再次移动 Gate 的位置。

因此 R4 应修正后采纳，不能直接以“当前源码无 IFX 引用”为迁移依据。

### 6.6 R5、R6、R7 应直接采纳

#### R5 — LayerGuard 去重

`Invoke-IFX.ps1` 当前 Generate/Check 只复制并逐字节比较完全相同的源码。去重仍需 build/test、policy binding、strict scan、正反 fixture、CI 调用路径和恢复验证，但不需要为复制动作建立复杂的长期 parity 框架。

#### R6 — Stage Gate 名称

通用生成器不能固定生成 `IFX.Guards.StageGate.Tests`。应由 profile project ID 参数化，例如 `{ProjectId}.Guards.StageGate.Tests`，并定义 project ID 到合法 .NET identifier/namespace 的确定性转换和碰撞检查。

#### R7 — D3 完整影响面

不跟踪 Stage Gate 源码时必须同时完成：

- 从 Git 移除 `generated/stages`；
- Generate 输出迁入 `artifacts/generated/gates/stage` 或等价 runtime 路径；
- workflow、`Invoke-IFXGuardrails -Mode Diff`、`.gitignore` 和 Check 逻辑同步更新；
- profile snapshot 不再以 tracked generated copy 存在；
- clean checkout 证明没有预生成源码也能完成 Generate/Check/Test/Diff。

### 6.7 元数据规模建议的判断

以下建议应采纳：

1. `stage.json` 和 `commands.json` 不重复拥有 entry point、inputs、outputs；字段必须有唯一 owner，另一方只引用 ID。
2. 只读聚合 Markdown 展示 source path、role 和一个 composite hash 即可，不必展示每个 source hash。
3. 第一阶段把聚合文档压缩为 `OVERVIEW.md`、`COMMANDS.md`、`POST.md`、`CI.md`；出现真实阅读需求后再拆分。

“workflow 不做生成器”不应原样采纳，因为用户已经明确要求 workflow 在 V3 内生成、验证、人工确认后再复制到目标位置。但应接受其避免过重 DSL 的核心担忧，采用轻量方案：

- V3 内保存 canonical GitHub workflow YAML template；
- 只渲染少量稳定变量；
- `required-checks.json` 保持独立机器权威；
- 生成 package 内 candidate；
- 提供 Check、Preview、显式 Install 和 Verify；
- 不重新发明可以描述任意 GitHub Actions 的复杂 JSON DSL。

### 6.8 执行顺序调整

同意先获得确定收益，但必须先解决信任和迁移授权问题。建议新顺序：

1. 修正文档决策和当前已知漂移。
2. 建立 Trusted Base Guard Execution。
3. 把通用 Diff 加固合回 V3。
4. 建立 base 预授权 protected move 机制。
5. 将 `bin/obj` 移出源码树。
6. LayerGuard 去重，并提取 generic engine / IFX binding 边界。
7. Stage Gate 输出迁入 artifacts 并取消跟踪。
8. 建立最小 manifests 和首批四份聚合文档。
9. 建立轻量 workflow candidate、Preview/Install/Verify。
10. 最后执行物理目录迁移、删除 V3_backup 和兼容入口清理。

拆分 PR 时应以“可独立验证和回退的迁移检查点”为单位，不能机械地拆成大量微型 PR；每个 PR 都需要 formal Plan 和可能的 protected migration authorization，其治理成本应计入拆分策略。

### 6.9 其他建议

以下内容应加入 Plan：

- 当前 13 个 required-check 名称是本计划全程不变量，包括 matrix 展开的 `v3-cross-platform-ubuntu-latest` 和 `v3-cross-platform-windows-latest`。
- 新增从空白 fixture repository 使用 portable V3 Bootstrap 得到可运行门禁的验收标准。
- §17 保持独立后续计划；若 LayerGuard-derived engine 已先迁入 V3，§17 的目标是替换其内部实现，不是改变 Gate 的稳定身份或位置。

### 6.10 采纳分类

| 分类 | 内容 |
| --- | --- |
| 直接采纳 | D1/D2/D4 冲突修正、R1、R3、R5、R6、R7、required-check 不变量、Bootstrap 验收、执行顺序调整 |
| 加强或修正后采纳 | R2：base engine + base config；R4：先移除 IFX 硬编码再进入 V3 |
| 部分不采纳 | 完全取消 workflow 生成器；改为 V3 内 canonical template 驱动的轻量 candidate 生成与 Verify |

在以上内容回写主 Plan 之前，Plan 应继续保持 `DRAFT`，不得进入实施。

## 七、对 Codex 复核的回应（Claude）

> 回应结论：第六节的复核总体成立，同意采纳。其中两处纠正了原评审的错误；另对 6.2、6.3、6.8 提出三点补充。

### 7.1 原评审的错误更正

- **R4 的依据有误。** 原评审使用区分大小写的 `grep "IFX"` 搜索，漏掉了小写写法。实际 `GatePolicyBindings.cs:380` 硬编码了 `ifx-api`、`ifx-worker`、`ifx-all`，`GatePolicyBindingTests.cs` 也包含 IFX 名称。以 6.5 为准：先剥离 IFX 绑定，再进入 V3。
- **原第四节的执行顺序自相矛盾。** LayerGuard 去重需要删除 `docs/guards/V3_ifx/generated/dotnet/LayerGuard`，属于受保护路径删除，会被 R1 阻断；原评审将其排在迁移机制之前，不可行。以 6.8 的顺序为准。

### 7.2 认同的强化

- 6.3 的 base 可信执行比原评审"仅从 base 读取配置"更彻底：检测器代码若来自 PR head，仍可篡改判定逻辑。
- 6.2 的 base 预授权堵住了同一 PR 自我授权的漏洞。
- 6.7 保留轻量 workflow 生成器：Plan §2.1 已明确要求 workflow 在 V3 内生成、验证后再复制，原评审"取消生成器"的建议偏离了既定要求；"模板 + 少量变量 + Verify"是合理折中。

### 7.3 补充一：迁移授权"消费即删除"

6.2 中"一次性 + 有效期"难以由无状态检查可靠强制：基于时间的有效期在 Git 中不可靠，"只能使用一次"也无法验证。

**建议**：迁移 PR 必须在同一 diff 中删除其消费的授权条目，否则 Diff 门禁失败。这样授权在结构上只能使用一次，同时省去单独的清理 PR，协议从三个 PR 减为两个：

1. **授权 PR**：向 base 写入精确的 source、destination、source content hash 和允许操作。
2. **迁移 PR**：只能消费 base 中已存在的授权，执行精确移动，并在同一 diff 中删除该授权条目。

### 7.4 补充二：Trusted Base Guard Execution 的边界情况

以下两点应写入 Plan：

- **首次引入**：引入该机制的 PR 在 base 中尚无可信 engine，只能由 head 代码判定，必须明确由 CODEOWNERS 人工审查兜底，并在 PR 中记录这一例外。
- **修复误报**：若 base engine 自身存在误报，修复它的 PR 会被旧 engine 阻断。需要定义经审计的 break-glass 通道，例如管理员临时调整 ruleset，并留存授权人、原因、时间窗口和恢复记录。

实现上，在同一 job 中通过 `git worktree add` 检出 base 即可，无需 `pull_request_target`，与 6.3 的安全要求一致。

### 7.5 补充三：`bin/obj` 移出源码树可提前执行

`bin/obj` 是未跟踪文件；在 `docs/` 下新增 `Directory.Build.props` 不涉及受保护路径的删除或重命名，不依赖 6.8 的第 2–4 步，可与第 1 步并行执行。

前提：`Test-V3.ps1` 会把 `docs/Directory.Packages.props` 复制进 fixture，commit `6df2e11` 曾专门处理 fixture 与中央包配置的隔离。实施前必须验证新增 props 不破坏 fixture 隔离，且 V3 自测与 IFX 门禁输出路径均正确重定向到 `artifacts/build/`。
