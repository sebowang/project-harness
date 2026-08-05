# Project Harness v1.3.3

[中文](README.md) | [English](README.en.md)

> 换一个人、换一个 AI Agent，或者隔一周再打开项目——之前聊清楚的规则、决定和验证方式，全留在聊天记录里，别人接不住。
> Project Harness 把这些写进仓库，让任何人或任何 Agent 接手时，都能从仓库里恢复上下文，而不是依赖上一段对话。

Project Harness 是一套非破坏性的 AI 辅助开发初始化工具：默认只创建缺失文件，不覆盖已有规则。Codex、Claude Code 和 Trae 读取同一份 `AGENTS.md` 规则，共用一个 `verify.ps1` 验证入口。

当前版本：`v1.3.3`。发布说明和兼容/迁移边界见 [CHANGELOG.md](CHANGELOG.md)、[发布指南](docs/release.md) 和 [兼容与迁移](docs/compatibility-and-migration.md)。

## 它解决什么问题

AI 辅助开发最大的隐性成本是上下文丢失。上个月你让 Agent 写了接口，这个月换人接手时，对方的第一个问题还是那几个：构建命令是什么、代码放在哪、有没有约定。

Project Harness 的做法：

- **把上下文留在仓库里**：规则、项目事实、重要决定和验证命令都进版本控制，不依赖任何一段聊天记录。
- **不破坏已有内容**：默认只创建缺失文件；已有 `AGENTS.md` 时，可以只把 Harness 规则接入受控区块，区块外内容不动。
- **多工具共用一套规则**：Codex、Claude Code、Trae 都从 `AGENTS.md` / `docs/workflows/` 读取同一份约定。
- **一个验证入口**：`verify.ps1` 同时检查 Harness 结构、项目准备状态和真实配置的验证命令。
- **按需渐进**：从 `Light` 开始，项目变复杂后再用 `Standard`；计划、交接和经验记录只在需要时创建。

它不替你设计业务架构，也不猜测构建命令。模板不预设业务领域、语言或框架。初始化器用 PowerShell：Windows 可直接运行，macOS/Linux 安装 PowerShell 7 后也能用。

## 快速开始

在目标项目仓库根目录运行，三步完成基础安装：

```powershell
# 1. 预览安装计划，不写任何文件
powershell -ExecutionPolicy Bypass -File scripts/initialize-project.ps1 `
  -TargetPath "C:\path\to\your-repository" -Profile Standard -WhatIf

# 2. 确认后执行安装
powershell -ExecutionPolicy Bypass -File scripts/initialize-project.ps1 `
  -TargetPath "C:\path\to\your-repository" -Profile Standard

# 3. 检查 Harness 是否就绪
powershell -ExecutionPolicy Bypass -File scripts/verify.ps1 -Scope Harness
```

PowerShell 7 环境改用 `pwsh -File ...`，路径写成 `/path/to/repository`。

**已有 `AGENTS.md` 的项目**：默认不会改动它。希望把 Harness 规则接入同一份文件时，安装追加 `-MergeProjectRules`。初始化器只新增或刷新 `<!-- PROJECT-HARNESS:BEGIN -->` 与 `<!-- PROJECT-HARNESS:END -->` 之间的受控区块，区块外规则保持不变，首次写入前备份原文件。

`verify.ps1 -Scope Harness` 只说明 Harness 已安装且入口可读取，不代表项目能通过真实构建或测试。

### 让 Agent 帮你安装

在目标仓库打开 Codex、Claude Code 或其他能使用终端的 Agent，把下面这段指令交给它。Agent 会从 GitHub 获取最新稳定 Release 并安装到当前 Git 仓库，不依赖作者电脑上的路径。

<details>
<summary>展开并复制完整安装指令</summary>

> 在当前 Git 仓库安装 GitHub 仓库 `sebowang/project-harness` 的最新稳定 Release。先检查当前仓库根目录和 `git status --short`，保留所有已有修改；先从 GitHub Releases 解析最新稳定版本并把实际版本号报告给我，再将该版本克隆到系统临时目录，从克隆目录运行 `scripts/initialize-project.ps1 -TargetPath <当前仓库> -Profile Standard -WhatIf`。默认安装不得覆盖已有文件；如果目标仓库已有 `AGENTS.md`，再用 `-MergeProjectRules -WhatIf` 预览受控区块合并并报告保留范围，确认后使用 `-MergeProjectRules` 执行；如果预览显示受管入口（例如 `CLAUDE.md`）与模板冲突，先报告冲突并等待确认，确认后使用 `-Force` 执行受管文件迁移。不得自动修改业务源码、依赖、部署或 Git 配置；安装后执行 `project-onboarding` 的只读 Proposal 阶段，必须明确报告本地 catalog Hook 是否启用、是否建议启用及冲突风险。不要启用能力或运行外部副作用命令，等待我确认 proposal。

