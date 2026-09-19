# CP08-prep0-auth — base-owned Stage Gate transition test bridge 授权

本 pair 是 Plan 06 P7 的测试桥授权。它为精确候选 `4ce9e5f7` 加入一条 `change-trusted-base` 记录，覆盖 `tcb.validation.package-tests` 的两份 base-owned 测试；授权本身不修改 TCB、policy、workflow 或产品代码，也不删除文件。

- `docs/guards/V3_ifx/stages/diff/authorizations/cp08-prep0-trusted-base.json`

parity contract 限定变化只在测试契约：manifest suite 继续保留 missing executable、template 与 synthetic-test 负向控制，但不再要求下一状态的 public runner 与 canonical implementation byte-identical；tools suite 在隔离目录连续运行 canonical Analyze，比较两次输出并保持 authored/tracked snapshots 不变。13 个 required checks、产品脚本、manifest、policy、workflow 与报告 schema 均保持不变。

D30 记录必须先让这两份测试成为 base，随后才能执行 canonical V3/薄 wrapper 的主 prep。变更提交必须消费本记录。
