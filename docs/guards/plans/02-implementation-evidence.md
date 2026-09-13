# 首版实施证据与剩余条件

实施基点为 `codex/guards-principles-plan` 的 `d19c4fa`。开始时工作树干净。本文件区分仓库中已实现的门禁、在本地实际运行的检查，以及尚未由远端 CI/仓库设置证实的合入保护。

## 冻结的既有权威

下列值是实施开始与结束时相同的工作树文件原始字节 SHA-256；生成器只读取这些文件。G03/G04/G05、LayerGuard 及原有 workflow 未被本次实施修改。

| 文件 | SHA-256 |
| --- | --- |
| `src/layerguard.json` | `5e361f30a14537581018ba5eebae9aae220fcaf8dfae0ffbb826d8ff3523ba74` |
| `mcp/LayerGuard/baselines/plan05.json` | `a68dae538fe4b320b7e76a309aecee80b6b4bee68302d5e8ac2a3eabfe2f8496` |
| `mcp/LayerGuard/src/LayerGuard/LayerGuard.csproj` | `4d6d69d7c879f04bb95441137251318e12454e145527a182d68029e892add8a1` |
| `docs/architecture/review/gates/G03/contract-event-catalog.yaml` | `38cb32a9a640889275120fdfcfea3eada5431b6171cfb8e52922711bbadf1ba1` |
| `docs/architecture/review/gates/G03/generated/layerguard-governance-input.json` | `d255013fc20f5cdd17fe1548430a7cd6143bc0cf1262755368aa1fbaa0c32649` |
| `deployment/g04/module-manifest.json` | `776be5076bc65d205c160a7ffba4a63fcb2f93e1d3c738b042b9939ab7d80646` |
| `deployment/g04/release-runtime-manifest.json` | `c8c580aa0feb5c287ca488561bb7473d345655f94678b1cce80c302c9633caeb` |
| `docs/architecture/review/gates/G05/observability-security-policy.json` | `828abb9c8e947d6ef30ffcf4515b128ef5965342a0d01778b7bc3b36f4a32673` |
| `docs/architecture/review/gates/G05/context-protocol-v1.json` | `499c9dac90bf76366de226c7f61743ddb361acce5afe91b50da44fe0fff32495` |
| `deployment/migration-safety-policy.json` | `f9a0ee2c3d3dd822bb888b63e7b772a1b4773f8a63e7d165b1deb917efd35acb` |

原工作流 SHA-256：`layerguard.yml` `2be88a446f64af86149a28af6471e514feb6d47a034673508c30d835335047fe`；`contract-event-governance.yml` `e45adf009591375df6a3a81b14dac5bce65cab08faa225bed1ff67b22a391582`；`g04-deployment-runtime.yml` `63948cc571641d7ba7ccbdd08d6f2b8b9eb5d6eded540ab7e545aae3fd6175a5`；`g05-context-boundary.yml` `e42352f4be364e98296c6ac56462f5221182e28750ca6c8f4349f2d2acead13c`；`plan04-governance.yml` `d4fb0572e3fbf54e614e32de37df405db0213606f6e01cb839806d03c029867b`；`database-migrations.yml` `01fa77075221501047c42acc8f30d12fcfac7717106903c6297b81fc650b3bff`。

LayerGuard 报告版本为 `0.4.0-a1`。现有 CI 分别运行 LayerGuard、G03、G04、G05、Plan 04 和数据库迁移检查；数据库 workflow 构建 solution 并运行数据库边界测试，G04/G05 验证脚本还运行相应后端构建/测试。实施前没有前端 `npm ci`、`lint`、`test:run`、`build` CI job，也没有 `dotnet format --verify-no-changes` 命令。新增 workflow 补上前端 job；后端格式检查保留为 `BE.FORMAT` 的 `none/advisory`，不假称已机械覆盖。

规则与权威入口逐项见 [生成规则索引](../generated/INDEX.md)和[覆盖矩阵](../generated/COVERAGE_MATRIX.md)。LayerGuard 的 `notChecked` 明确包含“semantic symbol binding”。新增 Domain 程序集检测器读取 `src/layerguard.json` 的 `allowedReferences.Domain`，用编译后程序集的实际直接引用补足项目文件/语法扫描的一部分盲区；本地正反程序集 fixture 已证明允许引用通过、违规引用阻断。它不识别具体方法、类型的业务语义，`ARCH.SEMANTIC` 仍保持 `none/advisory`，由架构维护者审查，待更完整的编译器语义检测器有正反 fixture 后再考虑 blocking。既有行为、契约、迁移验证仍以各专用 Gate 报告为证据，不由新规则名代替。

