# CP06a — Plan 06 P4（一）：完整授权 schema、Git 对象验证与路径操作授权

本 pair 是 [正式 Plan pair](20260916-v3-stage-oriented-package-refactor.md) 检查点 CP06a 的变更 PR，实施 [Plan 06](06-v3-stage-oriented-package-refactor.md) §14 的 P4.1、P4.2 与 P4.5 中路径操作部分，依据 D22（revocation-only 撤销）与 D23（保护义务模型）。它消费 `20260917-v3-stage-cp06a-authorization` 加入的 `change-trusted-base` 授权。

## 1. 变更

**授权格式（P4.1）**：`contracts/authorization.schema.json` 覆盖 §12.2 全部五种 operation，按 operation 约束字段：

- `change-trusted-base` 与 P2 的 format 1 记录完全兼容；
- `delete`、`move`、`case-rename` 记录 `source`（base tree entry，目录为 tree）、`destination`（base 前置状态与预期 head tree entry）、`changedPaths` 与逐路径 `entries`；
- `weaken-policy` 记录 authority 前后 hash、schema、字段 pointer 与 head tuple。它在 schema 中合法，但本阶段 verifier 不启用，消费即失败关闭。

**保护义务 verifier（P4.2，D23）**：新增 `trusted-base/Test-IFXProtectedChanges.ps1`，从 base worktree 针对 committed head 运行：

- 以已验证 merge-base 与 head SHA，用 `git diff --raw -z --no-renames` 读取 changed set；
- 由变更派生义务：每个受保护路径的删除（含重命名的源），以及任何 TCB 组件变化（一个义务）；同一路径可以同时承担多个正交义务；
- 候选授权为 head 删除的、base 中 schema-valid 的记录；每个义务必须恰好被一个候选覆盖，每个候选必须至少覆盖一个义务，未覆盖、重复覆盖和未使用均失败；
- `change-trusted-base` 复用候选 verifier 的记录校验（组件集合、路径、tuple、validation suite、引用）；路径操作校验 source/destination tree entry、head 中 source 不存在、source/destination 下的 changed path 与 `entries` 逐项一致；`delete` 不能覆盖仅大小写不同的重命名，`move` 不能是仅大小写变化；
- 始终失败：受保护范围内的 gitlink、任何 `.gitattributes` 变更（CP06b 以 `weaken-policy` 开通）、修改授权记录、新增 schema 无效或文件名与 id 不一致的记录；
- revocation-only PR（D22）：只普通删除 base 中 schema-valid 记录并写入本次 plan pair 时，记录被撤销；混入任何其他变更时，删除的记录都作为消费候选；
- 报告 `contracts/protected-change-report.schema.json` 绑定 base、merge-base、head 与 base `stages/diff/protection.json` 的 SHA-256。

**Trusted runner**：Diff 模式对 committed head 运行 verifier，报告保存在 head 与 base 之外，副本 `trusted-base/protected-changes-diff.json` 作为证据；summary 检查项由 `consumed-authorization` 改为 `protected-changes`；只有通过的报告以 `GUARD_PROTECTED_CHANGES` 传给 Diff 阶段；独立进程不继承该变量。未提交的 Diff 不运行 verifier，也不接受任何授权。候选 verifier 移除 `-AuthorizationOnly`，与 verifier 共用 `Test-GuardTrustedBaseRecord`。

**通用 Diff（V3 与 V3_ifx 模板逐字节相同）**：

- changed set 改为 `--raw -z --no-renames`，重命名即删除加新增；受保护路径出现 gitlink 失败；
- 只有 status 为 `pass`、且 `check`、`baseSha`、`mergeBase`、`headSha`、`protectionSha256` 全部与本次 Diff 一致的报告才生效，精确豁免 `allowedDeletions`，任一列出路径未被删除时失败；报告不匹配时失败而不是忽略；
- 旧的 `GUARD_CONSUMED_AUTHORIZATIONS` 暂时保留兼容（见 §3）。

**Schema 校验**：`TrustedBase.psm1` 新增 `Test-GuardJsonSchema`。实测 `Test-Json` 在 schema 无法解析时报告错误却仍返回 `True`，因此 verifier、候选 verifier 与授权生成器一律以错误即无效处理。

**生成器**：`New-IFXTrustedBaseAuthorization.ps1` 增加 `-Operation delete|move|case-rename`、`-SourcePath`、`-DestinationPath`。

**文档**：`stages/diff/authorizations/README.md`、`docs/authored/trusted-base.md`、V3 `DEPLOYMENT.md`。

## 2. 测试

- `Test-V3.ps1`（两份相同）：受保护 gitlink；绑定报告放行；报告列出未删除路径、绑定到其他 head、其他保护配置、失败状态均失败；无报告与未提交变更不放行；
- `Test-IFXTrustedBase.ps1 -DiffConsumptionOnly` 端到端（trusted runner）：
  - 消费 `change-trusted-base`、授权的受保护删除、revocation-only 均通过，summary 报告 consumed/revoked；
  - 调用方注入的报告与旧变量不能到达 Diff；
  - 混合撤销、与授权不一致的变更、额外受保护删除、重命名记录均失败。
- `Test-IFXTrustedBase.ps1 -DiffConsumptionOnly` 直接调用 verifier：
  - 目录 move 与 case-rename 通过；
  - 失败的情形：大小写重命名按 move 消费、未声明大小写重命名、move 目标下额外文件、`delete` 覆盖大小写重命名、授权后 source 变化、重复覆盖、消费 `weaken-policy`、仅 head 存在的授权、未删除授权、未使用授权、并发 PR 重复消费、修改记录、新增无效记录、`.gitattributes`、受保护 gitlink。

## 3. 与 Plan 06 文字的差异

| Plan 06 描述 | 实际实现 | 理由 |
| --- | --- | --- |
| P4 作为一个检查点 | 拆为 CP06a（本 PR）、CP06b（policy/config 双轨与 `weaken-policy`）、CP06c（演练与证据）、CP06d（第一次真实 D17 删除），P4.4 延后 | 用户于 2026-09-17 批准（D23） |
| P4.2 `.gitattributes` 变更单独验证 | CP06a 一律失败关闭，CP06b 以 `weaken-policy` 开通 | 在 `weaken-policy` 校验存在之前不开放削弱通道（D23） |
| §12.3 授权与实际变更逐项一致 | 按保护义务而非路径唯一覆盖 | 同一路径可能需要删除与 TCB 变化两条正交授权（D23） |
| D20 未消费授权的删除等待 P4 | revocation-only PR 允许撤销 | D22 |
| 以报告替换 `GUARD_CONSUMED_AUTHORIZATIONS` | 本 PR 的模板仍兼容旧变量，runner 不再设置并在子进程中清除；CP06b 删除兼容代码 | 候选验证把 base（CP05）的 `Test-V3.ps1` 叠加到本候选上，旧测试依赖该变量；直接删除会使本 PR 无法通过 base-owned validation（expand/contract） |

## 4. 验证

见 PR 描述与 CP06a 汇报。

## 5. 回退

还原本 pair 列出的文件会再次修改 TCB 组件，需要新的 `change-trusted-base` 授权。
