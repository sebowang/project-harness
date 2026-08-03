# Changelog

本项目遵循语义化版本。每个版本的模板版本来自 `templates/manifest.json`，目标仓库的 `harness.lock.json` 记录已安装版本。

## [1.1.1] - 2026-08-04

### Fixed

- 中立性检查改为覆盖任意盘符的 Windows 绝对路径与 Unix 绝对路径，并保留通用文档占位路径。
- 移除对历史项目名称的封闭式禁用词检查。
- 明确 `verify.ps1`、`harness-status.ps1` 以及非受管 CI 示例的职责边界。

## [1.1.0] - 2026-08-04

### Added

- GitLab CI 与 CNB（cnb.cool）参考示例，以及 CI 平台兼容性说明。
- onboarding 只读识别 Git remote 和已有 CI 文件，并在 proposal 中提出平台建议。

### Changed

- CI 示例不会默认写入目标项目；统一验证入口仍由目标仓库的 `scripts/verify.ps1 -Scope All` 配置决定。

## [1.0.4] - 2026-08-03

### Fixed

- Smoke Test 成功完成后显式返回退出码 `0`，避免 Linux PowerShell 将故意失败的负向断言遗留为整个测试的失败状态。

## [1.0.3] - 2026-08-03

### Fixed

- Smoke Test 会根据当前平台使用可发现的 `powershell` 或 `pwsh` 执行项目验证。

## [1.0.2] - 2026-08-03

### Fixed

- Linux/macOS PowerShell 初始化现在会正确枚举并安装 `.trae/rules/` 等隐藏模板路径。

## [1.0.1] - 2026-08-03

### Fixed

- `-Force` 现在只覆盖 manifest 标记为 `managed` 的模板文件，不再覆盖 `AGENTS.md`、项目文档、`harness.config.json` 或既有 lock。
- 统一 Windows 与跨平台路径分隔符后再判断模板所有权。

## [1.0.0] - 2026-08-03

### Added

- `Light` / `Standard` 非破坏性初始化，以及 `installed`、`ready`、`ready with waiver` 状态。
- `harness.lock.json` 受管文件基线、`harness-status.ps1` 和 `harness-doctor.ps1`。
- `-Update -WhatIf` 安全更新、受管文件所有权、冲突停止、备份和失败恢复；上游移除文件默认保留为 `ORPHANED`，显式 `-Prune` 仅清理未修改文件。
- 基于仓库证据的 `project-onboarding` proposal/confirm/apply 工作流。
- 面向大项目的可选 `durable-plan`、架构、数据库和部署风险能力入口，以及测试、系统化调试和跨会话计划工作流。
- Codex、Claude Code 与 Trae 的项目规则入口，其中 Trae 使用 `.trae/rules/` 路由到 `AGENTS.md`。
- 模板中立性检查、Windows PowerShell 5.1 与 PowerShell 7 Smoke Test CI，并完成仓库 dogfooding。

### Not Included

- Cursor、Gemini、GitHub Copilot、OpenSpec、Spec Kit、Superpowers 集成。
- 通用二进制发布物或无法由项目配置验证的安全命令守卫。

## Upgrade Notes

从 0.x 升级前先运行 `-Update -WhatIf`。没有 `harness.lock.json` 的目标仓库应先按首次安装流程安装；升级不会静默覆盖项目所有文件。
