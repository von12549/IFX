# CP09 — Plan 06 P8 commands、只读文档与 Analysis 生命周期

本检查点完成 P8：稳定公共入口收敛到 `commands/`；旧公共路径只保留弃用 wrapper。Markdown 不再是配置写入口，`Invoke-V3Docs` 只支持 Render/Check。

## 1. 文档契约

- `docs/docs-map.json` 由 schema 管理，声明输出、renderer、来源路径或 glob 与 source role。
- 首批聚合文档为 `OVERVIEW.md`、`COMMANDS.md`、`POST.md`、`CI.md`。
- 聚合文档与保留的 `profiles/ifx/views/` 均为只读生成物，头部列出实际来源、角色和单一 composite SHA-256。
- Check 重新渲染完整文件集并逐字节比较；authority 变化、手工编辑、缺失或额外文件均失败。

## 2. Analysis 生命周期

- Analyze/Review 的 inventory、proposal、review-profile 和 review report 只写 `artifacts/guards/<package>/analysis/`。
- 经评审的 `ARCHITECTURE.md`、`TECHNICAL.md` 与删除清单位于 `stages/analysis/evidence/`。
- 冻结的 cutover/parity 报告位于 `stages/analysis/reports/`。
- 长期输入和快照只通过 `maintenance/Update-IFXAnalysisEvidence.ps1` 的 Preview/Apply 更新；Apply 需要显式接受开关。
- 原 `analysis/ifx/` 运行输出和 review-profile 从 Git 删除；refactor baseline/history 保持不动。

## 3. 公共入口与兼容

- Canonical V3 runner、setup、docs 与 IFX dispatcher 位于 `commands/`。
- 原 `scripts/` 公共路径输出一次 deprecation 消息并原样转发参数和退出码。
- workflow、hooks、tests、trusted-base runner、manifest 与 command manifest 使用 canonical `commands/` 路径。

## 4. 授权与验证

受保护的 authored/analysis 移动、runtime 输出删除、TCB 变化和配置语义变化使用 base 预授权并在 change 中一次性消费。验收覆盖 manifest 正反例、Docs source/output drift、Import 拒绝、Analysis 不改 reviewed evidence、V3/IFX tools、package/TCB parity、Validate 与 trusted Diff。