</details>

安装保留已有的项目规则和配置。只有在你确认后才会用 `-Force` 迁移受管文件，迁移前会备份旧文件。找不到稳定 Release 时，Agent 应停止并报告，不能退回使用 `main`。

### 安装后完成项目配置

安装完成后还差两步，Harness 才对你的项目真正有用：

1. 让 Agent 按 `project-onboarding` 工作流以只读方式勘察仓库并给出 Proposal，你确认后它才会写入项目文件。
2. 根据真实源码填写 `docs/project-map.md`，并在 `harness.config.json` 的 `projectValidation` 中配置项目实际可运行的构建、测试、Lint 或 Smoke Check；为命令标注 `kind`，编译型项目在 `readiness.requiredValidationKinds` 声明 `build`。

然后运行完整检查：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify.ps1 -Scope All
```

`Standard` 至少需要一个项目验证命令。确实没有可运行命令，或编译型项目缺少可执行的 `build` 证据时，可以在 `readiness.projectValidationWaiver` 写明原因；状态会显示为 `ready with waiver`，而不是普通的通过状态。

## 装好以后怎么用

Harness 不改变你的代码目录，也不规定你怎么写代码。换人、换 Agent 或隔一段时间再继续开发时，大家仍能找到同一套规则、项目事实和验证入口。四种常见场景：

| 场景 | 做法 |
|---|---|
| 第一次接入项目 | 先用 `-WhatIf` 预览；已有 `AGENTS.md` 时决定是否用 `-MergeProjectRules`。安装后让 Agent 先勘察项目，确认它识别出的代码结构和验证命令。 |
| 日常开发 | 直接说清需求，例如“帮我实现这个功能，并按项目现有规则验证”。Agent 先读取项目上下文，再实施和验证。 |
| 复杂或持续较久的任务 | 说“这个任务会持续几天，先建立计划”或“把当前进展交接给下一次会话”。只有跨会话、多阶段或高风险任务才需要维护计划和交接文件。 |
| 想保留经验或决定 | 说“检查这次讨论有没有值得长期记录的经验，先列候选，不要直接写文件”。确认后 Agent 才会把结论放进正确的项目文档。 |

有几件事仍由项目自己决定：真实可运行的构建/测试命令、是否合并已有规则、是否启用本地 Hook，以及生产操作的权限、审批和回滚方式。Harness 不能替代测试、CI、权限或审批。

用户不需要按照 Harness 规定整理源码目录。`code/`、`src/`、`assets/`、`notes/` 等目录继续由目标项目自行维护，Harness 只记录真实布局和责任边界。

想了解完整机制、文件放在哪里或每个工作流何时生效，请阅读 [详细使用指南](docs/usage-guide.md)。

## 初始化级别

| 级别 | 适用场景 | 包含内容 |
|---|---|---|
| `Light` | 小型仓库、短期项目、文档项目 | `AGENTS.md`、项目地图、验证指南、统一验证脚本 |
| `Standard` | 长期项目，或多人和多个 Agent 会反复接手的仓库 | Light + 工作流、Skill、需求、决定、经验记录、文档检查、验收脚本索引、可选 Hook |

没有通用的自动化 `Full` 模式。生产发布、数据库、基础设施和付费操作等高影响事项，仍要按真实项目配置 CI、权限、审批和 Hook。

<details>
<summary>Standard 模式生成的结构</summary>

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
  lessons/README.md
.agents/skills/
  */SKILL.md
.claude/skills/
  */SKILL.md
scripts/
  check-artifact-catalog.ps1
  update-artifact-catalog.ps1
  install-git-hooks.ps1
  check-harness.ps1
  check-readiness.ps1
  check-doc-drift.ps1
  harness-status.ps1
  harness-doctor.ps1
  verify.ps1
tests/harness/README.md
.githooks/pre-commit
```

</details>

小任务不需要创建计划或交接文件。跨会话长任务才维护一个交接文件；启用 `durable-plan` 后，命中跨会话、多阶段、高风险或多模块依赖条件的任务才维护一个 `docs/active-plan.md`。

## 更新与维护

更新 Harness 用同一个初始化器，先预览后执行：

```powershell
# 先预览完整更新计划，不写文件
powershell -ExecutionPolicy Bypass -File scripts/initialize-project.ps1 `
  -TargetPath "C:\path\to\your-repository" -Update -WhatIf

# 确认后执行
powershell -ExecutionPolicy Bypass -File scripts/initialize-project.ps1 `
  -TargetPath "C:\path\to\your-repository" -Update
```

