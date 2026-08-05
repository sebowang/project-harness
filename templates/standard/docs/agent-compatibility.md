# Agent 兼容说明

## 规则入口

- Codex 自动读取 `AGENTS.md`。
- Claude Code 默认通过根目录 `CLAUDE.md` 中的 `@AGENTS.md` 导入同一规则；已有项目可以保留确实指向 `AGENTS.md` 的符号链接。
- Trae 从 `.trae/rules/project-harness.md` 发现项目规则并路由到 `AGENTS.md`。

`AGENTS.md` 是唯一规则事实源，不要在 `CLAUDE.md` 中复制正文。

## 工作流入口

完整流程位于 `docs/workflows/`：

- `project-start.md`
- `project-onboarding.md`
- `change-plan.md`
- `adversarial-review.md`
- `harness-authoring.md`
- `project-handoff.md`
- `testing.md`
- `systematic-debugging.md`
- `durable-plan.md`
- `knowledge-capture.md`

Codex 使用 `.agents/skills/` 自动发现入口，Claude Code 使用 `.claude/skills/` 自动发现入口。两个目录中的 Harness 受管同名 Skill 内容必须一致，且只引用上述公共流程；这些受管入口不受项目自有 Skill 晋级门槛限制。项目自行维护的单工具 Skill 不受配对限制，但仍应在稳定复用后再沉淀。Trae 的 `.trae/rules/` 入口同样只负责路由，不复制规则正文。

## 运行确认

初始化器和验证入口兼容 Windows PowerShell 5.1 与 PowerShell 7。面向 Windows PowerShell 5.1 的脚本和命令示例不得使用 `&&` 或 `||`；独立命令用 `;` 分隔，需要失败即停止时使用 `$?`、`$LASTEXITCODE` 或显式 `if` 检查。

新工具或新版本首次使用时，请启动一个新会话并要求其：

1. 说明本项目的修改前必读顺序。
2. 给出统一验证命令。
3. 定位并概括 `docs/workflows/project-start.md`。
4. 说明长任务何时必须使用 `docs/active-plan.md`，以及经验应如何路由到 Lessons、PRD、Decision Record、Reference 或 Skill。

文件被发现只能证明兼容入口存在，不能替代真实任务验证或机械安全边界。

CI 平台接入边界见 `docs/ci-platform-compatibility.md`；它与 Agent 规则发现是两个独立问题。

## 参考

- Codex `AGENTS.md`：https://learn.chatgpt.com/docs/agent-configuration/agents-md
- Codex Skills：https://learn.chatgpt.com/docs/agent-configuration/skills
- Claude Code memory：https://code.claude.com/docs/en/memory
- Claude Code skills：https://code.claude.com/docs/en/skills
- Trae Rules：https://docs.trae.ai/ide/rules
