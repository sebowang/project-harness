# Project Harness 项目地图

> 只记录可从源码、配置或已确认材料中验证的当前事实。本文不授权架构变更。

## 仓库类型

PowerShell 脚本仓库，使用 JSON、Markdown 和 GitHub Actions；初始化器目标兼容 Windows PowerShell 5.1 与 PowerShell 7。仓库本身不包含业务运行时。

## 入口

| 入口 | 位置 | 验证依据 |
|---|---|---|
| 初始化器 | `scripts/initialize-project.ps1` | 安装、预览和安全更新模板 | Windows PowerShell 5.1 / PowerShell 7 Smoke Test |

## 模块与职责

| 模块 | 主要位置 | 职责 | 边界与风险 |
|---|---|---|---|
| 模板与清单 | `templates/`、`templates/manifest.json` | 维护 Light/Standard 输出和所有权 | 不写入业务代码 |
| 验证 | `scripts/check-*.ps1`、`scripts/update-artifact-catalog.ps1`、`scripts/verify.ps1`、`tests/initialize-smoke.ps1` | Harness 完整性、artifact catalog、readiness、状态和回归 | 不代表目标项目业务正确 |
| 文档与工作流 | `docs/`、`templates/standard/docs/workflows/` | 规则、事实、流程和能力入口 | 事实必须可由仓库证据复核 |

## 依赖方向

初始化器读取模板清单并生成目标仓库文件；Smoke Test 通过临时仓库验证安装、验证、状态、doctor、WhatIf、更新、新文件和冲突路径。模板不依赖业务项目。

## 共享契约与高风险区域

- 外部边界：GitHub Actions 只运行仓库 Smoke Test；初始化器不执行目标项目命令，项目命令由目标仓库 `harness.config.json` 显式提供。
- Git Hook 是显式、可撤销的本地反馈机制；初始化器不修改 `core.hooksPath`，完整验证仍由 CI 或人工运行 `verify.ps1`。

## 验收路径

| 变更类型 | 所需证据 |
|---|---|
| 文档 | Harness 完整性检查与链接/事实复核 |
| 初始化器/模板 | Windows PowerShell 5.1 与 PowerShell 7 Smoke Test、`git diff --check` |
| 文档/配置 | Harness 检查、readiness 检查、正则漂移检查和人工事实复核 |

## 更新责任

模块归属、依赖方向、共享契约或验收入口变化时，在同一聚焦变更中更新本地图。
