# Project Harness 协作指南

## 项目目标

本仓库维护一套通用、非破坏性的 AI 辅助研发初始化方案。发布到本仓库的模板、脚本与示例必须保持领域、语言和框架中立，不得嵌入私有项目代码、名称、路径或业务约定。该限制不适用于安装后的目标仓库：目标项目可以并且应当保留自身的私有代码、名称、路径和业务约定。

`AGENTS.md` 是跨工具协作规则的唯一事实来源。`CLAUDE.md` 只负责导入它；`.agents/skills/`、`.claude/skills/` 只负责把各工具路由到 `docs/workflows/` 中的公共流程。

<!-- PROJECT-HARNESS:BEGIN -->
## Project Harness 集成

以下区块由 Project Harness 管理。`AGENTS.md` 仍是项目协作规则的唯一事实来源；项目专属规则保留在区块外，由项目维护。重新合并时只更新本区块。

- 修改前阅读 `docs/project-map.md`、`docs/verification.md`，以及与任务相关的需求、决策、参考资料和模块 README。
- 已有项目规则与 Harness 工作流重叠时，保留项目规则为事实源；本区块只提供 Harness 入口、边界和验证要求，不复制第二份同义正文。
- 目标项目的源码、素材和临时记录目录由项目自己决定；不要因为 Harness 模板创建、移动或重命名 `code/`、`src/`、`assets/`、`notes/` 等目录。
- 开始实施、规划、调试、测试、审查或交接时，使用 `.agents/skills/` 或 `.claude/skills/` 中对应入口，并以 `docs/workflows/` 为公共流程事实源。
- 开始实施前按 `project-start` 恢复上下文；若 `docs/handoff.md` 存在，先读取并按其中状态恢复或完成交接。
- 如果 `harness.config.json` 启用了 `durable-plan`，按 `docs/workflows/durable-plan.md` 判断是否命中长任务触发条件；命中时必须先创建或恢复唯一的 `docs/active-plan.md`。
- 不把目录名或模板占位符当作架构事实；项目事实、验证命令和风险能力必须基于目标仓库证据配置。
- 保留工作树中的既有修改，采用最小有效变更，不覆盖或回退无关内容。
- 完成前运行与风险相称的项目检查；统一入口为 `pwsh -NoProfile -File scripts/verify.ps1 -Scope All`，Windows PowerShell 5.1 环境使用 `powershell -ExecutionPolicy Bypass -File scripts/verify.ps1 -Scope All`。
- 新增或修改外部接口请求构造或响应解析、字段映射、共享契约，或仅靠代码审查难以确认的可独立验证逻辑时，必须新增或引用覆盖该行为的自动化测试；可使用项目现有单元测试、集成测试或 Harness。无法自动化时，交付说明必须记录原因、替代验证、遗留风险和下一步，并优先评估最小的可测边界调整。
- 面向 Windows PowerShell 5.1 的脚本和命令示例不得使用 `&&` 或 `||`；独立命令用 `;` 分隔，需要失败即停止时使用 `$?`、`$LASTEXITCODE` 或显式 `if` 检查。
- `.agents/skills/` 和 `.claude/skills/` 中由 Harness 管理的入口只负责路由公共工作流，不受项目自有 Skill 的复用门槛限制；项目自有 Skill 仍应在稳定复用后再沉淀。
- 用户明确要求发现或沉淀知识，或出现重复纠正、重复失败、共享契约等强信号时，使用 `knowledge-capture` 工作流；默认先报告候选，不自动创建长期规则、Decision Record 或 Skill。
- Harness 完整性通过只证明工程规则和入口可读取，不代表业务构建、测试或用户流程已经通过。
<!-- PROJECT-HARNESS:END -->

## 修改前

1. 阅读 `README.md`、`docs/design-principles.md`、`docs/agent-compatibility.md` 和 `docs/initialization-workflow.md`。
2. 修改模板时，同时检查初始化器、Smoke Test 和生成结果。
3. 区分模板完整性检查与目标项目的真实构建/测试，不能用前者代替后者。

## 变更规则

- 默认保留目标仓库已有文件；`-Force` 只允许覆盖 manifest 标记为 `managed` 的模板文件，不覆盖项目所有文件。
- 不根据文件名自动写入未经验证的架构结论或构建命令。
- 不把命令字符串交给 `Invoke-Expression`；验证命令使用 `executable + arguments` 结构。
- 不把安全检查脚本描述成无法绕过的安全边界。
- 新增模板文件时，更新初始化器生成的 `requiredPaths` 和 Smoke Test。
- 不在 `AGENTS.md`、`CLAUDE.md` 和两个 Skill 目录中复制三份同义规则。
- 保持 Windows PowerShell 5.1 兼容；使用 PowerShell 7 专属语法前必须有明确理由。

## 验证

提交前运行：

```powershell
powershell -ExecutionPolicy Bypass -File tests/initialize-smoke.ps1
powershell -ExecutionPolicy Bypass -File tests/check-template-neutrality.ps1
```

第二个命令检查发布表面不包含绝对本地路径；私有代码、名称和业务约定仍须在代码审查中按领域中立原则人工复核。

## 文档

项目自有文档默认使用简体中文；命令、路径、配置键和代码字面量保持原样。每个 Git 提交原则上只聚焦一个可说明的动机；同一动机所需的测试、文档和配置可以同提交，无关格式化或重构应拆分，确需合并时在提交说明中解释原因。
