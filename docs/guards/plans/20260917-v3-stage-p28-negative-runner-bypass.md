# P2.8 负向控制 B：required check 绕过 trusted base runner（不合入）

本 PR 把 `v3-historical-integrity` 改为从 checkout 原位运行 head dispatcher。预期 base CI 契约在 `v3-architecture` 与两个 `v3-cross-platform` 的 Validate 中失败（`trusted-base-runner`、`trusted-base-no-head-dispatcher`）；验证后关闭本 PR，不合入（Plan 06 P2.8，D19）。
