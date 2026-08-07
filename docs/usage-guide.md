# Project Harness 使用指南

本指南解释 Harness 在项目中的完整工作方式。首次使用时先看根目录 `README.md` 的“装好以后怎么用”；不需要为了每个小任务都记住这里的术语。

## 先记住两件事

Harness 不是新的开发框架，也不要求项目调整代码目录。它把原本散落在聊天记录、个人习惯和工具配置里的协作信息，变成项目内可读取、可更新、可验证的文件。

用户不需要指挥 Agent 按顺序运行每个 Skill。日常任务只要说清需求和验收预期；复杂任务、跨会话交接和长期经验沉淀时，再明确提出需要计划、交接或知识发现。

## 四个常见场景

| 场景 | 用户要做什么 | Agent 应做什么 |
|---|---|---|
| 第一次接入 | 预览安装，确认是否合并现有规则 | 勘察仓库并提交项目化 Proposal，不擅自改业务配置 |
| 日常开发 | 描述需求和验收预期 | 恢复相关上下文，实施最小变更并运行验证 |
| 全项目整理 | 明确要求“基线刷新”或“整理整个项目” | 只读审计项目事实与治理文档，先提交差异 Proposal，确认后才更新 |
| 长任务或跨会话 | 明确要求建立计划或交接 | 维护唯一的计划或 handoff 文件，避免多份状态记录 |
| 有价值的经验或决定 | 要求先检查候选，或明确要求记录 | 只检查实际可访问的上下文和仓库证据，路由到一个合适的长期载体 |

可以直接这样说：

> 帮我实现这个功能，并按项目现有规则验证。

> 这个任务会持续几天，先建立计划，再开始实施。

> 把当前进展交接给下一次会话，写清已验证内容、剩余风险和下一步。

> 检查这次讨论有没有值得长期记录的经验，先列候选和建议位置，不要修改文件。

## Agent 的完整工作闭环

以下流程描述 Harness 内部如何把一次较完整的开发任务收束起来。它是默认工作方式，不要求用户逐步下指令。

1. **接入与勘察**：安装时先用 `-WhatIf` 预览。已有 `AGENTS.md` 时，用户确认是否使用 `-MergeProjectRules`。之后 Agent 通过 `project-onboarding` 从源码和现有文档识别真实目录、模块边界、构建入口、验证命令和风险能力；写入项目配置前先提交 Proposal。后续只有用户明确要求“基线刷新”或“整理整个项目”时，才重新进行全量审计；日常开发不自动重写项目地图。
2. **开始任务**：`project-start` 读取项目规则、项目地图、验证指南，以及与任务相关的需求、决策、参考资料、经验和现有 handoff。
3. **规划变更**：非简单任务使用 `change-plan` 明确目标、范围、不可接受行为和验证方式。项目启用 `durable-plan` 后，跨会话、多阶段、高风险或多模块依赖任务必须先创建或恢复唯一的 `docs/active-plan.md`。
4. **实施与验证**：Agent 保留工作树已有修改，只进行与任务直接相关的改动，并运行风险相称的构建、测试、Lint 或 Smoke Check。
5. **审查与交付**：高风险或共享行为变更使用 `adversarial-review` 检查回归、范围漂移和缺失验证，最后运行 `scripts/verify.ps1 -Scope All`。
6. **知识沉淀或交接**：需要延续给下一次会话时，`project-handoff` 维护唯一的 `docs/handoff.md`。有长期价值的结论按下表迁移到正式文档，而不是永久留在计划或交接文件中。

## 信息应该放在哪里

| 内容 | 主要位置 | 使用边界 |
|---|---|---|
| 必须长期遵守的研发规则 | `AGENTS.md` | 保持简短、稳定；项目专属规则放在 Harness 受控区块外 |
| 产品目标、范围和验收条件 | `docs/prd/` | 描述用户需要什么，不代替技术决策 |
| 长期选择和系统不变量 | `docs/decisions/` | 使用统一 Decision Record；`Type` 为 `System Invariant` 或 `Architecture Decision` |
| 当前架构、模块和接口事实 | `docs/project-map.md`、`docs/reference/` | 必须能从源码、接口或环境复核 |
| 用户纠正、重复失败和可复用教训 | `docs/lessons/` | 不冒充规则、事实或临时日志 |
| 已稳定复用的执行流程 | `docs/workflows/` 和对应 Skill | 至少两次独立成功复用，并有清楚的输入、输出和验证方式 |
| 当前长任务状态 | `docs/active-plan.md` | 只保留一个；小任务不创建空计划 |
| 跨会话交接状态 | `docs/handoff.md` | 只保留一个；完成后归档或删除 |

