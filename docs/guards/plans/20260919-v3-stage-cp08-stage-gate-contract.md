# CP08 — Plan 06 P7 仓库外、项目专属 Stage Gate contract

本检查点完成 P7 的 contract 阶段：canonical `docs/guards/V3` 成为唯一 Stage Gate 实现，IFX 仅保留 profile、policy、orchestration 与三个公开兼容 wrapper。生成工程不再作为源码或 profile 快照被 Git 跟踪。

## 1. 生成与命名契约

- Generate/Check/Test/Diff 必须显式提供位于 `TargetRoot` 之外的 `GenerationRoot`。
- 输出根为 `<generation-root>/<package>/gates/stage/`；IFX 使用 package id `v3-ifx`。
- profile `projectId` 以确定性 kebab-case 转换为 .NET identifier，工程名为 `{ProjectId}.Guards.StageGate.Tests`。已有 identity 不同但映射到同一 identifier 时 fail closed。
- 工程内部按 `Self/`、`Post/`、`Diff/` 与 `GeneratedInputs/` 分层；input snapshot 仅存在于外部运行时目录。

## 2. 取消跟踪与去重

- 删除 tracked `V3_ifx/generated/stages/**`，并在根 `.gitignore` 中阻止该旧路径和 canonical legacy generated 路径重新进入版本控制。
- IFX workflow 与 dispatcher 直接调用 canonical V3；reviewed lock 随工程名移动为 `Ifx.Guards.StageGate.Tests.packages.lock.json`。
- 删除 IFX 内部的 V3 architecture script、hooks、dotnet templates 和三个 generic tests；`Invoke-V3.ps1`、`Invoke-V3Setup.ps1`、`Invoke-V3Docs.ps1` 作为公开路径保留薄 wrapper。
- trusted component manifest 移除 generated-candidate 与 transition-copy ownership，改为声明 canonical generator/tests 和三个 public wrappers。

## 3. 授权边界

本 change 在实际候选提交上生成并消费：一个 `change-trusted-base`、一个覆盖全部 registered semantic changes 的 `weaken-policy`、一个 lock move，以及 generated tree、hooks、templates、architecture script 和三个测试文件的精确 delete 授权。授权 PR 只包含这些 record；change PR 删除全部 record。

## 4. 验收

- canonical `Test-V3.ps1`、`Test-V3ArchUnit.ps1`、`Test-V3BuildBaseline.ps1` 全部通过；
- IFX profile 在仓库外完成 Generate、Check、Locked Test，且新 lock 稳定；
- manifest 与 CI contract 正/负向测试通过，IFX package/trusted-base candidate parity 通过；
- clean checkout 对同一候选完成 Generate/Check/Test/Diff，目标 checkout 和 base worktree 无生成输出；
- `git ls-files docs/guards/V3_ifx/generated/stages` 为空，runtime reference scan 不再指向已删除的 IFX 内部副本。
