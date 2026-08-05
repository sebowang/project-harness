# 兼容与迁移

## v1 支持矩阵

| 部件 | 支持范围 | 说明 |
|---|---|---|
| 初始化器 | Windows PowerShell 5.1、PowerShell 7 | macOS/Linux 使用 `pwsh`；CI 双跑 |
| Agent 入口 | Codex、Claude Code、Trae | 共用 `AGENTS.md` 和 `docs/workflows/` |
| 配置 schema | `harness.config.json` schema `1` | 项目拥有，更新不静默重写 |
| 安装状态 | `harness.lock.json` schema `1` | Harness 管理，记录受管文件基线 |

## 从 0.x 迁移

1. 备份目标仓库并确认 `git status --short`。
2. 用 v1 初始化器执行 `-WhatIf`；已有文件默认 `SKIP`，先区分项目所有文件和受管入口冲突。
3. 如果受管入口与模板冲突，确认迁移范围后使用 `-Force`。它只覆盖 manifest 标记为 `managed` 的文件，先把旧文件备份到 `.harness-backup/<timestamp>/`，并刷新这些文件的 lock 基线；项目所有文件仍不会覆盖。
4. 若已有 `AGENTS.md` 需要保留并接入 Harness，使用 `-MergeProjectRules`；它只更新带 `PROJECT-HARNESS` 标记的受控区块，并备份原文件。
5. 检查生成的 `harness.config.json`，补充真实项目验证命令和已确认能力。
6. 运行 `scripts/verify.ps1 -Scope Harness`，再按 onboarding 工作流补齐事实。
7. 以后升级先运行 `-Update -WhatIf`。冲突时处理目标仓库的本地修改后再重试。

没有 lock 的旧安装不能安全推断基线，因此 v1 不会自动升级它；重新安装只创建缺失文件，项目文件仍由用户决定。

## 从 1.1.x 启用 artifact catalog

`-Update` 可以安装 1.2.0 新增的受管脚本和 `.githooks/pre-commit`，但不会改写项目拥有的 `harness.config.json` 与 `tests/harness/README.md`。需要启用目录索引时：

1. 在 `harness.config.json` 增加 `artifactCatalogs` 数组。
2. 在对应 `indexPath` 增加唯一的 `PROJECT-HARNESS:CATALOG:BEGIN/END` 标记区块。
3. 运行 `scripts/update-artifact-catalog.ps1`，再运行 `scripts/verify.ps1 -Scope Harness`。
4. 需要本地提交前反馈时，显式运行 `scripts/install-git-hooks.ps1`；已有其他 `core.hooksPath` 时先人工决定如何整合。

未增加 `artifactCatalogs` 的旧项目会跳过该检查，不会因小版本更新直接失效。

## 为既有 Standard 项目启用计划与经验沉淀

安全更新可以安装新的 `durable-plan`、`knowledge-capture` 工作流和对应受管 Skill，但不会改写项目拥有的 `AGENTS.md`、`harness.config.json` 或文档目录。旧项目需要人工确认后完成：

1. 在 `harness.config.json.requiredPaths` 增加 `docs/workflows/knowledge-capture.md` 和两个 `knowledge-capture` Skill 路径；需要长期经验目录时再增加 `docs/lessons/README.md`。
2. 从当前版本的 `templates/standard/docs/lessons/README.md` 创建项目自己的 Lessons 入口，并按项目需要调整说明。
3. 将 `docs/decisions/README.md` 更新为统一 Decision Record 说明；已有 ADR 文件不需要批量重命名，可在新增或修改时补充 `Type` 和 `Status`。
4. 需要强制长任务计划时，在 `capabilities` 中加入 `durable-plan`，并把当前受管 Harness 规则区块合并到项目 `AGENTS.md`。
5. 运行 `scripts/verify.ps1 -Scope Harness`，确认必需路径、工作流和 Skill 入口完整。

Harness 不为旧项目创建或移动 `code/`、`src/`、`assets/`、`notes/` 等项目目录；onboarding 只记录已有布局。

## 兼容承诺

小版本应保持 schema `1` 和已有模板路径兼容。删除或改变受管文件、配置字段或 Agent 发现路径时，必须提高主版本并在 CHANGELOG 写迁移步骤。
