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
2. 用 v1 初始化器执行一次首次安装；已有文件默认 `SKIP`，不要使用 `-Force` 解决差异。
3. 检查生成的 `harness.config.json`，补充真实项目验证命令和已确认能力。
4. 运行 `scripts/verify.ps1 -Scope Harness`，再按 onboarding 工作流补齐事实。
5. 以后升级先运行 `-Update -WhatIf`。冲突时处理目标仓库的本地修改后再重试。

没有 lock 的旧安装不能安全推断基线，因此 v1 不会自动升级它；重新安装只创建缺失文件，项目文件仍由用户决定。

## 兼容承诺

小版本应保持 schema `1` 和已有模板路径兼容。删除或改变受管文件、配置字段或 Agent 发现路径时，必须提高主版本并在 CHANGELOG 写迁移步骤。