更新只替换自上次安装后未被本地修改的受管文件。出现双方都改过同一路径、文件缺失或路径冲突时，更新在写入前停止；原文件和 lock 会备份到 `.harness-backup/<timestamp>/`。新版本不再管理的旧文件默认保留并标记为 `ORPHANED`，确认不再需要且未被本地修改时，用 `-Prune` 显式清理。Update plan 还会列出需要项目确认的缺失 project-owned 模板、配置版本差异和落后的 `AGENTS.md` 受控区块；需要刷新后者时，在预览和确认后追加 `-MergeProjectRules`。

### 让 Agent 帮你更新

在已安装 Harness 的目标仓库中，可以直接把下面这段自然语言指令交给 Agent：

<details>
<summary>展开并复制更新指令</summary>

> 在当前 Git 仓库更新 Project Harness。先确认仓库根目录、`git status --short`、`harness.lock.json` 和当前 Harness 版本，保留所有已有修改。先从 GitHub Releases 解析最新稳定 Release 并报告实际版本号，再将该固定版本克隆到系统临时目录，从克隆目录运行 `scripts/initialize-project.ps1 -TargetPath <当前仓库> -Update -WhatIf`。报告计划更新的文件、已修改或缺失的受管文件、冲突、`ORPHANED` 文件、缺失 project-owned 模板、配置版本差异、`AGENTS.md` 受控区块是否落后、备份位置和预计影响；不要使用 `-Force` 解决 `-Update` 冲突，不要改写项目拥有的 `AGENTS.md` 区块外内容、`harness.config.json`、项目地图、验证文档或业务源码。若确认需要刷新 `AGENTS.md` 受控区块，再单独预览 `-Update -MergeProjectRules -WhatIf`，确认后才使用 `-Update -MergeProjectRules`；其他项目拥有文件仍只报告，不自动创建。等待我确认预览结果后才执行对应更新。更新完成后运行 `scripts/harness-doctor.ps1` 和 `scripts/verify.ps1 -Scope Harness`；只有项目验证配置已确认且实际通过时，才运行并报告 `scripts/verify.ps1 -Scope All`。不要自动安装依赖、启用 Git Hook、修改 CI 或执行部署操作。`

</details>

`-Update` 只更新 Harness 受管文件和 lock 基线，不会自动配置项目构建、测试、依赖或 CI。没有 `harness.lock.json` 的旧安装不能安全推断本地基线，应先报告并选择重新安装或人工迁移。

可选能力：

- **验收脚本索引**：Standard 默认把 `tests/harness/*.ps1` 列入受管索引。新增或删除脚本后运行 `scripts/update-artifact-catalog.ps1`；`verify.ps1 -Scope Harness` 会检查索引是否同步。
- **本地 pre-commit Hook**：`scripts/install-git-hooks.ps1`，`-Uninstall` 卸载。只在 `core.hooksPath` 未配置或已为 `.githooks` 时工作，不覆盖项目已有 Hook；初始化不会自动安装，CI 仍应运行 `scripts/verify.ps1 -Scope All`。
- **只读诊断**：`scripts/harness-status.ps1` 和 `scripts/harness-doctor.ps1`。

## Agent 兼容

| 工具 | 自动入口 | 公共工作流入口 |
|---|---|---|
| Codex | `AGENTS.md`、`.agents/skills/` | `docs/workflows/` |
| Claude Code | `CLAUDE.md` 导入 `AGENTS.md`、`.claude/skills/` | `docs/workflows/` |
| Trae | `.trae/rules/project-harness.md` 路由到 `AGENTS.md` | `docs/workflows/` |

各工具的 Skill 入口只负责找到公共工作流，不复制完整规则。详细说明见 [Agent 兼容策略](docs/agent-compatibility.md)。

## 配置真实验证

在 `harness.config.json` 的 `projectValidation` 中分别配置证据类型、可执行文件和参数，Harness 才能可靠地运行项目验证命令：

```json
{
  "projectValidation": [
    {
      "name": "Run tests",
      "kind": "test",
      "executable": "dotnet",
      "arguments": ["test", "MyProject.sln", "--no-restore"]
    }
  ]
}
```

配置后运行 `scripts/verify.ps1 -Scope All` 做完整检查。

## 原则与工作流

- [设计原则](docs/design-principles.md)
- [初始化工作流](docs/initialization-workflow.md)
- [详细使用指南](docs/usage-guide.md)
- [Knowledge Capture 工作流](docs/workflows/knowledge-capture.md)
- [Decision Record 指南](docs/decisions/README.md)
- [Lessons 指南](docs/lessons/README.md)
- [Agent 兼容策略](docs/agent-compatibility.md)
- [CI 平台兼容性](docs/ci-platform-compatibility.md)
- [Harness 配置](docs/harness-configuration.md)
- [持续实施计划](docs/implementation-roadmap.md)

## License

[MIT](LICENSE)
