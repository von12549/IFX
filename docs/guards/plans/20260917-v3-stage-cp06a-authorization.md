# CP06a-auth — P4 保护义务与路径操作授权的 change-trusted-base 授权

本 pair 是 [正式 Plan pair](20260916-v3-stage-oriented-package-refactor.md) 检查点 CP06a 的授权 PR，按 §11.5、§12.1 与 D20 为 CP06a 变更 PR（`20260917-v3-stage-cp06a-protected-change-obligations`）加入 `change-trusted-base` 授权，并记录用户于 2026-09-17 批准的 D22 与 D23。本 PR 不修改 TCB 组件、不删除文件。

- `docs/guards/V3_ifx/stages/diff/authorizations/cp06a-protected-change-obligations.json`：由 `New-IFXTrustedBaseAuthorization.ps1` 从准备好的变更 revision 生成，列出变更涉及的全部 TCB 路径、base/head tuple 与 base validation suite；
- D22：`20260917-v3-stage-d22-revocation-only-authorization-deletion.json`，未消费授权只能在 revocation-only PR 中撤销；
- D23：`20260917-v3-stage-d23-protected-change-obligations.json`，P4 拆分为 CP06a–CP06d、P4.4 延后，按保护义务唯一覆盖，未启用的 operation 与 `.gitattributes` 失败关闭，允许集合报告绑定 base、merge-base、head 与配置 hash；
- Plan 06 §17 增加 D22、D23，P3 标记完成；plan pair 的检查点表拆分 CP06，CP05 标记完成，CP06a 标记进行中。

变更 PR 合入前须以 base 已包含本授权为前提（ruleset `strict`）；其 TCB 路径的对象 ID 必须与授权记录一致。变更 PR 仍由本 base（CP05）判定：`v3-pre-diff` 应报告 `consumed-authorization` 通过，候选验证在 base-owned validation（含 CP05 的 `Test-V3.ps1`）与 parity 下通过。
