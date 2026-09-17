# CP05 — Plan 06 P3：通用 Diff 加固合回 V3、保护路径参数化

本 pair 是 [正式 Plan pair](20260916-v3-stage-oriented-package-refactor.md) 检查点 CP05 的变更 PR，实施 [Plan 06](06-v3-stage-oriented-package-refactor.md) §14 P3（P3.0–P3.5），并记录 D21。它按 §11.5 与 D20 消费 `20260917-v3-stage-cp05-authorization` 加入的 `change-trusted-base` 授权，是 break-glass 之后第一个常规两 PR 流程的 TCB 变更。

## 1. 变更

**Diff 模板（P3.1、P3.2）**：

- `docs/guards/V3/templates/dotnet/GuardTests.cs.in` 获得 V3_ifx 的全部通用加固：committed range 先验证 base/head commit 并从 merge base 比较；changed set 为空失败关闭；受保护路径的删除或重命名失败；D20 的授权记录消费规则；
- 受保护路径与授权目录不再写在 C# 中，改由 Diff 配置提供：`GUARD_PROTECTION_PATH` 指向的 JSON（`protectedPaths`：以 `/` 结尾为目录前缀，其余为精确路径，忽略大小写；`authorizationDirectory`）；未提供配置时不保护任何路径、不接受任何消费；
- `docs/guards/V3_ifx/templates/dotnet/GuardTests.cs.in` 与 V3 模板逐字节相同，`generated/stages/GuardTests.cs` 已重新生成。

**配置与加载**：

- `Invoke-V3.ps1`（V3 与 V3_ifx，保持相同）：新增 `-ProtectionPath`（绝对路径或相对 package），默认使用 package 的 `stages/diff/protection.json`；只在 Diff 阶段按 `contracts/protection.schema.json` 校验后设置 `GUARD_PROTECTION_PATH`，并清除继承值、运行后恢复；trusted base runner 从 base 包副本运行，因此配置来自 base；
- `contracts/protection.schema.json`（V3 与 V3_ifx）：拒绝绝对路径、`..`、通配符、未以 `/` 结尾的授权目录与未知字段；
- `docs/guards/V3_ifx/stages/diff/protection.json`：与原硬编码列表相同的 7 个受保护路径，授权目录 `docs/guards/V3_ifx/stages/diff/authorizations/`；
- `trusted-base/TrustedBase.psm1`：独立进程不继承 `GUARD_PROTECTION_PATH`；
- `stages/diff/stage.json`：`v3-pre-diff` 的 trust contract 增加 base 输入 `package:stages/diff/protection.json`；
- `shared/trusted-components.json`：`tcb.contracts` 纳入 protection schema；V3 `tests/Test-V3.ps1` 登记为 `tcb.validation.v3-package-tests`，使两份 `Test-V3.ps1` 此后都作为 base-owned 测试叠加（见 §3 Test-V3 parity）。

**NuGet 源（P3.3，D21）**：两份 `Test-V3.ps1` 不再生成 `NuGet.Offline.Config`/`NuGet.Test.Config`、不再复制 `docs/Directory.Packages.props`，通过 V3 `build/NuGet.config` restore，两份逐字节相同。

**测试（P3.4、P3.5）**：

- `Test-V3.ps1`（V3 与 V3_ifx）新增：committed 计划变更通过；空 committed diff 失败；非法保护配置失败；受保护删除失败；无配置时不保护；受保护重命名失败；经验证的授权消费通过；列出但未删除的记录失败；授权目录外的消费失败；未经验证的授权删除失败；未提交变更不接受消费；
- 不修改 workflow：V3_ifx 的 `scripts/Invoke-V3.ps1` 与 `templates/dotnet` 由 manifest 检查强制与 V3 逐字节相同，两份 `Test-V3.ps1` 本 PR 中逐字节相同，因此 `v3-cross-platform` 在 Linux 与 Windows 运行的 V3_ifx 副本即运行 V3 的 Diff 代码与测试；
- `Invoke-IFXManifestCheck.ps1`：Diff 保护配置必须存在并通过 schema；V3_ifx `templates/dotnet` 与 `scripts/Invoke-V3.ps1` 必须与 V3 逐字节相同（至 P7.5；夹具缺少对应 V3 目录时跳过，与既有模板规则一致）；`Test-IFXManifests.ps1` 新增 4 个负例，夹具复制 V3 模板与脚本；
- V3 DEPLOYMENT 说明 committed range、空 diff 与保护配置；
- `analysis/ifx/inventory.json` 与 `INVENTORY.md` 在 LF checkout（与 CI 相同）中重新生成：已提交的清单记录的是 Windows CRLF checkout 的 `.csproj` 哈希，本 PR 首次触发 `tcb.engine.v3-runner` 的候选验证，其 base-owned `Test-IFXTools.ps1` 在 Linux 上会因此失败（本地模拟发现）。

## 2. 等价性（P3.5）

- 模板：V3_ifx 模板与 V3 模板逐字节相同，并由 manifest 检查强制；
- 保护集合：`protection.json` 的 7 个条目与原 `IsProtectedGuardPath` 的精确/前缀判断逐项相同，匹配仍忽略大小写；授权目录与 D20 模板常量相同；
- 行为：Diff 由 `Invoke-V3.ps1` 从 package 加载配置，manifest 检查要求 V3_ifx 配置存在且有效，因此 IFX 的 trusted Diff 与合入前等价；V3 在未提供配置时不保护任何路径，这是通用包的正确默认，而非对 IFX 的削弱；
- 回归：`Test-IFXTrustedBase.ps1 -DiffConsumptionOnly` 的 9 个端到端用例在配置化模板下通过（其中受保护删除与重命名用例依赖 `protection.json` 的 `docs/guards/V3_ifx/` 前缀）。

## 3. 与 Plan 06 文字的差异

| Plan 06 描述 | 实际实现 | 理由 |
| --- | --- | --- |
| P3.2 保护路径参数化到 Diff 配置 | 同时参数化 D20 的授权目录 | 授权目录是 IFX 路径，通用模板中不能保留 |
| P3.5 V3_ifx 与 V3 逐字节相同 | 本 PR 只强制模板与 `Invoke-V3.ps1` 的 parity；`Test-V3.ps1` 的 parity 检查在下一个 trusted-base 变更（CP06）加入 | 候选验证把 base 版本的 base-owned 测试叠加到候选上：本 PR 中 V3_ifx `Test-V3.ps1` 被还原为 base 版本而 V3 副本（base 未登记）不被还原，同时修改两份并强制 parity 的 PR 无法通过（本地模拟发现）。本 PR 登记 V3 副本后，两份都会被叠加，CP06 即可加入该检查 |
| P3.4 Linux/Windows 测试 | 不把 V3 `Test-V3.ps1` 加入 workflow，而由 manifest 检查强制 V3_ifx 副本与 V3 逐字节相同，并由已在 `v3-cross-platform` 运行的 V3_ifx 副本覆盖 Linux/Windows | 新增 workflow 引用的脚本必须先在 base 的 TCB manifest 登记，否则 base 的 manifest 检查使本 PR 的 Validate 失败（本地模拟发现）；切换到 V3 副本随 P7.5 删除 V3_ifx 副本时进行 |

## 4. 验证

见 PR 描述与 CP05 汇报。

## 5. 回退

还原本 pair 列出的文件会再次修改 TCB 组件，需要新的 `change-trusted-base` 授权。
