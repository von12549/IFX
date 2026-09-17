# CP07b-prep-auth — IFX facade 与 IFX policy binding 测试迁移的 move 与 change-trusted-base 授权

本 pair 是 [正式 Plan pair](20260916-v3-stage-oriented-package-refactor.md) 检查点 CP07b-prep 的授权 PR，按 §12.1、§12.2、D12、D23 与 D27 为变更 PR（`20260918-v3-stage-cp07b-prep-ifx-facade`）加入两条正交授权，并记录用户于 2026-09-18 批准的 D27。本 PR 不修改 TCB 组件、不修改已登记 policy、不删除文件。

- `docs/guards/V3_ifx/stages/diff/authorizations/cp07b-prep-move-binding-tests.json`
- `docs/guards/V3_ifx/stages/diff/authorizations/cp07b-prep-trusted-base.json`

- `move` 覆盖 `tests/LayerGuard.Tests/GatePolicyBindingTests.cs` → `tests/LayerGuard.Ifx.Tests/GatePolicyBindingTests.cs` 的 protected-removal，记录 source 的 base tree entry 与 destination 的 head tree entry；
- `change-trusted-base` 覆盖 `tcb.build.package-local`、`tcb.engine.architecture-conformance`、`tcb.engine.architecture-runner`、`tcb.validation.architecture-conformance` 与 `tcb.validation.package-tests` 的变化；
- D27：`20260918-v3-stage-d27-architecture-conformance-binding-separation.json`，P6.2–P6.3 以 CP07b-prep、CP07b 交付且不使用 activation exception；IFX 常量作为受 TCB 管控的 IFX binding 代码迁移（所有权迁移，不是 policy 外部化），policy 文件与 composite hash 输入逐字节不变；engine 提供 binding 扩展点，IFX binding 与 host 注册 binding；CP07b-prep 先建立显式引用的 IFX facade 并迁移 IFX binding 测试，不使用通配符 project reference。

授权记录由 `New-IFXTrustedBaseAuthorization.ps1` 从准备好的变更 revision 生成，义务集合以 verifier 实际报告为准（本 prep 无 policy-weakening 义务）。变更 PR 必须同时删除两条记录；只消费其中一条时应失败。Plan 06 §17 增加 D27；plan pair 的决定索引增加 D27，检查点表增加 CP07b-prep，CP07a 标记完成，CP07b-prep 标记进行中。
