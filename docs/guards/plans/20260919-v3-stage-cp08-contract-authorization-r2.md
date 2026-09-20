# CP08-auth-r2 — 显式 Diff protection binding 后的 Stage Gate contract 授权

首次本地 authorization 模拟正确通过“authorization PR 无受保护变更”，但 base-owned Diff 随后发现 canonical V3 未收到 IFX overlay 的 `stages/diff/protection.json`，因而拒绝消费已绑定的 protected-change report。该记录未发布；显式 `-ProtectionPath`、base-owned 测试桥、profile-candidate 隔离与 `RepositoryIgnore` 映射已前移到修订并验证过的 prep `32fcf3a7`，candidate `2448cec0` 据此重新生成本 r2。

本 pair 包含十条正交授权：一条 `change-trusted-base`、一条 `weaken-policy`、七条 `delete` 与一条 reviewed lock `move`。它自身只增加授权记录、formal Plan 和检查点台账，不改变 trusted component、registered policy、workflow 或运行时代码。后续 CP08 change 必须删除并消费全部十条记录。
