# {{PROJECT_NAME}} 协作指南

## 项目目标

TODO(HARNESS)：用两到三句话说明项目服务对象、核心能力和明确非目标。

本文件是 Codex、Claude Code 和 Trae 共用的项目规则事实源。`CLAUDE.md` 只导入本文件，不在其他工具入口复制规则正文。

{{HARNESS_RULES_BLOCK}}

## 修改前必读

1. 本文件。
2. `docs/project-map.md`。
3. 与任务相关的需求、决策、参考资料和模块 README。

Standard 项目还应按任务需要读取 `docs/lessons/`，并检查 `harness.config.json` 的 `durable-plan` 能力和对应触发条件。

项目规则与项目文档冲突时，以本文件为协作规则事实源；相关文档存在时，按已接受的决策/ADR、当前 PRD、项目地图、模块 README、临时 notes 的顺序核对。若冲突会改变公共契约或用户可见行为，先暂停确认，不得静默选择更方便的解释。

## 变更规则

- 实施前确认目标、影响范围和验收路径，区分已验证事实与假设。
- 采用最小有效修改，不做无关重构、格式化或清理。
- 保留工作树中已有的用户修改，不覆盖或回退无关内容。
- 不因为 Harness 模板改变目标项目的源码、素材或临时记录布局；`code/`、`src/`、`assets/`、`notes/` 等目录由项目自行决定并由项目地图记录。
- 不根据目录名猜测架构、公共契约或运行时行为。
- 未经明确批准，不新增依赖、改变公共接口或执行破坏性操作。
- 发现任务范围显著扩大时，暂停并重新确认方案。
- 面向用户的变更，按现有交互模式检查适用的加载、禁用、成功、空数据和失败恢复状态；未检查相关验收路径前，不声称用户流程已完成。
- 每个 Git 提交原则上只聚焦一个可说明的动机。同一动机所需的代码、测试、文档和配置可以同提交；无关清理、格式化或重构应拆分，确需合并时在提交说明中解释原因。

## 验证

- 使用 `docs/verification.md` 和 `harness.config.json` 选择真实检查。
- 运行与变更风险相称的构建、测试、Lint、Harness 或手工验收。
- 报告实际运行的命令、结果和尚未验证的内容。
- Harness 检查失败视为未完成或回归，直到根因明确；Harness 完整性通过只证明工程规则和入口可读取，不代表业务功能已经通过。

统一入口：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify.ps1 -Scope All
```

## 文档路由

- `docs/project-map.md`：当前架构事实、模块边界、依赖和验收入口。
- `docs/verification.md`：变更类型与验证证据的映射。
- `docs/lessons/`：Standard 模式下记录可复用的用户纠正、重复失败根因和实施经验。
- `docs/workflows/`：工具中立的可复用工作流程；Standard 模式下由各工具入口按需读取。

TODO(HARNESS)：Standard 模式下补充 PRD、Decision Record、Reference、Lessons、durable-plan 与 Harness 的项目具体规则。

## 公共工作流

Standard 模式提供：

- `docs/workflows/project-start.md`
- `docs/workflows/project-onboarding.md`
- `docs/workflows/change-plan.md`
- `docs/workflows/adversarial-review.md`
- `docs/workflows/harness-authoring.md`
- `docs/workflows/project-handoff.md`
- `docs/workflows/testing.md`
- `docs/workflows/systematic-debugging.md`
- `docs/workflows/durable-plan.md`（仅确认启用 `durable-plan` 后使用）
- `docs/workflows/knowledge-capture.md`

当工具不能自动发现 Skill 时，直接读取并执行对应工作流。

## 完成标准

只有在实现、验证、必要文档同步和知识沉淀判断完成后，才能声称任务完成。无法运行检查时，明确记录原因、风险和建议的后续验证。
