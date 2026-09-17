# CP07b-prep-auth-r2 — 修正后 CP07b-prep 变更的 change-trusted-base 授权

本 pair 是 [正式 Plan pair](20260916-v3-stage-oriented-package-refactor.md) 检查点 CP07b-prep 的第二个授权 PR，按 §12.1、D23 与 D27 为修正后的变更 PR（`20260918-v3-stage-cp07b-prep-ifx-facade`）加入 `change-trusted-base` 授权。本 PR 不修改 TCB 组件、不修改已登记 policy、不删除文件。

- `docs/guards/V3_ifx/stages/diff/authorizations/cp07b-prep-trusted-base-r2.json`：由 `New-IFXTrustedBaseAuthorization.ps1` 从修正后的变更 revision 生成，覆盖 `tcb.build.package-local`、`tcb.engine.architecture-conformance`、`tcb.engine.architecture-runner`、`tcb.validation.architecture-conformance` 与 `tcb.validation.package-tests`；与被 `20260918-v3-stage-cp07b-prep-revocation` 撤销的记录相比，只有 `Test-IFXPackage.ps1` 的 head tuple 不同。

修正内容：`Test-IFXPackage.ps1` 在比较 Check 负向用例输出前去掉颜色转义、`|` 边栏与换行，使 Linux 与 Windows runner 的错误记录换行方式不影响匹配。变更 PR 同时消费本记录与 base 中的 `docs/guards/V3_ifx/stages/diff/authorizations/cp07b-prep-move-binding-tests.json`。