| 规则 ID | 关联的实际验证入口 | 仍未证明的部分 |
| --- | --- | --- |
| `L1.2`、`L2.*`、`L3.*` | `Invoke-LayerGuard.ps1` 及其 190 项工具测试；`L2.2` 增加 `Invoke-DomainAssemblyGuard.ps1` | 具体类型/方法的语义绑定、实际运行时调用与完整业务行为 |
| `G03.CONTRACT` | `Invoke-G03ContractEventGuard.ps1` 的 catalog、source reconciliation、handoff 与文档核验 | 消费者运行时行为 |
| `G04.RUNTIME` | `Invoke-G04Verification.ps1` 的 runtime guard、编排、失败矩阵、入站契约及 LayerGuard | 目标环境实际发布与运维审批 |
| `G05.CONTEXT` | `Invoke-G05Verification.ps1` 的 context boundary、catalog security、迁移安全与 LayerGuard | 外部 IdP 与生产租户数据行为 |
| `P04.GOVERNANCE` | `Test-Plan04Governance.ps1`，对应独立 Plan 04 CI job | 所有租户授权业务路径 |
| `DB.MIGRATION` | 数据库 CI 的 pending-model、SQL bundle、迁移安全、`IFX.DatabaseBoundary.Tests` | 目标环境迁移审批和发布结果 |
| `FE.QUALITY` | 新前端 job 的锁文件安装、lint、63 项单测和 build | 浏览器端到端验收 |

## 本地验证

| 检查 | 结果 |
| --- | --- |
| 再生成两次、只读 Check、输入/产物漂移反例 | 通过 |
| 新项目模板及 Pre/Post/Diff 正反例（缺权威、重复 ID、无检测器、越界路径、跳过命令、无决策、重命名、受保护文件删除等） | 通过，Windows 本地 PowerShell 7.6.5 |
| 当前 IFX Diff（两个独立高风险决策记录覆盖实际变更） | 通过；不代表人工已批准决策 |
| 前端 `npm run lint` | 通过，0 errors、4 条既有 hook 依赖 warning |
| 前端 `npm run test:run` | 通过，11 个文件、63 项测试 |
| 前端 `npm run build` | 通过 |
| LayerGuard 隔离 LF 干净检出的测试 | 通过，190/190 |
| LayerGuard 隔离 LF 干净检出的严格扫描 | 通过；原始 JSON 报告保存在忽略提交的 `artifacts/guards/verification-layerguard-clean.json` |
| Release solution build 与编译后 Domain 程序集检查 | 通过；构建 0 error、19 条既有 warning，5 个 Domain 程序集引用均符合现有策略 |
| Domain 程序集检测器正反 fixture | 通过；允许引用 pass、违规引用 fail、缺失程序集 blocked |

直接在当前 Windows 工作树运行原始 `Invoke-LayerGuard.ps1` 时，沙箱不能读取用户级 `NuGet.Config`。绕过 restore 运行测试时，5 项因 `deployment/g04/module-manifest.json` 的本地 CRLF 原始字节哈希而失败：原始字节为 `776be5…`，LF 归一化后为绑定要求的 `4047c3…`。用 `git archive HEAD` 建立不修改原文件的隔离 LF 检出后，190 项测试及严格扫描均通过。新增 `.gitattributes` 为新门禁文档/脚本指定 LF，原有 G04 的 LF 声明未更动。

## CI 与保护状态

仓库文件已声明新 `Coding Guardrails` 的 `guard-framework`、`framework-windows`、`frontend-quality`、`assembly-domain` 四个 job；PR 上运行再生成 Check、框架测试、显式 base/head SHA 的 Diff，main push 运行再生成 Check、框架测试和编译后架构检测。Linux 和 Windows CI 尚未实际运行，因为本分支尚未推送/创建 PR。新 workflow 不重复执行旧 Gate；现有 workflow 状态仍需独立审查。

读取 GitHub `main` branch protection 与 rulesets 的 API 均返回 HTTP 403：`Upgrade to GitHub Pro or make this repository public to enable this feature.` 因此目前**没有证据**表明新旧 checks 已被设为 required，也无法在当前仓库套餐下完成这项外部配置。不能把 workflow 文件存在等同于合入门禁生效。仓库所有者需要在该功能可用后，把新四个 job 和既有必需 Gate job 加入 required checks，并用一次故意不再生成的 PR 证明阻断；之后再更新本记录。
