# CP07-ci-auth — CI 成本控制与变更范围判定的 change-trusted-base 与 weaken-policy 授权

本 pair 是 [正式 Plan pair](20260916-v3-stage-oriented-package-refactor.md) 检查点 CP07-ci 的授权 PR，按 §12.1、§12.2、D23、D24 与 D28 为变更 PR（`20260918-v3-stage-cp07ci-cost-controls`）加入两条正交授权，并记录用户于 2026-09-18 批准的 D28。本 PR 不修改 TCB 组件、不修改已登记 policy、不删除文件。

- `docs/guards/V3_ifx/stages/diff/authorizations/cp07ci-trusted-base.json`
- `docs/guards/V3_ifx/stages/diff/authorizations/cp07ci-weaken-policy.json`

- `change-trusted-base` 覆盖 `tcb.activation.ci`、`tcb.engine.trusted-base` 与 `tcb.validation.package-tests` 的变化，parity contract 写明唯一允许的判定差异：base 判定变更集只含 formal plan、authorization record 与 decision record 时，`v3-architecture`、三个 quality 与 `v3-specialized-database` 继承 base 判定；
- `weaken-policy` 覆盖 `ci/jobs.json` 与新增 `contracts/change-scope.schema.json`；
- D28：`20260918-v3-stage-d28-ci-cost-controls-and-change-scope.json`，记录度量结果（单次 PR 运行 73–75 计费分钟）、成本控制（concurrency 取消、package cache、月度 schedule）与 base 判定的变更范围，并写明 13 个 required check 名称、job DAG、trigger 语义与 ruleset 不变。

Plan 06 §17 增加 D28；plan pair 的决定索引增加 D28，检查点表增加 CP07-ci 并标记进行中。
