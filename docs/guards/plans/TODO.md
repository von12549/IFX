# V3_ifx 后续质量清理 TODO

> 状态：Backlog。
>
> 来源：PR #26 的 GitHub Actions run `34991428279`。Plan 05 只负责 V3_ifx CI 切换和旧 Guardrails 清理；本文件记录切换后暴露的依赖安全、编译和前端质量问题。每项实施前应形成独立范围、补充风险评估并更新对应测试。

## 依赖安全与确定性恢复

- [ ] **CIQ-01 — AutoMapper 高危漏洞**：将所有 `AutoMapper` `12.0.1` 使用升级到已修复版本（至少 `15.1.1` 或 `16.1.1`），移除已废弃的 `AutoMapper.Extensions.Microsoft.DependencyInjection` 依赖，并验证全部 mapping profile、DI 注册和模块测试。验收时不得再出现 `NU1903` / `GHSA-rvv3-g6hj-g44x`。
- [ ] **CIQ-02 — MemoryCache 高危漏洞**：将 Transaction、Holdings Infrastructure 的 `Microsoft.Extensions.Caching.Memory` `8.0.0` 至少升级到 `8.0.1`，与仓库内其他模块对齐。验收时不得再出现 `NU1903` / `GHSA-qj66-m88j-hmgj`。
- [ ] **CIQ-03 — Cognito 不确定恢复**：把不存在的 `AWSSDK.CognitoIdentityProvider` `3.7.401.18` 替换为经验证且明确存在的兼容版本，并验证认证单元测试、集成测试和 OAuth/Cognito 流程。验收时不得再由 NuGet 自动选择 `3.7.402`，也不得出现 `NU1603`。
- [ ] **CIQ-04 — npm 漏洞清理**：保存完整 `npm audit` 报告，区分 production/dev 与直接/传递依赖，消除当前 1 low、6 moderate、12 high 漏洞；升级后执行 `npm ci`、lint、63 个测试和 production build。不得以强制更新或忽略 advisory 代替兼容性验证。

## 编译与前端代码警告

- [ ] **CIQ-05 — 旧认证入口**：移除或完成 `AuthEndpoints.Login` 到 OAuth 2.0 Authorization Code flow 的迁移，补充路由兼容性和授权测试。验收时不得出现 `CS0618`。
- [ ] **CIQ-06 — IAM nullable 流**：修复 `RefreshTokenCommandHandler` 的 3 个 `CS8601` 和 `UpdateUserProfileCommandHandler` 的 2 个 `CS8604`，明确 token claims 与 `ipAddress` 缺失时的领域行为，不使用 null-forgiving operator 掩盖未验证输入。
- [ ] **CIQ-07 — React Hook 依赖**：修复 `PolicyManagementPage`、`RoleDetailPage`、`RoleGroupDetailPage`、`UserDetailPage` 的 4 个 `react-hooks/exhaustive-deps` 警告；使用稳定 callback 或将加载逻辑放入 effect，并覆盖依赖变化和重复请求行为。

## 清零后的 CI 强化

- [ ] **CIQ-08 — 警告回归门禁**：以上基线清零后，为 NuGet `NU1603`/`NU1903`、npm high/critical audit 和 ESLint warning 添加阻断规则。候选命令为 `dotnet restore -warnaserror:NU1603,NU1903`、`npm audit --audit-level=high` 和 `npm run lint -- --max-warnings=0`；先验证跨平台退出码和报告输出，再纳入 required checks。

## 完成定义

- GitHub Actions 不再产生 Node.js 20 action runtime 弃用提示。
- `dotnet restore`/`build` 不再产生上述 NuGet、obsolete 或 nullable 警告。
- `npm ci` 不再报告已知 high/critical 漏洞，ESLint 为零 warning。
- CIQ-01–CIQ-08 均已进入独立计划并完成，或附有明确 owner、期限和有证据的风险接受决策。
