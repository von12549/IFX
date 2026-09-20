# CP07b — Plan 06 P6.2–P6.3：通用 engine 与 IFX policy binding 分离

本 pair 是 [正式 Plan pair](20260916-v3-stage-oriented-package-refactor.md) 检查点 CP07b 的变更 PR，按 [Plan 06](06-v3-stage-oriented-package-refactor.md) §14 P6.2、P6.3 与 D27，把 IFX 的 G03/G04/G05 规则从通用 engine 移入受 TCB 管控的 IFX binding，并让 engine 通过扩展点接受 binding。它消费 `20260918-v3-stage-cp07b-authorization` 加入的授权。

## 1. 变更

**通用 engine（`src/LayerGuard`）**

- 新增 `PolicyBinding.cs`：`IPolicyBinding`（`Section` 与 `Load(section, config, configPath)`）、`PolicyBindings` 注册表、`PolicyBindingResult`/`PolicyBindingInfo`/`WaiverPolicyInfo`/`PolicyBindingFile`，以及 binding 可复用的严格 JSON 读取、artifact 解析与 hash 助手 `PolicyDocument`（raw 与 canonical-text 两种 hash 规则不变）；composite hash 仍由 engine 计算，输入为 `layerguard.json` 加 binding 声明的文件；
- 删除 `GatePolicyBindings.cs`：G03 catalog 投影、contract roles、adapter edges、shared primitives、waiver policy、G04 绑定与部署单元、G05 依赖政策等 IFX 规则全部移出；
- `Ruleset.cs`：`gatePolicies` 不再是 typed IFX 结构，而是原样交给已注册 binding 的 `JsonElement`；没有 binding 时失败关闭（`configures gatePolicies, but this host registered no policy binding for it`）；G04 project role 绑定检查移入 IFX binding；
- `Cli.cs`（新增）：命令行与 MCP 入口成为 `Cli.Run(args)`，MCP 工具显式从 engine assembly 加载；`Program.cs` 只调用 `Cli.Run`，不注册任何 binding。

**IFX binding 与 host（`src/LayerGuard.Ifx`）**

- 新增 `IfxGatePolicyBinding.cs`：所有 IFX 规则与常量（`ifx-api`/`ifx-worker`/`ifx-all` 与 `Runtime:Role`、必需 host role、授权 backup owner handle、不可豁免类别、豁免上限 90 天、`BCL-only`、G05 禁止依赖清单、contract roles、RuntimeHost→Composition 绑定）；这是所有权迁移，policy 文件不变；
- `IfxArchitectureConformance`：`Register()` 幂等注册 binding，`Analyze` 先注册再调用 engine；路径与入口与 CP07b-prep 相同；
- 新增 `Program.cs`：IFX host（`layerguard-ifx`）注册 binding 后调用 `Cli.Run`，CLI/MCP 契约不变。

**runner 与测试**

- `scripts/Invoke-IFX.ps1`：Scan 构建并运行 IFX host（engine 自身无 binding，直接运行会失败关闭）；Check 增加大小写不敏感的 IFX 标识扫描，覆盖 `src/LayerGuard/`、`tests/LayerGuard.Tests/` 与 `tests/fixtures/`；
- `tests/LayerGuard.Tests/PolicyBindingTests.cs`（新增）：未注册 binding 时绑定段失败关闭；注册的 stub binding 提供 provider graph、waiver policy 与 composite hash；
- `tests/Test-IFXPackage.ps1`：新增「engine 源码出现 IFX 标识时 Check 失败」负向用例；隔离 fixture 在 `docs/guards/V3/stages/post/gates/architecture/dotnet` 存在时一并复制（P6.4 迁移前为空操作），`tests/Test-IFXManifests.ps1` 同样复制 `docs/guards/V3/stages`，使下一个检查点的 base-owned 验证能看到迁移后的 V3 engine 树；
- `build/locks/LayerGuard.Ifx.Tests.packages.lock.json`：IFX 项目 assembly 名称改为 `layerguard-ifx` 带来的 lock 更新（仅项目名一行）。

## 2. 不变量

- policy composite hash 不变：报告 hash `d25e881a0cb6f2408b7e0a8fd5f2af37cd362e25ba241d5bb516d2d2f0c7a76f` 与 `policy/baselines/plan05.json` 的 `rulesetHash` 相同；
- report 字段、`toolVersion` `0.4.0-a1`、12 条 policy binding（G03、G03-catalog、G04 与 8 个 G04 绑定、G05）不变；
- CLI 动词与参数、MCP 工具契约不变；`v3-architecture` 与 13 个 required check 名称不变；
- 所有 policy 文件逐字节不变。

## 3. 验证方式

- `Invoke-IFX.ps1 -Mode Test`：engine 测试 184 个（含 2 个新 binding 用例）、IFX policy binding 测试 10 个全部通过，严格扫描通过；
- `Invoke-IFX.ps1 -Mode Check`：源码清单、精确项目集合与引用、fixture 对应与 IFX 标识扫描通过；
- `Test-IFXPackage.ps1` 通过（含新增负向用例）；
- `Test-IFXManifests.ps1`、`Test-IFXTrustedBase.ps1` 通过；
- 本地两 PR 模拟：`v3-pre-diff` 的保护义务由授权恰好覆盖，Validate、Architecture、HistoricalIntegrity 与候选验证通过。

## 4. 与 Plan 06 文字的差异

| Plan 06 描述 | 实际实现 | 理由 |
| --- | --- | --- |
| P6.2 runtime role 与 IFX project/type names 移入 IFX policy/fixtures | 移入受 TCB 管控的 IFX binding 代码，policy 文件不变 | 所有权迁移而非 policy 外部化，保持 composite hash（D27，用户批准） |
| P6.3 分离通用检测引擎与 IFX policy binding | engine 提供 binding 扩展点，IFX binding 与 host 位于 `src/LayerGuard.Ifx`，engine 无 binding 时失败关闭 | CP07c 迁入 V3 时只需移动 engine，binding 留在 V3_ifx（D12、D27） |

## 5. 回退

还原本 pair 会把 IFX 规则放回通用 engine，属于 TCB 变更，需要新的 `change-trusted-base` 授权；Check 的 IFX 标识扫描会阻止在通用 engine 中重新引入 IFX 标识。
