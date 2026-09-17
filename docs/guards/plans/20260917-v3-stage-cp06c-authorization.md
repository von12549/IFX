# CP06c-auth — 两 PR 演练与证据的 change-trusted-base 授权

本 pair 是 [正式 Plan pair](20260916-v3-stage-oriented-package-refactor.md) 检查点 CP06c 的授权 PR，按 §11.5、§12.1 与 D23 为 CP06c 变更 PR（`20260917-v3-stage-cp06c-rehearsal-evidence`）加入 `change-trusted-base` 授权。本 PR 不修改 TCB 组件、不修改已登记 policy、不删除文件。

- `docs/guards/V3_ifx/stages/diff/authorizations/cp06c-rehearsal-evidence.json`：由 `New-IFXTrustedBaseAuthorization.ps1` 从准备好的变更 revision 生成，覆盖 manifest 检查、trusted-base 脚本与测试等 TCB 路径；
- plan pair 的检查点表把 CP06b2 标记完成，CP06c 标记进行中。

CP06c 不修改已登记 policy 或 domain authority，因此只需要 `change-trusted-base`。
