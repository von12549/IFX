# V3_ifx 后续质量清理 TODO

> 状态：CIQ-01–CIQ-10 Completed（2026-09-16）。
>
> 来源：PR #26 的 GitHub Actions run `34991428279`。Plan 05 只负责 V3_ifx CI 切换和旧 Guardrails 清理；本文件记录切换后暴露的依赖安全、编译和前端质量问题。每项实施前应形成独立范围、补充风险评估并更新对应测试。

## 依赖安全与确定性恢复

- [x] **CIQ-01 — AutoMapper 高危漏洞**：五个 Application 项目统一升级至 `AutoMapper` `15.1.3`，移除 `AutoMapper.Extensions.Microsoft.DependencyInjection`，更新 DI 注册，并为每个 mapping profile 增加配置校验。选择 15.1.3 是为了保持 Microsoft.Extensions 8 依赖线；16.1.1 的试验恢复产生了 NU1605，因此未采用。恢复及模块测试不再出现 `NU1903` / `GHSA-rvv3-g6hj-g44x`。
- [x] **CIQ-02 — MemoryCache 高危漏洞**：Transaction、Holdings Infrastructure 已升级到 `Microsoft.Extensions.Caching.Memory` `8.0.1`。恢复不再出现 `NU1903` / `GHSA-qj66-m88j-hmgj`。
- [x] **CIQ-03 — Cognito 不确定恢复**：`AWSSDK.CognitoIdentityProvider` 已固定为存在且兼容当前代码的 `3.7.402.11`；恢复、认证测试和集成测试不再出现 `NU1603` 或隐式版本替换。
- [x] **CIQ-04 — npm 漏洞清理**：通过兼容范围内的 lockfile 更新消除原有 1 low、6 moderate、12 high 漏洞，没有使用 `--force`。V3 Frontend quality 会保存完整及 production-only JSON audit 报告；`npm ci`、零警告 lint、67 个测试和 production build 均通过。

## 编译与前端代码警告

- [x] **CIQ-05 — 旧认证入口**：`POST /api/v1/auth/login` 不再接收或处理密码，固定返回 `410 Gone` 并指向 OAuth 2.0 Authorization Code 入口；路由集成测试覆盖迁移响应。Release build 不再出现 `CS0618`。
- [x] **CIQ-06 — IAM nullable 流**：刷新 token 成功响应必须包含 access、ID 和 refresh token，否则明确失败；缺失或空白的 `ipAddress` 统一记录为 `Unknown`。对应 handler 测试已覆盖，未使用 null-forgiving operator，Release build 不再出现相关 `CS8601`/`CS8604`。
- [x] **CIQ-07 — React Hook 依赖**：四个页面使用依赖明确的稳定 callback；新增测试验证租户或路由参数变化时只重新加载一次，等价 rerender 不产生重复请求。ESLint 以 `--max-warnings=0` 通过。

## 清零后的 CI 强化

- [x] **CIQ-08 — 警告回归门禁**：V3 Solution restore 以 `-warnaserror:NU1603,NU1903` 执行；Frontend quality 同时运行 production/full `npm audit --audit-level=high` 并保存 JSON 报告，lint 以 `--max-warnings=0` 执行。V3 package tests 会检查这些阻断参数，现有 required checks 无需新增名称。
- [x] **CIQ-09 — download-artifact 上游 DEP0005**：截至 2026-09-16，仓库已使用当前 v8 major，最新发布为 [`v8.0.1`](https://github.com/actions/download-artifact/releases/tag/v8.0.1)，但上游问题 [`actions/download-artifact#484`](https://github.com/actions/download-artifact/issues/484) 仍处于 open。该警告不影响 artifact 下载，仓库不作全局抑制。Owner：`xiaolong-feng`；下次复查：2026-10-16，届时若有修复版本则升级并重跑 assembly artifact 传递。

## 实施期间发现的后续项

- [x] **CIQ-10 — .NET 传递依赖漏洞基线**：所有 81 个活动项目已采用 NuGet Central Package Management；EF Core 全家族及仓库 `dotnet-ef` 工具统一到 `8.0.31`。全量审计同时识别并修复 Hangfire、Testcontainers、WireMock 等既有高危传递链，V3 Solution 现在执行 direct/transitive JSON 审计并阻断 high/critical advisory。最终审计为 81 个项目、0 个漏洞发现；Release build、全量测试、数据库模型/迁移验证和 V3 package gate 均通过。详细计划：`docs/guards/plans/20260916-ciq10-central-package-security.plan.json`。

## 完成定义

- GitHub Actions 不再产生 Node.js 20 action runtime 弃用提示。
- `dotnet restore`/`build` 不再产生上述 NuGet、obsolete 或 nullable 警告。
- `npm ci` 不再报告已知 high/critical 漏洞，ESLint 为零 warning。
- CIQ-01–CIQ-10 均已进入独立计划并完成，或附有明确 owner、期限和有证据的风险接受决策。

## 验收记录

- 实施计划：`docs/guards/plans/20260916-v3-ifx-quality-cleanup.plan.json`；详细风险和验证矩阵：`.claude/Plans/20260916-v3-ifx-quality-cleanup.md`。
- NuGet deterministic restore、Release build、模块测试、前端 audit/lint/test/build 和 V3 全套门禁结果，以本分支 CI 及 `artifacts/guards/v3-ifx` 产物为准。
- CIQ-09 属于上游未修复风险，以上 owner、复查日期和 issue 状态满足本清单的风险接受条件。
- CIQ-10 实施计划：`docs/guards/plans/20260916-ciq10-central-package-security.plan.json`；81 个活动项目的 direct/transitive 审计结果为 0 个漏洞发现，并已通过 V3 Solution 与 Specialized Database 验证。
