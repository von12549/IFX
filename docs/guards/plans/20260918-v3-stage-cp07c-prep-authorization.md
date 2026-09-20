# CP07c-prep-auth — Architecture Conformance engine V3 目标路径与测试桥的 move 与 change-trusted-base 授权

本 pair 是 [正式 Plan pair](20260916-v3-stage-oriented-package-refactor.md) 检查点 CP07c-prep 的授权 PR，按 §12.1、§12.2、D12、D23 与 D29 为变更 PR（`20260918-v3-stage-cp07c-prep-v3-engine-paths`）加入二十二条正交授权，并记录用户于 2026-09-18 批准的 D29。本 PR 不修改 TCB 组件、不修改已登记 policy、不删除文件。

- `docs/guards/V3_ifx/stages/diff/authorizations/cp07c-prep-move-alloweddirectiontests.json`
- `docs/guards/V3_ifx/stages/diff/authorizations/cp07c-prep-move-allowedreferencetests.json`
- `docs/guards/V3_ifx/stages/diff/authorizations/cp07c-prep-move-baselinetests.json`
- `docs/guards/V3_ifx/stages/diff/authorizations/cp07c-prep-move-bootstraparchitecturetests.json`
- `docs/guards/V3_ifx/stages/diff/authorizations/cp07c-prep-move-bootstrapconfigurationtests.json`
- `docs/guards/V3_ifx/stages/diff/authorizations/cp07c-prep-move-customrulestests.json`
- `docs/guards/V3_ifx/stages/diff/authorizations/cp07c-prep-move-declarationplacementtests.json`
- `docs/guards/V3_ifx/stages/diff/authorizations/cp07c-prep-move-directreferencetests.json`
- `docs/guards/V3_ifx/stages/diff/authorizations/cp07c-prep-move-fixtures.json`
- `docs/guards/V3_ifx/stages/diff/authorizations/cp07c-prep-move-forbiddendependencytests.json`
- `docs/guards/V3_ifx/stages/diff/authorizations/cp07c-prep-move-forbiddenpackagetests.json`
- `docs/guards/V3_ifx/stages/diff/authorizations/cp07c-prep-move-implementstests.json`
- `docs/guards/V3_ifx/stages/diff/authorizations/cp07c-prep-move-importtests.json`
- `docs/guards/V3_ifx/stages/diff/authorizations/cp07c-prep-move-indirectreferencetests.json`
- `docs/guards/V3_ifx/stages/diff/authorizations/cp07c-prep-move-policybindingtests.json`
- `docs/guards/V3_ifx/stages/diff/authorizations/cp07c-prep-move-reportformattests.json`
- `docs/guards/V3_ifx/stages/diff/authorizations/cp07c-prep-move-rulebooktests.json`
- `docs/guards/V3_ifx/stages/diff/authorizations/cp07c-prep-move-scopetests.json`
- `docs/guards/V3_ifx/stages/diff/authorizations/cp07c-prep-move-severitytests.json`
- `docs/guards/V3_ifx/stages/diff/authorizations/cp07c-prep-move-stoppedreferencetests.json`
- `docs/guards/V3_ifx/stages/diff/authorizations/cp07c-prep-move-engine-fixtures.json`
- `docs/guards/V3_ifx/stages/diff/authorizations/cp07c-prep-trusted-base.json`
- `docs/guards/V3_ifx/stages/diff/authorizations/cp07c-prep-weaken-policy.json`

- 二十条 `move` 覆盖通用 engine 测试源码逐个迁往 V3 目标路径的 protected-removal（`move` 要求 source 在 head 中不存在，而旧测试项目文件作为空桥留在原地），一条 `move` 覆盖 synthetic fixture 目录整体迁移；
- `weaken-policy` 覆盖 `shared/trusted-components.json`（base-owned 归属迁往 V3 路径）；
- `change-trusted-base` 覆盖 runner、engine 与 base-owned 测试组件、package-local lock 与 package 测试的变化，parity contract 写明判定不变、composite hash 不变，新增的只是跨两个包的源码与项目集合检查；
- D29：`20260918-v3-stage-d29-architecture-conformance-v3-relocation.json`，记录 V3 stage 路径、项目与 assembly 改名而 namespace 作为内部兼容面保留、IFX 专属 fixture，以及必须先证明的 expand/contract 桥。

verifier 报告的义务即为上述各条（21 个 protected-removal、1 个 trusted-component-change 与 1 个 policy-weakening：trusted component manifest 的组件路径迁移）。变更 PR 必须同时删除全部记录。Plan 06 §17 增加 D29；plan pair 的决定索引增加 D29，检查点表增加 CP07c-prep 并标记进行中。
