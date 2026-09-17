# CP05-auth — P3 Diff 加固的 change-trusted-base 授权

本 pair 是 [正式 Plan pair](20260916-v3-stage-oriented-package-refactor.md) 检查点 CP05 的授权 PR，按 §11.5、§12.1 与 D20 为 CP05 变更 PR（`20260917-v3-stage-cp05-p3-diff-hardening`）加入 `change-trusted-base` 授权，并记录 D21（`Test-V3.ps1` 的 NuGet 源统一）。本 PR 不修改 TCB 组件、不删除文件。

- `docs/guards/V3_ifx/stages/diff/authorizations/cp05-p3-diff-hardening.json`：由 `New-IFXTrustedBaseAuthorization.ps1` 从准备好的变更 revision 生成，列出变更涉及的全部 TCB 路径、base/head tuple 与 base validation suite；
- D21：`20260917-v3-stage-d21-test-v3-nuget-source.json`；
- plan pair：CP05 标记为进行中，D21 进入决定索引。

变更 PR 合入前须以 base 已包含本授权为前提（ruleset `strict`），其 7 个以上 TCB 路径的对象 ID 必须与授权记录一致；`v3-pre-diff` 应报告 `consumed-authorization` 通过，无需 break-glass。
