# Project Harness v1.1.0

面向 AI 辅助研发的通用项目初始化工具。它把仓库规则、架构事实、长期决策、可复用流程和验证入口放进版本控制，让后续 Agent 会话可以基于项目文件工作，而不是依赖聊天记录。

当前模板同时为 Codex、Claude Code 和 Trae 提供项目入口，并使用 `AGENTS.md` 作为唯一规则事实源。

当前发布：`v1.1.0`。发布说明和兼容/迁移边界见 [CHANGELOG.md](CHANGELOG.md)、[发布指南](docs/release.md) 和 [兼容与迁移](docs/compatibility-and-migration.md)。

本项目不绑定业务领域、编程语言或应用框架。初始化器使用 PowerShell，适合 Windows 仓库，也可在安装 PowerShell 7 的 macOS/Linux 环境运行。

## 设计目标

- 非破坏性：默认只创建缺失文件，不覆盖已有项目规则。
- 事实优先：模板要求先勘察仓库，不根据目录名猜测架构。
- 验证闭环：提供统一入口，区分 Harness 完整性检查和项目真实测试。
- 控制上下文：稳定知识、长期决策、当前验证和重复流程各有明确载体。
- 渐进采用：提供 `Light` 与 `Standard` 两种初始化级别。

## 快速开始

### 复制给 Agent

在目标项目的根目录打开 Codex、Claude Code 或支持终端的 Agent，复制以下指令。它不依赖作者电脑上的绝对路径：Agent 会从 GitHub 获取最新稳定 Release 到自己的临时目录，再把 Harness 安装到当前 Git 仓库。

> 在当前 Git 仓库安装 GitHub 仓库 `sebowang/project-harness` 的最新稳定 Release。先检查当前仓库根目录和 `git status --short`，保留所有已有修改；先从 GitHub Releases 解析最新稳定版本并把实际版本号报告给我，再将该版本克隆到系统临时目录，从克隆目录运行 `scripts/initialize-project.ps1 -TargetPath <当前仓库> -Profile Standard`，不得使用 `-Force`，不得修改业务源码、依赖、部署或 Git Hook。安装后执行 `project-onboarding` 的只读 Proposal 阶段：检查已有 `AGENTS.md`、`CLAUDE.md`、CI、构建、测试和项目文档，列出已验证事实、未知项、建议的验证命令与风险能力。不要修改项目所有文件、启用能力或运行外部副作用命令，等待我确认 proposal。

这条指令会安装缺失的 Harness 文件，但会保留已有的项目规则与配置；后续项目化配置仍必须由用户确认。最新版本解析失败或 Release 不是稳定版本时，应停止并报告，不得退回使用 `main`。

### 命令行安装

在本仓库根目录运行：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/initialize-project.ps1 `
  -TargetPath "C:\path\to\your-repository" `
  -Profile Standard
```

PowerShell 7 也可以使用：

```powershell
pwsh -File scripts/initialize-project.ps1 -TargetPath /path/to/repository -Profile Standard
```

以后从本仓库拉取新版本后，用同一个初始化器安全维护目标仓库：

```powershell
# 先预览完整更新计划，不写文件
powershell -ExecutionPolicy Bypass -File scripts/initialize-project.ps1 `
  -TargetPath "C:\path\to\your-repository" -Update -WhatIf

# 确认后执行
powershell -ExecutionPolicy Bypass -File scripts/initialize-project.ps1 `
  -TargetPath "C:\path\to\your-repository" -Update
```

更新只自动替换 lock 基线后未被项目修改的受管文件。双方修改同一路径、文件缺失或新增受管文件与本地路径碰撞时，整次更新会在写入前停止；成功更新前的文件和 lock 保存在 `.harness-backup/<timestamp>/`。

当新版本不再管理旧文件时，默认保留该文件并报告为 `ORPHANED`，不会阻塞其他更新。确认不再需要且文件仍未被本地修改时，显式清理：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/initialize-project.ps1 `
  -TargetPath "C:\path\to\your-repository" -Update -Prune
```

初始化完成后，进入目标仓库执行：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify.ps1 -Scope Harness
```

