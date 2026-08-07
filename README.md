# Project Harness v1.3.6

[中文](README.md) | [English](README.en.md)

> **换人、换 Agent、隔一周再打开项目——上下文不再丢。**
> 之前聊清楚的规则、决定和验证方式，全部写进仓库。任何人或任何 Agent 接手时，都能从仓库恢复上下文，而不是依赖上一段聊天记录。

当前版本：`v1.3.6`。发布说明和兼容/迁移边界见 [CHANGELOG.md](CHANGELOG.md)、[发布指南](docs/release.md) 和 [兼容与迁移](docs/compatibility-and-migration.md)。

## 亮点速览

Project Harness 是一套非破坏性的 AI 辅助开发初始化工具：默认只创建缺失文件，不覆盖已有规则。装上之后你会得到：

- **上下文不再丢**：规则、项目事实、重要决定和验证命令全部进版本控制。换人、换工具、隔段时间，都从仓库恢复上下文，而不是依赖上一段对话。
- **一键让 Agent 安装**：复制一段指令交给 Codex、Claude Code 或 Trae，它自己解析版本、克隆、预览安装计划，等你确认后才写入。
- **不破坏已有内容**：默认只创建缺失文件；已有 `AGENTS.md` 时，只把 Harness 规则接入受控区块，区块外内容一律不动。
- **一套规则，多个 AI 工具共用**：Codex、Claude Code、Trae 读同一份规则，行为一致；统一验证入口让"检查项目是否就绪"只跑一条命令。
- **装上就有自动检查**：提交前自动检查有没有改漏、文档是否一致；Agent 交付前自动自查缺陷、回归和验证缺口。
- **按需渐进**：从 `Light` 开始，项目复杂后再升级 `Standard`；计划、交接和经验记录只在需要时创建。

它不替你设计业务架构，也不猜测构建命令。模板不预设业务领域、语言或框架；初始化器用 PowerShell，Windows 可直接运行，macOS/Linux 安装 PowerShell 7 后也能用。

## 它解决什么问题

AI 辅助开发最大的隐性成本是上下文丢失。上个月让 Agent 写了接口，这个月换人接手，对方问的还是那几个问题：构建命令是什么、代码放在哪、有什么约定。

Project Harness 把答案写进仓库，并把"验证"固化成可重复的自动检查点——装完、提交前、交付前各有一道对应检查，但每一步都留人工确认窗口。

## 它适合谁 / 何时用

**适合**：长期项目；多人或多个 Agent 反复接手的仓库；会跨会话进行的复杂任务；被"每次都要重新解释一遍"消耗的团队。

**不适合**：一次性脚本；从不用 AI Agent 的小项目；已经有了完善治理体系、不需要改变工作流的仓库。

**边界**：它不替代测试、CI、权限或审批，也不规定你的代码目录怎么写。`code/`、`src/`、`assets/`、`notes/` 等目录继续由项目自己维护，Harness 只记录真实布局和责任边界。

## 快速开始

### 方式一：让 Agent 一键安装（推荐）

在目标仓库打开 Codex、Claude Code 或其他能用终端的 Agent，把下面这段指令交给它。Agent 会从 GitHub 获取最新稳定 Release，先预览安装计划、报告会保留什么，等你确认后才写入——不依赖作者电脑上的任何路径。

<details>
<summary>展开并复制安装指令</summary>

> 在当前 Git 仓库安装 GitHub 仓库 `sebowang/project-harness` 的最新稳定 Release。先检查仓库根目录和 `git status --short`，保留所有已有修改；从 GitHub Releases 解析最新稳定版本并报告实际版本号，再克隆该版本到系统临时目录，从克隆目录运行 `scripts/initialize-project.ps1 -TargetPath <当前仓库> -Profile Standard -WhatIf`。默认不得覆盖已有文件；目标已有 `AGENTS.md` 时，用 `-MergeProjectRules -WhatIf` 预览受控区块合并并报告保留范围，确认后再执行；受管入口与模板冲突时先报告并等待确认，确认后才可用 `-Force`。不得自动修改业务源码、依赖、部署或 Git 配置。安装后执行 `project-onboarding` 的只读 Proposal 阶段，报告本地 Hook 状态与冲突风险，不启用能力、不运行外部副作用命令，等待确认。

</details>

找不到稳定 Release 时，Agent 应停止并报告，不能退回 `main`。带全部边界条件的完整指令见 [docs/usage-guide.md](docs/usage-guide.md)。

### 方式二：手动命令

三步完成基础安装：

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

### 安装后完成项目配置

安装完成后还差两步，Harness 才对你的项目真正有用：

1. 不需要自己知道构建或测试命令。让 Agent 按 `project-onboarding` 工作流以只读方式勘察仓库并给出 Proposal；它基于已有源码、CI 和本机工具给出可确认的配置草案，你确认后它才会写入项目文件。
2. 根据真实源码填写 `docs/project-map.md`，并在 `harness.config.json` 的 `projectValidation` 中配置项目实际可运行的构建、测试、Lint 或 Smoke Check；为命令标注 `kind`，编译型项目在 `readiness.requiredValidationKinds` 声明 `build`。

