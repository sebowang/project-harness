# Changelog

本项目遵循语义化版本。每个版本的模板版本来自 `templates/manifest.json`，目标仓库的 `harness.lock.json` 记录已安装版本。

## [1.0.0] - 2026-08-03

### Added

- `Light` / `Standard` 非破坏性初始化，以及 `installed`、`ready`、`ready with waiver` 状态。
- `harness.lock.json` 受管文件基线、`harness-status.ps1` 和 `harness-doctor.ps1`。
- `-Update -WhatIf` 安全更新、受管文件所有权、冲突停止、备份和失败恢复。
- 基于仓库证据的 `project-onboarding` proposal/confirm/apply 工作流。
- 面向大项目的可选 `durable-plan`、架构、数据库和部署风险能力入口。
- Windows PowerShell 5.1 与 PowerShell 7 Smoke Test CI，并完成仓库 dogfooding。

### Not Included

- Cursor、Gemini、GitHub Copilot、OpenSpec、Spec Kit、Superpowers 集成。
- 通用二进制发布物或无法由项目配置验证的安全命令守卫。

## Upgrade Notes

从 0.x 升级前先运行 `-Update -WhatIf`。没有 `harness.lock.json` 的目标仓库应先按首次安装流程安装；升级不会静默覆盖项目所有文件。