该命令证明 Harness 已安装且结构可读取，不代表项目已完成配置。初始化器会将新项目报告为 `installed`。

也可以在目标仓库直接告诉 Agent：

> 按 `project-onboarding` 工作流勘察并配置这个仓库；先给我 proposal，不要直接写入。

Agent 会先只读勘察，列出证据、未知项、验证命令候选和风险能力建议。只有你明确确认 proposal 后，它才会修改项目拥有的文件并运行 doctor 与完整验证。

然后完成两项人工工作：

1. 根据真实源码填写 `docs/project-map.md`，不要保留推测性描述。
2. 在 `harness.config.json` 的 `projectValidation` 中配置项目实际可运行的构建、测试、Lint 或 Smoke Check。

完成后运行完整检查：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify.ps1 -Scope All
```

`Standard` 默认要求至少一个项目验证命令。确实没有可运行命令时，可以在 `readiness.projectValidationWaiver` 中记录具体原因；这种状态会报告为 `ready with waiver`，不会伪装成普通验证通过。

## 初始化级别

| 级别 | 适用场景 | 主要内容 |
|---|---|---|
| `Light` | 小型仓库、短期项目、文档项目 | `AGENTS.md`、项目地图、验证指南、统一验证脚本 |
| `Standard` | 长期维护、多人或 Agent 重复参与的仓库 | Light + ADR/PRD/Reference 路由、Harness 规范、仓库级 Skills、文档漂移检查 |

不提供自动化 `Full` 模式。生产发布、数据库、基础设施、昂贵操作和机械安全边界必须根据真实项目配置 CI、权限、审批与 Hook，不应由通用模板猜测。

## 生成结构

Standard 模式会补充以下结构：

```text
AGENTS.md
CLAUDE.md
harness.config.json
harness.lock.json
.trae/rules/project-harness.md
docs/
  harness-configuration.md
  project-map.md
  verification.md
  agent-compatibility.md
  workflows/*.md
  prd/README.md
  decisions/README.md
  reference/README.md
.agents/skills/
  */SKILL.md
.claude/skills/
  */SKILL.md
scripts/
  check-harness.ps1
  check-readiness.ps1
  check-doc-drift.ps1
  harness-status.ps1
  harness-doctor.ps1
  verify.ps1
tests/harness/README.md
```

默认不创建 `current-task.md`、`session-state.json`、`session-log.md`、`progress-map.md` 等重复状态文件。跨会话长任务确有需要时，由 `project-handoff` Skill 建立单一交接文件即可。

## Agent 兼容方式

| 工具 | 自动入口 | 公共工作流入口 |
|---|---|---|
| Codex | `AGENTS.md`、`.agents/skills/` | `docs/workflows/` |
| Claude Code | `CLAUDE.md` 导入 `AGENTS.md`、`.claude/skills/` | `docs/workflows/` |
| Trae | `.trae/rules/project-harness.md` 路由到 `AGENTS.md` | `docs/workflows/` |

各工具专属 Skill 只是薄入口，不复制完整规则。详细设计见 [Agent 兼容策略](docs/agent-compatibility.md)。

## 配置真实验证

`harness.config.json` 使用结构化命令，避免把任意字符串交给 `Invoke-Expression`：

```json
{
  "projectValidation": [
    {
      "name": "Run tests",
      "executable": "dotnet",
      "arguments": ["test", "MyProject.sln", "--no-restore"]
    }
  ]
}
```

配置后运行：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify.ps1 -Scope All
```

只读诊断：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/harness-status.ps1
powershell -ExecutionPolicy Bypass -File scripts/harness-doctor.ps1
```

## 原则与工作流

- [设计原则](docs/design-principles.md)
- [初始化工作流](docs/initialization-workflow.md)
- [Agent 兼容策略](docs/agent-compatibility.md)
- [CI 平台兼容性](docs/ci-platform-compatibility.md)
- [Harness 配置](docs/harness-configuration.md)
- [持续实施计划](docs/implementation-roadmap.md)

## License

[MIT](LICENSE)
