# PR 25 CI 修复

基线：`1677e18`，分支 `codex/plan05-iam-platform-security`。原始失败记录保留在 GitHub Actions：

| 工作流 | 原始运行 | 原因 |
| --- | --- | --- |
| LayerGuard | [34699884679](https://github.com/von12549/IFX/actions/runs/34699884679) | 独立工具 solution 未 restore；干净 runner 缺少 assets 文件 |
| Contract Event Governance | [34699884708](https://github.com/von12549/IFX/actions/runs/34699884708) | 后续 LayerGuard 步骤使用同一个未 restore 的入口 |
| G04 Deployment Runtime | [34699884668](https://github.com/von12549/IFX/actions/runs/34699884668) | 发布清单的文件摘要过期，且受平台换行影响 |
| G05 Context and Sensitive Data Boundary | [34699884673](https://github.com/von12549/IFX/actions/runs/34699884673) | 数据库 inventory 使用 `-NoBuild` 时 solution 尚未构建 |
| Plan 04 governance | [34699884676](https://github.com/von12549/IFX/actions/runs/34699884676) | 哈希绑定记录了 Windows CRLF 字节；Linux checkout 为 LF；solution 中的反斜杠路径还会导致项目名解析失败 |

## 改动

- LayerGuard 入口显式 restore 自己的 solution；G05 在数据库检查之前完成构建。
- 对哈希绑定的输入限定 UTF-8/LF checkout，并让相关清单、图和 inventory 生成器输出 LF。原始 SHA-256 检查继续严格比较文件字节。
- 刷新当前治理锁、派生 inventory/handoff 和 G04 runtime manifest。历史证据保持原提交字节，原摘要和先前 refresh 记录保留；新增 authority refresh 解释 LF 摘要。逐文件说明见 [哈希刷新证据](ci-cross-platform-hash-refresh.json)。
- 重新运行无 baseline 的架构检查确认 49 个项目零违规后，刷新空 Plan 05 baseline 的 ruleset hash；没有新增豁免。
- 在遗留 Abstractions 检查中统一 Windows/Linux 路径分隔符，新增 Windows 路径正例和遗留引用反例。
- 后续完整验证发现 G05 仍要求旧版的 15 个 catalog mutation 用例，而当前已有 18 个。基线明确绑定全部 18 个名称，包括三个 credential 反例；数量、名称或结果不匹配均失败。同步更新 Plan 05 状态和目标环境验证边界校验。

## 提交前验证

| 验证 | 结果 |
| --- | --- |
| Windows `Invoke-G05Verification.ps1` 完整入口 | passed；1,228/1,228 .NET 测试，190/190 LayerGuard 测试，18/18 catalog mutation 用例 |
| Windows Plan 04 统一治理和文档检查 | passed |
| Linux 独立干净 checkout：Plan 04 统一治理 | passed；含 6 个路径/遗留引用 fixtures |
| Linux LayerGuard 独立 solution restore、测试和严格检查 | passed；190/190，49 项目零违规，空 baseline |
| Plan 00、03-A1、历史 B4、G04 orchestration/failure matrix、Plan 02 C1 | passed |
| Catalog mutation 聚合的缺失/替换名称检查 | 均拒绝 |

本地日志和机器报告位于忽略目录 `artifacts/plan05/ci-fix/`，包括原始 CI 失败日志。此记录只声明以上已完成的本地验证；推送后的完整远程验证以 PR 25 最新提交的 Actions 结果为准。真实 IdP、目标数据、生产遥测和人工批准仍属于外部验收范围。
