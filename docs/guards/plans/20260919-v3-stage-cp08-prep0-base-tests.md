# CP08-prep0 — base-owned Stage Gate transition test bridge

本检查点是 Plan 06 P7 的最小 expand bridge。它只修正两份 base-owned 测试，使下一检查点可以把 legacy V3 runner 改为薄 wrapper，并把工具验证切到 canonical V3，而不会被旧 base overlay 恢复出互相矛盾的断言。

- `Test-IFXManifests.ps1` 的 workflow 负向控制改用真正不存在的 `Invoke-Untrusted.ps1`，因此未来把现有 legacy 文件纳入 transition TCB 不会削弱“新增可执行入口必须显式登记”的保护；runner byte-parity 断言移除，因为其下一状态是受 manifest/TCB 约束的薄 wrapper。template 与 synthetic test parity 断言仍保留。
- `Test-IFXTools.ps1` 在仓库 artifacts 下创建唯一临时 analysis root，复制可编辑 drafts，调用 canonical V3 tools，连续 Analyze 两次并比较输出；它不再把平台相关 checkout bytes 当作生成器规范，也不改写 tracked analysis snapshot。
- 除消费 exact-candidate authorization 记录外，本检查点不改变 runner、manifest checker、policy、workflow 或 required checks；下一检查点才切换 canonical references。
