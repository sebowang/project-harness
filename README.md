# Project Harness

面向 AI 辅助研发的通用项目初始化工具。它把仓库规则、架构事实、长期决策、可复用流程和验证入口放进版本控制，让后续 Agent 会话可以基于项目文件工作，而不是依赖聊天记录。

本项目不绑定业务领域、编程语言或应用框架。初始化器使用 PowerShell，适合 Windows 仓库，也可在安装 PowerShell 7 的 macOS/Linux 环境运行。

## 设计目标

- 非破坏性：默认只创建缺失文件，不覆盖已有项目规则。
- 事实优先：模板要求先勘察仓库，不根据目录名猜测架构。
- 验证闭环：提供统一入口，区分 Harness 完整性检查和项目真实测试。
- 控制上下文：稳定知识、长期决策、当前验证和重复流程各有明确载体。
- 渐进采用：提供 `Light` 与 `Standard` 两种初始化级别。

## 快速开始

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

初始化完成后，进入目标仓库执行：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify.ps1 -Scope Harness
```

然后完成两项人工工作：

1. 根据真实源码填写 `docs/project-map.md`，不要保留推测性描述。
2. 在 `harness.config.json` 的 `projectValidation` 中配置项目实际可运行的构建、测试、Lint 或 Smoke Check。

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
harness.config.json
docs/
  project-map.md
  verification.md
  prd/README.md
  decisions/README.md
  reference/README.md
.agents/skills/
  project-start/SKILL.md
  change-plan/SKILL.md
  adversarial-review/SKILL.md
  harness-authoring/SKILL.md
  project-handoff/SKILL.md
scripts/
  check-harness.ps1
  check-doc-drift.ps1
  verify.ps1
tests/harness/README.md
```

默认不创建 `current-task.md`、`session-state.json`、`session-log.md`、`progress-map.md` 等重复状态文件。跨会话长任务确有需要时，由 `project-handoff` Skill 建立单一交接文件即可。

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

## 原则与工作流

- [设计原则](docs/design-principles.md)
- [初始化工作流](docs/initialization-workflow.md)

## 与原始方案的关系

本项目受到 Bow-Lin/project-harness 的分层、会话恢复和验证闭环思想启发，但重新设计了默认文件数量、Codex Skill 路径、Windows 支持、验证入口和安全边界。详见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。

## License

[MIT](LICENSE)
