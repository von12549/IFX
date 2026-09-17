# CP07a-prep-auth — Architecture Conformance 绑定测试 package root 解析的 change-trusted-base 授权

本 pair 是 [正式 Plan pair](20260916-v3-stage-oriented-package-refactor.md) 检查点 CP07a-prep 的授权 PR，按 §11.5、§12.1 与 D23 为变更 PR（`20260917-v3-stage-cp07a-prep-binding-root`）加入 `change-trusted-base` 授权，并记录用户于 2026-09-17 批准的 D26。本 PR 不修改 TCB 组件、不修改已登记 policy、不删除文件。

- `docs/guards/V3_ifx/stages/diff/authorizations/cp07a-prep-binding-root.json`：由 `New-IFXTrustedBaseAuthorization.ps1` 从准备好的变更 revision 生成，覆盖两份 `GatePolicyBindingTests.cs`、`Invoke-IFX.ps1` 与 `TrustedBase.psm1`；
- D26：`20260917-v3-stage-d26-architecture-conformance-split.json`，P6 拆分为 CP07a-prep、CP07a、CP07b、CP07c，过渡期保留 Generate/Check（Generate 只读、Check 做实质检查、P6.4 前不输出 DEPRECATED），`mcp/LayerGuard` 不在 P6 范围；
- Plan 06 §17 增加 D26；plan pair 的决定索引增加 D26，检查点表把 CP07 拆为 CP07a-prep、CP07a、CP07b、CP07c，CP06d 标记完成，CP07a-prep 标记进行中。
