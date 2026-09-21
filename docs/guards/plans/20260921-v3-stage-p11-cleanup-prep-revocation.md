# P11.5 cleanup-prep 撤销 — 过期的 change-trusted-base 授权（D22）

本 pair 是 [Plan 06](06-v3-stage-oriented-package-refactor.md) P11.5 cleanup-prep 的 D22 revocation-only PR。它只删除 base 中 schema-valid 的 `p11-cleanup-prep-trusted-base` 授权记录并加入本 plan pair，不含其他变更。

## 原因

PR #88 的首轮真实 CI 证明，候选 CI verifier 必须在过渡期同时拒绝旧 `scripts/Invoke-IFXGuardrails.ps1` 和新的 `commands/Invoke-IFXGuardrails.ps1` head 原地执行；否则 base-owned `Test-IFXCiContract.ps1` 的 legacy 负向夹具会错误通过。修正只改变 `docs/guards/V3_ifx/commands/Invoke-IFXCiContract.ps1`，但也改变了 `tcb.activation.ci` 的精确 head blob，因此现有授权不可消费。

授权记录不可修改。按 D22，先单独撤销旧记录，再由后续授权 PR 从修正后的候选 revision 生成新记录。一次性兼容桥按明确授权绑定现有 ID，因此重新签发保留 `p11-cleanup-prep-trusted-base` ID；记录内容、base/head tuple 和引入它的授权提交均为新的单次授权实例。

## 变更与验证

- 删除 `docs/guards/V3_ifx/stages/diff/authorizations/p11-cleanup-prep-trusted-base.json`；
- 加入本 plan pair；
- `v3-pre-diff` 必须报告恰好一条 revocation、无保护义务；全部 13 个 required checks 必须通过。

`p11-cleanup-prep-policy` 保持不变，由修正后的 PR #88 消费。
