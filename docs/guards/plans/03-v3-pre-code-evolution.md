# V3 Pre-Code 门禁增强与 IFX 验证计划

> 状态：本轮 Pre-Code 增强与 IFX 验证已完成（2026-09-14）。`V3_backup` 已在测试通过后同步为通用源码快照。本计划不包括 Post/Diff 专项检测器扩展或 CI 激活；本轮 Pre 测试通过不代表这些后续阶段完成。

## 目标与边界

让 Agent 在编码前从独立、可编辑的项目配置中得到归属、层、风险、适用规则和验证命令，并能校验正式 Plan 或普通变更的简短影响面。Pre 只验证声明与决策记录的结构和覆盖，不声称已经验证未来代码或人工批准。`V3` 保存可复制模板与通用实现；`V3_ifx` 保存 IFX 配置和测试；旧门禁不变。全部测试通过后才将 `V3` 通用源码同步到 `V3_backup`，不把 IFX 配置混入备份。

## P0 — 冻结与迁移约束

- 记录 `V3`、`V3_backup`、`V3_ifx` 文件集和当前状态；确认已有 V3 正反例与 IFX LayerGuard 正反例可运行。
- 保留 `V3_backup` 原样，直到 P3 验收通过。同步时核对其与 `V3` 的文件名、文件数和字节内容；不迁入 `profiles/ifx`、本地策略或生成的 IFX .NET 项目。

## P1 — 通用 V3 的结构化 Pre 输入与模板

- 将项目映射和风险目录放入独立 `project-map.json`，以 JSON Schema 描述 area、路径、层、owner、相似实现搜索根、聚焦命令及高风险触发器；保留项目无关的最小样例。单一输入是这些事实的唯一来源。
- 在 `tech-stack.json` 声明可引用的验证命令 ID；Plan 只能引用已登记的命令。规则增加 `appliesTo` 路径范围，使没有 Pre 检测器但由 Post 硬门禁执行的规则也能被 Plan 自动关联；规则仍不得因文字说明而冒充 Pre 已检测。
- 完善 Plan sidecar 与 Markdown 模板：目标、验收、路径、受影响 area、规则 ID、命令 ID、决策路径；正式 Plan 文件名继续固定为 `YYYYMMDD-slug`。普通变更允许命令行提供规划路径并得到简短 Pre 影响报告；触发高风险时要求正式 Plan 与覆盖决策。
- 定义机器可读的 Pre 结果 Schema，区分 `advisory` 与 `blocked`，记录映射的 area/owner、风险、规则、建议命令、输入摘要和失败原因。无归属、未知命令、漏关联规则或缺决策必须显式失败。

## P2 — 通用执行器、Skill/Hook 和正反例

- 扩展 `Invoke-V3.ps1 -Mode Pre`：读取和校验上述输入，确定性生成结果；`Generate/Check` 对新输入做快照和字节漂移检查。旧的 Post/Diff 检测行为保持可用。
- 更新 `guard-plan` Skill 与 Hook 适配器，使其消费同一 Pre 入口和结果契约。包内提供安装说明，但不声称复制文件即可自动触发；实际 host 注册留给部署阶段。
- 扩展 V3 合成测试：普通路径、正式 Plan、高风险缺决策、未知/遗漏 area 或规则、未知命令、空或漂移输入、生成漂移与原 Post/Diff 正反例。测试不把人工决策的内容质量称为机械通过。

## P3 — IFX 配置与能力试验

- 在 `V3_ifx/profiles/ifx` 填写独立的模块/平台/前端/部署/门禁区域与高风险路径，owner 从包内 G03 本地策略事实确定，不在运行时读取旧门禁。
- 为九条 LayerGuard 编号规则填写 Pre 适用范围，补齐 IFX 验证命令 ID。保留已存在的独立 LayerGuard Post 硬门禁及 `L2.2` V3 检测器。
- 在 IFX 正反例中证明：普通变更可得到映射报告；高风险变更必须有正式 Plan 和决策；漏选适用规则/验证命令或未知区域失败；V3 stage Test、独立 LayerGuard 190 项测试和隔离无旧门禁负例仍通过。
- 验收证据记录实际命令、结果及限制。`V3_ifx` 中 G03/G04/G05 专项 validator、Plan 04、数据库、前端与 CI 激活仍另列缺口，不报告为本阶段完成。

## P4 — 同步备份并锁定后续路线

- 仅在 P2/P3 所列测试通过且 `Generate → Check` 无漂移后，将通用 `V3` 文件逐项同步到 `V3_backup`，核对两者文件集及 SHA-256 一致。更新说明文档记下同步基点。
- 后续阶段按顺序增加检测器绑定/覆盖矩阵和统一结果、扩展 Diff 风险复核、安装 Agent host 触发器与 CI required checks，最后用新项目 fixture 证明仅修改配置即可生成适用门禁。以上均不得由本阶段的 Pre 通过推定完成。

## 执行与验收记录（2026-09-14）

- 通用 `V3`：新增 `project-map.json`、命令目录、规则 `appliesTo`、Plan 目标/验收/area 关联、Pre JSON 结果与输入 SHA-256；普通路径摘要和正式 Plan 共用 Pre 入口。Hook 适配两种模式。合成测试覆盖有效/违规引用、生成漂移、未知命令、遗漏 area/rule/command、空 Markdown、高风险决策、未知路径与 Diff 越界；`pwsh -NoProfile -File docs/guards/V3/tests/Test-V3.ps1` 通过。随包 Plan 示例也通过 Pre。
- IFX：独立项目映射和命令目录落在 `V3_ifx/profiles/ifx`；九条编号规则增加适用路径。`Test-IFXPre.ps1` 的普通/正式正例、高风险缺决策、缺项、未知区域及未登记模块负例通过。正式 Plan 示例可通过 Pre。
- 代码后门禁回归：`Invoke-V3.ps1 -Mode Test` 通过 5/5；`Invoke-IFX.ps1 -Mode Test` 通过 190/190 和严格扫描；`Test-IFXPackage.ps1` 的隔离正例、`L2.2` 违规负例和外部绑定负例通过；`Invoke-IFX.ps1 -Mode Check` 无漂移。`V3_ifx/tests/Test-V3.ps1` 通用合成测试通过。
- 备份：完成上述测试后复制通用 `V3` 到 `V3_backup`。两目录各 28 个文件，按相对路径和 SHA-256 比较完全相同；`V3_backup/tests/Test-V3.ps1` 通过。IFX 配置、策略、生成项目未进入备份。
- 限制：Pre 只检查配置、声明及决策覆盖，不执行命令目录中的命令，也不判断决策内容质量。Agent host Hook 注册、CI required check、G03/G04/G05 等专项 validator 的迁入、更多 Post 检测器与覆盖矩阵仍属后续工作。旧门禁及现有 CI 未修改。
