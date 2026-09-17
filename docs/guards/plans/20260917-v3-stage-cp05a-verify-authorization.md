# CP05a 事后复验（正例 1/2）：授权 PR

按 `20260917-v3-stage-cp05a-authorization.md` §4 runbook 第 13 步，break-glass 恢复后以常规两 PR 流程验证 D20。本 PR 只加入 `docs/guards/V3_ifx/stages/diff/authorizations/cp05a-verify-runner-documentation.json`，授权下一 PR 对 `trusted-base/Invoke-IFXTrustedBase.ps1` 头部注释的修改（说明 Diff mode 的授权消费步骤）；不修改 TCB 组件、不删除文件。
