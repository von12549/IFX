# CP07b-prep 撤销 — 过期的 change-trusted-base 授权记录（D22）

本 pair 是 [正式 Plan pair](20260916-v3-stage-oriented-package-refactor.md) 检查点 CP07b-prep 的 D22 revocation-only PR，只删除 base 中 schema-valid 的授权记录 `docs/guards/V3_ifx/stages/diff/authorizations/cp07b-prep-trusted-base.json` 并加入本 plan pair，不含任何其他变更。

## 1. 原因

`#62` 加入的 `cp07b-prep-trusted-base` 精确绑定了变更 PR `#63` 当时的 head blob。`#63` 的 CI 在 Linux 上失败：`Test-IFXPackage.ps1` 的新负向用例确实让 Check 失败，但比较输出时没有去掉 PowerShell 在较窄控制台上为错误记录加入的换行、`|` 边栏与颜色转义，导致文本匹配失败。修正该测试会改变 `tcb.validation.package-tests` 的 head blob，原记录再也无法被消费。授权记录不可修改（§12.1），因此先按 D22 单独撤销，再由新的授权 PR 加入绑定修正后内容的记录。

## 2. 变更

- 删除 `docs/guards/V3_ifx/stages/diff/authorizations/cp07b-prep-trusted-base.json`；
- 加入本 plan pair。

`docs/guards/V3_ifx/stages/diff/authorizations/cp07b-prep-move-binding-tests.json` 仍与 `#63` 的移动一致，保留在 base 中，由修正后的变更 PR 消费。

## 3. 验证方式

`v3-pre-diff` 报告 revocation：1 条授权被撤销、无保护义务、无其他变更；其余 required check 通过。
