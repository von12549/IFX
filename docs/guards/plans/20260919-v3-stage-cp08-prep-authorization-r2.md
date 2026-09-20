# CP08-prep-auth-r2 — verified prep0 base 上的 canonical V3 授权

本 pair 在已通过验证的 CP08-prep0 change `b4eecb73` 上，为精确候选 `2513ac9f` 生成两条正交授权。旧的本地模拟记录基于 prep0 之前的 base，未发布且已被本 r2 取代。

- `docs/guards/V3_ifx/stages/diff/authorizations/cp08-prep-trusted-base.json`
- `docs/guards/V3_ifx/stages/diff/authorizations/cp08-prep-weaken-policy.json`

`change-trusted-base` 覆盖六个组件的 17 个实际变化路径：canonical V3 runner ownership、兼容旧/新 Stage Gate 的 base-owned 测试桥、workflow-facing legacy runner、IFX orchestrator、trusted-base 执行链、manifest verifier 与剩余 package-test 变化。parity contract 要求 legacy runner 的参数/退出码、13 个 required checks、判定、policy binding、Stage Gate 内容和 tracked snapshot 保持不变。

`weaken-policy` 覆盖 `guard-system.json`、`profiles/ifx/project-map.json`、`shared/commands.json` 与 `shared/trusted-components.json` 的精确语义变化。变更提交必须同时消费两条记录。