然后运行完整检查：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify.ps1 -Scope All
```

`Standard` 至少需要一个项目验证命令。确实没有可运行命令，或编译型项目缺少可执行的 `build` 证据时，可以在 `readiness.projectValidationWaiver` 写明原因；状态会显示为 `ready with waiver`，而不是普通的通过状态。

## 装上后它会自动做什么

Harness 把"检查"做成可重复的自动检查点，但每一步都留人工确认窗口，不会在你不知情时改动内容。

| 能力 | 它自动做什么 | 边界 |
|---|---|---|
| **提交前自动检查**（可选） | git 提交时自动运行两个检查：验收脚本索引是否同步、文档是否发生漂移，拦住"改漏了 / 文档不一致"的提交 | 不自动安装，需要时用 `scripts/install-git-hooks.ps1` 显式启用；只检查 Harness 资产和文档一致性，不跑业务测试 |
| **交付前自动审查** | Agent 完成变更后、交付前，按 `adversarial-review` 工作流自查：缺陷、回归、范围漂移、验证缺口 | 是 Agent 遵循的工作流，不是 CI 门禁；在任务中说明期望时生效 |
| **统一验证入口** | 一条命令检查 Harness 结构（`-Scope Harness`）、项目准备状态和真实验证命令（`-Scope All`） | `-Scope All` 只在配置了项目验证命令后才有意义 |
| **只读诊断** | 报告安装状态、定位缺口，方便排查 | 只读，不改任何文件 |

`-Scope Harness` 只证明 Harness 已安装且入口可读取，不代表项目能通过真实构建或测试。Hook、测试、CI、权限和审批不能互相替代。

## 装好以后怎么用

Harness 不改变你的代码目录，也不规定你怎么写代码。换人、换 Agent 或隔一段时间再继续开发时，大家仍能找到同一套规则、项目事实和验证入口。几种常见场景：

| 场景 | 做法 |
|---|---|
| 第一次接入项目 | 先用 `-WhatIf` 预览；已有 `AGENTS.md` 时决定是否用 `-MergeProjectRules`。安装后让 Agent 先勘察项目，确认它识别出的代码结构和验证命令。 |
| 日常开发 | 直接说清需求和验收，例如"帮我实现这个功能，并按项目现有规则验证"。Agent 先读取项目上下文，再实施和验证。 |
| 全项目整理 | 明确说"请做一次基线刷新"或"整理整个项目"。Agent 先只读审计源码与治理文档、列出差异 Proposal；你确认后才更新项目地图等语义文档。 |
| 复杂或持续较久的任务 | 说"这个任务会持续几天，先建立计划"或"把当前进展交接给下一次会话"。只有跨会话、多阶段或高风险任务才需要维护计划和交接文件。 |
| 想保留经验或决定 | 说"检查这次讨论有没有值得长期记录的经验，先列候选，不要直接写文件"。确认后 Agent 才会把结论放进正确的项目文档。 |

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

更新 Harness 用同一个初始化器，先预览后执行。

### 方式一：让 Agent 帮你更新

在已安装 Harness 的目标仓库，把下面这段指令交给 Agent：

<details>
<summary>展开并复制更新指令</summary>

> 在当前 Git 仓库更新 Project Harness。先确认仓库根目录、`git status --short`、`harness.lock.json` 和当前 Harness 版本，保留所有已有修改。从 GitHub Releases 解析最新稳定 Release 并报告实际版本号，再克隆该版本到系统临时目录，从克隆目录运行 `scripts/initialize-project.ps1 -TargetPath <当前仓库> -Update -WhatIf`。报告计划更新的文件、本地已修改或缺失的受管文件、冲突、`ORPHANED` 文件、备份位置和预计影响；不要用 `-Force` 解决 `-Update` 冲突，不要改写项目拥有的 `AGENTS.md` 区块外内容、`harness.config.json`、项目地图、验证文档或业务源码。需要刷新 `AGENTS.md` 受控区块时，先预览 `-Update -MergeProjectRules -WhatIf`，确认后才执行。等待我确认预览结果后才执行对应更新。更新后运行 `scripts/harness-doctor.ps1` 和 `scripts/verify.ps1 -Scope Harness`；只有项目验证配置已确认且实际通过时，才运行 `-Scope All`。不要自动安装依赖、启用 Git Hook、修改 CI 或执行部署操作。

</details>

带全部边界条件的完整指令见 [docs/usage-guide.md](docs/usage-guide.md)。

### 方式二：手动更新

```powershell
# 先预览完整更新计划，不写文件
powershell -ExecutionPolicy Bypass -File scripts/initialize-project.ps1 `
  -TargetPath "C:\path\to\your-repository" -Update -WhatIf

# 确认后执行
powershell -ExecutionPolicy Bypass -File scripts/initialize-project.ps1 `
  -TargetPath "C:\path\to\your-repository" -Update
```

更新只替换自上次安装后未被本地修改的受管文件。出现双方都改过同一路径、文件缺失或路径冲突时，更新在写入前停止；原文件和 lock 会备份到 `.harness-backup/<timestamp>/`。新版本不再管理的旧文件默认保留并标记为 `ORPHANED`，确认不再需要且未被本地修改时，用 `-Prune` 显式清理。

`-Update` 只更新 Harness 受管文件和 lock 基线，不会自动配置项目构建、测试、依赖或 CI。没有 `harness.lock.json` 的旧安装不能安全推断本地基线，应先报告并选择重新安装或人工迁移。

可选能力：

- **验收脚本索引**：Standard 默认把 `tests/harness/*.ps1` 列入受管索引。新增或删除脚本后运行 `scripts/update-artifact-catalog.ps1`；统一验证入口会检查索引是否同步。
- **提交前自动检查**：`scripts/install-git-hooks.ps1`，`-Uninstall` 卸载。它检查暂存的验收脚本索引和已配置文档漂移断言，只在 `core.hooksPath` 未配置或已为 `.githooks` 时工作，不覆盖项目已有 Hook；初始化不会自动安装，CI 仍应运行完整检查。
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

配置后运行完整检查做最终验证。

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
