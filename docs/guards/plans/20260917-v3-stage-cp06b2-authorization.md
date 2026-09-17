# CP06b2-auth — D18 domain authority 覆盖的 change-trusted-base 与 weaken-policy 授权

本 pair 是 [正式 Plan pair](20260916-v3-stage-oriented-package-refactor.md) 检查点 CP06b2 的授权 PR，按 §11.5、§12.1、D23 与 D24 为 CP06b2 变更 PR（`20260917-v3-stage-cp06b2-domain-authority-coverage`）加入两条正交授权，并记录 D25。本 PR 不修改 TCB 组件、不修改已登记 policy、不删除文件。

- `docs/guards/V3_ifx/stages/diff/authorizations/cp06b2-domain-authority-coverage-trusted-base.json`：`change-trusted-base`，由 `New-IFXTrustedBaseAuthorization.ps1` 从准备好的变更 revision 生成，覆盖 trusted-base 脚本、测试、`stages/post/stage.json` 与 workflow 等 TCB 路径；
- `docs/guards/V3_ifx/stages/diff/authorizations/cp06b2-domain-authority-coverage-policy.json`：`weaken-policy`，覆盖 `stages/post/stage.json` 的 trust/meta 语义变化（五个 D18 gate 的 `policy` 字段）；
- D25：`20260917-v3-stage-d25-domain-authority-coverage.json`；
- Plan 06 §17 增加 D25，plan pair 的决定索引增加 D25，CP06b1 标记完成，CP06b2 标记进行中。

CP06b2 是第一个由 CP06b1 规则判定的 PR：变更 PR 必须同时消费两条授权；只消费 `change-trusted-base` 时应以未覆盖的 `policy-weakening` 失败。