不要把所有内容都写进 `AGENTS.md`，也不要把一次性经验立即制作成 Skill。详细分类规则见 [Knowledge Capture 工作流](workflows/knowledge-capture.md)、[Decision Record 指南](decisions/README.md) 和 [Lessons 指南](lessons/README.md)。

## 发现和沉淀知识

用户不需要记关键词，可以自然地提出“检查、记录、沉淀”这类请求。Agent 必须先说明实际可检查的范围：只包括当前可读取的对话上下文和仓库证据，不能凭印象补写无法访问的历史会话。

仅要求检查或列候选时，Agent 只报告候选、证据、建议位置和不沉淀风险，不修改文件。用户明确要求记录或更新时，Agent 才会完成分类并写入；分类会明显改变结果时，应先展示建议并请求确认。

即使用户提出“固化为 Skill”，也不应立刻创建。一个流程至少应有两次独立成功复用，并能说清输入、步骤、失败信号、验证方式和不适用范围，才适合成为 Skill。

## 用户仍需要确认的事情

- 选择 `Light` 或 `Standard`，以及是否把 Harness 规则合并进已有 `AGENTS.md`。
- 审核 `project-onboarding` Proposal，确认模块边界、验证命令、风险能力和知识目录符合真实项目。
- 在 `harness.config.json.projectValidation` 中维护真实可执行的构建、测试、Lint 或 Smoke Check。
- 决定是否启用 `durable-plan` 等能力，以及是否显式安装本地 Git Hook。
- 将 `scripts/verify.ps1 -Scope All` 接入项目 CI；本地 Hook 可以跳过，不能代替 CI、权限或审批。
- 更新 Harness 前先用 `-Update -WhatIf` 查看计划，处理本地修改冲突和 `ORPHANED` 文件后再执行更新。
- 对生产发布、数据库迁移、外部消息、付费操作等高影响行为继续使用项目自己的权限、审批和回滚机制。

## 让 Agent 安装 / 更新 Harness（完整指令）

以下指令是根目录 `README.md` 中精简版的完整形态，包含全部边界条件。目标仓库的 Agent 无法访问本仓库聊天记录，指令必须自包含。

### 完整安装指令

> 在当前 Git 仓库安装 GitHub 仓库 `sebowang/project-harness` 的最新稳定 Release。先检查当前仓库根目录和 `git status --short`，保留所有已有修改；先从 GitHub Releases 解析最新稳定版本并把实际版本号报告给我，再将该版本克隆到系统临时目录，从克隆目录运行 `scripts/initialize-project.ps1 -TargetPath <当前仓库> -Profile Standard -WhatIf`。默认安装不得覆盖已有文件；如果目标仓库已有 `AGENTS.md`，再用 `-MergeProjectRules -WhatIf` 预览受控区块合并并报告保留范围，确认后使用 `-MergeProjectRules` 执行；如果预览显示受管入口（例如 `CLAUDE.md`）与模板冲突，先报告冲突并等待确认，确认后使用 `-Force` 执行受管文件迁移。不得自动修改业务源码、依赖、部署或 Git 配置；安装后执行 `project-onboarding` 的只读 Proposal 阶段，必须明确报告本地 Hook 是否启用、它会检查的暂存 artifact catalog 和文档漂移断言、是否建议启用及冲突风险。不要启用能力或运行外部副作用命令，等待我确认 proposal。

### 完整更新指令

> 在当前 Git 仓库更新 Project Harness。先确认仓库根目录、`git status --short`、`harness.lock.json` 和当前 Harness 版本，保留所有已有修改。先从 GitHub Releases 解析最新稳定 Release 并报告实际版本号，再将该固定版本克隆到系统临时目录，从克隆目录运行 `scripts/initialize-project.ps1 -TargetPath <当前仓库> -Update -WhatIf`。报告计划更新的文件、已修改或缺失的受管文件、冲突、`ORPHANED` 文件、缺失 project-owned 模板、配置版本差异、`AGENTS.md` 受控区块是否落后、备份位置和预计影响；不要使用 `-Force` 解决 `-Update` 冲突，不要改写项目拥有的 `AGENTS.md` 区块外内容、`harness.config.json`、项目地图、验证文档或业务源码。若确认需要刷新 `AGENTS.md` 受控区块，再单独预览 `-Update -MergeProjectRules -WhatIf`，确认后才使用 `-Update -MergeProjectRules`；其他项目拥有文件仍只报告，不自动创建。等待我确认预览结果后才执行对应更新。更新完成后运行 `scripts/harness-doctor.ps1` 和 `scripts/verify.ps1 -Scope Harness`；只有项目验证配置已确认且实际通过时，才运行并报告 `scripts/verify.ps1 -Scope All`。不要自动安装依赖、启用 Git Hook、修改 CI 或执行部署操作。
