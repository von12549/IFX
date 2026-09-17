# CP06b1-auth — policy/config 注册表与 `weaken-policy` 的 change-trusted-base 授权

本 pair 是 [正式 Plan pair](20260916-v3-stage-oriented-package-refactor.md) 检查点 CP06b1 的授权 PR，按 §11.5、§12.1 与 D23 为 CP06b1 变更 PR（`20260917-v3-stage-cp06b1-policy-config-dual-track`）加入 `change-trusted-base` 授权，并记录用户于 2026-09-17 批准的 D24。本 PR 不修改 TCB 组件、不删除文件。

- `docs/guards/V3_ifx/stages/diff/authorizations/cp06b1-policy-config-dual-track.json`：由 `New-IFXTrustedBaseAuthorization.ps1` 从准备好的变更 revision 生成，列出变更涉及的全部 TCB 路径、base/head tuple 与 base validation suite；
- D24：`20260917-v3-stage-d24-policy-config-dual-track.json`，CP06b 拆为 CP06b1 与 CP06b2，policy/config 角色分类与明确文件集合，零比较器下 trust/meta 变化同时需要 `change-trusted-base` 与 `weaken-policy`，head 候选只由 base engine 从明确 head commit 验证，CP06b1 activation exception，b2 合入前 D18 blocking findings 继续失败关闭；
- Plan 06 §17 增加 D24；plan pair 的检查点表把 CP06b 拆为 CP06b1、CP06b2，CP06a 标记完成，CP06b1 标记进行中。

CP06b1 首次引入 policy/config 义务：变更 PR 仍由本 base（CP06a）判定，只消费本授权（`protected-changes` 报告消费 `change-trusted-base`），不需要 `weaken-policy`；下一个修改已登记 policy 的 PR 必须同时提供 `weaken-policy`，以验证新规则生效。
