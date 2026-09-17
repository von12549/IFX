# CP05a 事后复验（正例 2/2）：消费授权的变更 PR

修改 `trusted-base/Invoke-IFXTrustedBase.ps1` 头部注释，说明 Diff mode 先以 authorization-only 模式核对被消费的授权（D20），并删除被消费的 `docs/guards/V3_ifx/stages/diff/authorizations/cp05a-verify-runner-documentation.json`。预期 13 个 required check 全部通过，`v3-pre-diff` 的 trusted-base summary 中 `consumed-authorization` 为 pass；无需任何 ruleset 变更。
