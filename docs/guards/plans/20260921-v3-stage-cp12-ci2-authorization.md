# CP12-ci2-auth — Windows portability smoke 的受保护变更授权

本 pair 为 CP12-ci2 变更候选 `3bb22a72a6fc6c7533156f44f6198fa767020aa2` 增加两条正交预授权。本授权 PR 只增加 decision、formal plan 与 authorization records，不修改 workflow、TCB 组件或已登记 policy。

- `cp12-ci2-trusted-base.json`：覆盖候选对 `tcb.activation.ci`、`tcb.manifest` 与 `tcb.validation.package-tests` 的 5 个精确路径变化；允许的证据变化仅为普通 Windows head candidate 从 full 改为已声明 smoke，Ubuntu 保持 full，P11.4 通过 dispatch 补一次 Windows full。
- `cp12-ci2-weaken-policy.json`：精确覆盖 `ci/jobs.json` 与 `shared/trusted-components.json` 的语义指针变化。
- D35 局部取代 D28 对 Windows 裁剪的否决；D28 的其余成本控制与失败关闭约束保持有效。

两条记录都绑定 base `22fb907822b103a0ce184f7081eac90db096f394` 与候选 commit；候选 rebase 到本授权合入后的 base 后将消费并删除记录。
