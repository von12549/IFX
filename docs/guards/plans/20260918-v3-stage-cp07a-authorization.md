# CP07a-auth — LayerGuard generated 副本删除的 delete、change-trusted-base 与 weaken-policy 授权

本 pair 是 [正式 Plan pair](20260916-v3-stage-oriented-package-refactor.md) 检查点 CP07a 的授权 PR，按 §12.1、§12.2、D12、D23、D24 与 D26 为 CP07a 变更 PR（`20260918-v3-stage-cp07a-single-source-layerguard`）加入三条正交授权。本 PR 不修改 TCB 组件、不修改已登记 policy、不删除文件。

- `docs/guards/V3_ifx/stages/diff/authorizations/cp07a-delete-generated-layerguard.json`
- `docs/guards/V3_ifx/stages/diff/authorizations/cp07a-trusted-base.json`
- `docs/guards/V3_ifx/stages/diff/authorizations/cp07a-weaken-policy.json`

- `delete` 覆盖 `generated/dotnet/LayerGuard` 目录的 protected-removal（174 个路径），记录 source 的 base tree entry；
- `change-trusted-base` 覆盖 `tcb.engine.architecture-runner`、`tcb.generated.architecture-conformance`、`tcb.manifest` 与 `tcb.validation.package-tests` 的变化；
- `weaken-policy` 覆盖 `guard-system.json`、`shared/commands.json` 与 `shared/trusted-components.json` 的语义变化（trust/meta 与 editable policy）。

三条记录由 `New-IFXTrustedBaseAuthorization.ps1` 从准备好的变更 revision 生成。变更 PR 必须同时删除三条记录；只消费其中两条时应失败。plan pair 的检查点表把 CP07a-prep 标记完成，CP07a 标记进行中。
