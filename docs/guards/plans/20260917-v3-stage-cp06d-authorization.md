# CP06d-auth — D17 Plan04 阶段校验脚本删除的 delete 与 change-trusted-base 授权

本 pair 是 [正式 Plan pair](20260916-v3-stage-oriented-package-refactor.md) 检查点 CP06d 的授权 PR，按 §12.1、§12.2、D17 与 D23 为 CP06d 变更 PR（`20260917-v3-stage-cp06d-d17-validator-retirement`）加入五条正交授权。本 PR 不修改 TCB 组件、不修改已登记 policy、不删除文件。

- `docs/guards/V3_ifx/stages/diff/authorizations/cp06d-delete-test-plan04documentation.json`
- `docs/guards/V3_ifx/stages/diff/authorizations/cp06d-delete-test-plan04phase0baseline.json`
- `docs/guards/V3_ifx/stages/diff/authorizations/cp06d-delete-test-plan04phase1inventory.json`
- `docs/guards/V3_ifx/stages/diff/authorizations/cp06d-delete-test-plan04phase2audit.json`
- `docs/guards/V3_ifx/stages/diff/authorizations/cp06d-d17-trusted-base.json`

四条 `delete` 各覆盖一个受保护路径删除义务，`change-trusted-base` 覆盖 `tcb.engine.specialized` 的变化；它们由 `New-IFXTrustedBaseAuthorization.ps1` 从准备好的删除 revision 生成。变更 PR 必须同时删除五条记录；只消费其中一类时应失败。plan pair 的检查点表把 CP06c 标记完成，CP06d 标记进行中。
