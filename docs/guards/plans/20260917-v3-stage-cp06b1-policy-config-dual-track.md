# CP06b1 — Plan 06 P4（二）：policy/config 注册表、`weaken-policy` 与 head 候选验证

本 pair 是 [正式 Plan pair](20260916-v3-stage-oriented-package-refactor.md) 检查点 CP06b1 的变更 PR，实施 [Plan 06](06-v3-stage-oriented-package-refactor.md) §12.4 与 §14 P4.3 中 package policy/config 部分，依据 D24。它消费 `20260917-v3-stage-cp06b1-authorization` 加入的 `change-trusted-base` 授权。本 PR 首次引入 policy/config 义务，由 CP06a base 判定，只消费 `change-trusted-base`（activation exception，D24）；新规则在下一个修改已登记 policy 的 PR 中验证生效。

## 1. 变更

**注册表**：新增 `shared/policy-config.json` 与 `contracts/policy-config.schema.json`（`tcb.manifest`、`tcb.contracts`）：

| 角色 | 文件 |
| --- | --- |
| editable policy | `profiles/ifx/{profile,project-map,tech-stack}.json`、`profiles/ifx/rules/*.json`、`policy/layerguard.json`、`policy/baselines/plan05.json`、`history/manifest.json` |
| trust/meta-policy | `policy/authorities.json`；六个 `stages/*/stage.json` 与 `stages/diff/protection.json`（明确文件集合）；`shared/commands.json`、`shared/trusted-components.json`、`shared/policy-config.json`；`guard-system.json`；`ci/jobs.json`；`contracts/*.schema.json`；根 `.gitattributes`（normalized text，根指针） |
| derived projection | 不登记；只有 base `policy/authorities.json` 的精确 target |

`stages/diff/authorizations/` 被排除。注册表为每个已登记 schema 的每个属性定义声明 monotonicity（177 项，全部为零比较器 `none`）。

**保护义务**（`Test-IFXProtectedChanges.ps1`）：

- 每个已登记文件的语义变化（JSON 解析后比较、文本规范换行后比较）产生一个 `policy-weakening` 义务，记录变化的 JSON Pointer；与受保护删除、TCB 变化正交，因此 trust/meta 变化同时需要 `change-trusted-base` 与 `weaken-policy`；
- `weaken-policy` 启用：只有 blob SHA-256、head tuple、注册 schema 或 format 与变化 pointer 集合完全一致时才覆盖；
- registry roots 内未登记的 JSON 与未登记的 `.gitattributes` 失败；CP06a 中 `.gitattributes` 的一律拒绝改为 `weaken-policy` 通道；
- 报告增加 `policyRegistrySha256`、`authorizationSchemaSha256` 与义务 `pointers`；runner 复核 registry 与 schema hash。

**Head 候选验证**（新增 `Test-IFXPolicyCandidates.ps1`，trusted Diff 检查项 `policy-candidates`）：从 base 运行，只读取明确 PR head commit 的 Git 对象：

- 已登记 JSON 可解析并符合注册 schema（本 PR 修改该 schema 时使用 head schema）；
- 修改 profile 时由 base V3 runner 验证 head profile；
- 修改 `history/manifest.json` 时由 base historical integrity engine 以 head evidence 校验引用、hash 与 summary；
- 修改 projection target 或其来源时，由 base generator 从 head authority 来源重新生成并与 head projection 比较；
- head 注册表符合 schema，且为其登记的全部 schema 字段声明 monotonicity。

**Contract 步骤**：通用 Diff 模板删除 `GUARD_CONSUMED_AUTHORIZATIONS` 兼容代码（V3 与 V3_ifx 相同，generated 已更新）。

**其他**：`New-IFXTrustedBaseAuthorization.ps1 -Operation weaken-policy [-PolicyPaths]`；`stages/diff/stage.json` 的 `v3-pre-diff` trust contract 增加 base 输入 `shared/policy-config.json` 与 `policy/authorities.json`；`Invoke-IFXManifestCheck.ps1` 校验注册表 schema、root 覆盖、projection 与排除目录不被登记、monotonicity 声明完整；授权 README、`trusted-base.md` 与 `policy/README.md`。

## 2. 测试

- `Test-IFXTrustedBase.ps1 -DiffConsumptionOnly` 新增：
  - 通过：trusted runner 接受授权的规则变化（summary 报告 `fixture-rule.json (consumed)` 与 `policy-candidates` pass）、纯格式变化无需授权、授权的新增规则、授权的 `.gitattributes`、trust/meta 变化同时消费两条记录；
  - 失败：未授权规则变化、超出授权 pointer、未登记 policy 文件、未授权 `.gitattributes`、只有 `change-trusted-base` 的 trust/meta 变化、未使用的 `weaken-policy`；
  - 候选验证：授权变化通过；无效 head profile、与 head evidence 不符的 history manifest、未随来源生成的 projection、未声明 monotonicity 的 schema 字段均失败。
- `Test-IFXManifests.ps1` 新增 4 个负例：未登记 policy 文件、未声明 monotonicity 的 schema 字段、注册表登记 projection target、注册表登记授权记录。

## 3. 与 Plan 06 文字的差异

| Plan 06 描述 | 实际实现 | 理由 |
| --- | --- | --- |
| P4.3 双轨验证作为一个步骤 | CP06b1（package policy/config）与 CP06b2（D18 domain authority 覆盖）；b2 合入前 D18 blocking findings 继续失败关闭 | 用户于 2026-09-17 批准（D24） |
| trust/meta 变化按 §11.5 验证 | 零比较器阶段同时需要 `change-trusted-base` 与 `weaken-policy` | 用户批准，不提前实现 additive comparator（D24） |
| 新规则的首个 PR 即受约束 | 本 PR 由 CP06a base 判定，只消费 `change-trusted-base`；下一个修改已登记 policy 的 PR 验证新规则 | activation exception（D24） |

## 4. 验证

见 PR 描述与 CP06b1 汇报。

## 5. 回退

还原本 pair 列出的文件会再次修改 TCB 组件与 trust/meta policy，需要新的 `change-trusted-base` 与 `weaken-policy` 授权。
