# Agent 兼容说明

## 规则入口

- Codex 自动读取 `AGENTS.md`。
- Claude Code 通过根目录 `CLAUDE.md` 中的 `@AGENTS.md` 导入同一规则。
- Trae 读取 `AGENTS.md`。

`AGENTS.md` 是唯一规则事实源，不要在 `CLAUDE.md` 中复制正文。

## 工作流入口

完整流程位于 `docs/workflows/`：

- `project-start.md`
- `change-plan.md`
- `adversarial-review.md`
- `harness-authoring.md`
- `project-handoff.md`

Codex 使用 `.agents/skills/` 自动发现入口，Claude Code 使用 `.claude/skills/` 自动发现入口。两个目录中的 Skill 都只引用上述公共流程。Trae 可根据 `AGENTS.md` 直接读取对应流程。

## 运行确认

新工具或新版本首次使用时，请启动一个新会话并要求其：

1. 说明本项目的修改前必读顺序。
2. 给出统一验证命令。
3. 定位并概括 `docs/workflows/project-start.md`。

文件被发现只能证明兼容入口存在，不能替代真实任务验证或机械安全边界。

## 参考

- Codex `AGENTS.md`：https://learn.chatgpt.com/docs/agent-configuration/agents-md
- Codex Skills：https://learn.chatgpt.com/docs/agent-configuration/skills
- Claude Code memory：https://code.claude.com/docs/en/memory
- Claude Code skills：https://code.claude.com/docs/en/skills
