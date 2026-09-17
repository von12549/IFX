# P2.8 负向控制 A：未授权 TCB 变更（不合入）

本 PR 只在 `history/Invoke-IFXHistoricalIntegrity.ps1` 中加入一行注释，不提供 `change-trusted-base` 授权。预期 `v3-cross-platform-ubuntu-latest` 的 `Verify trusted component candidates` 失败；验证后关闭本 PR，不合入（Plan 06 P2.8，D19）。
