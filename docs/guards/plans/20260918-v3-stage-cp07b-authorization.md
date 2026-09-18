# CP07b-auth — 通用 engine 与 IFX policy binding 分离的 delete 与 change-trusted-base 授权

本 pair 是 [正式 Plan pair](20260916-v3-stage-oriented-package-refactor.md) 检查点 CP07b 的授权 PR，按 §12.1、§12.2、D12、D23 与 D27 为变更 PR（`20260918-v3-stage-cp07b-engine-binding-separation`）加入两条正交授权。本 PR 不修改 TCB 组件、不修改已登记 policy、不删除文件。

- `docs/guards/V3_ifx/stages/diff/authorizations/cp07b-delete-gate-policy-bindings.json`
- `docs/guards/V3_ifx/stages/diff/authorizations/cp07b-trusted-base.json`

- `delete` 覆盖 `docs/guards/V3_ifx/templates/ifx-layerguard/src/LayerGuard/GatePolicyBindings.cs` 的 protected-removal：IFX 的 G03/G04/G05 规则离开通用 engine，通用部分进入新的 `PolicyBinding.cs`，IFX 部分进入 `src/LayerGuard.Ifx/IfxGatePolicyBinding.cs`；
- `change-trusted-base` 覆盖 `tcb.build.package-local`、`tcb.engine.architecture-conformance`、`tcb.engine.architecture-runner`、`tcb.validation.architecture-conformance` 与 `tcb.validation.package-tests`，parity contract 写明 policy composite hash、report 字段、12 条 policy binding、tool version 与 CLI/MCP 契约不变，唯一新增行为是没有注册 binding 的 engine 对绑定段失败关闭。

verifier 报告的义务即为上述两条（无 policy-weakening：policy 文件逐字节不变）。变更 PR 必须同时删除两条记录；只消费其中一条时应失败。plan pair 的检查点表把 CP07b-prep 与 CP07-ci 标记完成，CP07b 标记进行中。
