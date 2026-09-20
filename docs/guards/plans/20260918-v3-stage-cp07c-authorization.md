# CP07c-auth — 通用 engine 迁入 V3 的 move、delete、change-trusted-base 与 weaken-policy 授权

本 pair 是 [正式 Plan pair](20260916-v3-stage-oriented-package-refactor.md) 检查点 CP07c 的授权 PR，按 §12.1、§12.2、D12、D23、D24 与 D29 为变更 PR（`20260918-v3-stage-cp07c-engine-in-v3`）加入 31 条正交授权。本 PR 不修改 TCB 组件、不修改已登记 policy、不删除文件。

- 27 条 `move`：通用 engine 的每个源码文件迁往 `docs/guards/V3/stages/post/gates/architecture/dotnet/Guards.ArchitectureConformance/`；
- 2 条 `delete`：V3_ifx 的 engine 项目文件与它退役的 reviewed lock；CP07c-prep 留下的空桥测试项目本检查点保留（base 仍拥有该路径，候选验证会把 base 的 engine 测试恢复到那里运行并编译），删除推迟到 base 不再拥有该路径的后续检查点；
- 1 条 `change-trusted-base`：runner、engine 与 base-owned 测试组件、package-local lock 与 package 测试，parity contract 写明 composite hash、report 字段、12 条 policy binding、tool version、失败类别、CLI/MCP 契约与 `v3-architecture` 名称不变；
- 1 条 `weaken-policy`：`stages/post/stage.json`（P6.5 混合型 trust contract）、`contracts/stage.schema.json`（新增契约字段）、`shared/policy-config.json`（6 条 monotonicity 声明）与 `shared/trusted-components.json`（组件路径随 engine 迁移收敛）。

verifier 报告的义务即为 29 个 protected-removal、1 个 trusted-component-change 与 4 个 policy-weakening。变更 PR 必须同时删除全部记录。plan pair 的检查点表把 CP07c-prep 标记完成，CP07c 标记进行中。
