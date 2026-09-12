# Plan 05 后续：旧 Auth 目录与依赖清理

日期：2026-09-13；检查基于 `e274611`。本次没有删除业务源码或变更权限、schema、API、运行配置。

## 检查与删除

检查 Git 跟踪的 169 个 csproj（含工具和测试 fixture）及 287 个 ProjectReference：没有指向旧 Auth 项目的引用，没有不存在的引用目标。solution、props/targets 与活动构建配置中也没有旧 Auth 项目依赖。

| 删除的本地目录 | 文件数 | 内容 |
| --- | --- | --- |
| src/Modules/Auth | 6 | 旧 Composition 的 obj 生成文件 |
| tests/IFX.Modules.Auth.Application.Tests | 278 | bin/obj |
| tests/IFX.Modules.Auth.Domain.Tests | 278 | bin/obj |
| tests/IFX.Modules.Auth.Infrastructure.Tests | 375 | bin/obj |
| tests/IFX.Modules.Auth.Presentation.Tests | 288 | bin/obj |

合计 1225 个文件、132794656 bytes，约 126.6 MiB。删除前逐项确认绝对路径位于工作区、没有 Git 跟踪文件、没有 bin/obj 外的文件、没有 reparse point。这些文件此前被 Git 忽略，因此本次不会出现项目源码删除 diff。

## 开发指引

发现一份根 CLAUDE.md；定向审查评分 55/100：命令 15/20、架构 10/20、特殊约束 10/15、简洁度 10/15、时效性 0/15、可执行性 10/15。主要问题是仍要求 Auth 三子域、旧 Provider 项目位置及旧授权规则。

更新 CLAUDE.md 和七份活动 `.claude` 指引：项目/测试/迁移路径改为 IAM；说明四个子域、平台协议实现和 Port/Adapter 消费；移除已退休的安全类型与放行规则指引；迁移应用指向受控 Migrator。详细现状统一引用 [当前 IAM 架构](../../iam-platform-security.en.md)。历史计划没有改写成新实现。

以下旧标识有明确用途，予以保留：

- IAM Composition 的精确 Hangfire cleanup alias，以及两种旧 assembly qualification 的测试。
- `auth` schema、`AuthDatabase`、逻辑 Auth module ID、原 migration history 和 `/api/v1/auth` API。
- 固定历史报告、旧 LayerGuard baselines、`.claude/Plans` 历史计划。
- Invoke-Plan05Inventory.ps1 的 Auth 路径：该脚本读取指定旧 Git commit，默认 f29ad32，不读取当前 Auth 目录。

## 验证

- Release solution build 通过：0 errors、19 项既有 warnings。
- LayerGuard 严格边界与 Plan 05 安全边界通过。
- IAM 旧任务兼容和 API/Worker Composition：7/7，0 failed/0 skipped。
- 构建后五个旧目录仍不存在；未重新生成。
- 文档 diff 空白检查通过。本次只有构建残留和指引清理，没有重跑数据库/全量业务回归。

本地审计清单与日志位于 `artifacts/plan05/cleanup/`：removed-build-artifacts.json、dependencies.json、build.log、layerguard.json、security-boundary.json、compatibility-tests.log 和 tests/*.trx。提交与推送状态以 Git 历史及远端分支为准。
