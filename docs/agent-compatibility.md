# Agent 兼容策略

## 目标边界

本项目保证的是“仓库结构能够被目标工具发现并路由到同一套规则与流程”，不保证语言模型对所有文字指令百分之百服从。必须执行的安全、权限和发布要求仍应使用 Hook、Sandbox、审批、CI 和环境权限机械约束。

## 单一事实源

```text
                         +-> Codex: .agents/skills/*/SKILL.md -----+
AGENTS.md <- CLAUDE.md   +-> Claude: .claude/skills/*/SKILL.md ----+-> docs/workflows/*.md
    ^                    +-> Trae: .trae/rules/project-harness.md -+
    |
项目规则、文档路由和验证要求
```

- `AGENTS.md`：所有工具共用的仓库规则。
- `CLAUDE.md`：默认只包含 `@AGENTS.md`；已有项目也可以保留经过验证、确实指向 `AGENTS.md` 的符号链接。
- `docs/workflows/`：工具中立的完整工作流程。
- `docs/lessons/`：项目长期经验的建议落点；Skill 只负责流程，不复制其中的项目事实。
- `.agents/skills/`：Codex 自动发现入口，只引用公共工作流；Harness 管理的入口不受项目自有 Skill 晋级门槛限制。
- `.claude/skills/`：Claude Code 自动发现入口，只引用公共工作流；Harness 管理的入口不受项目自有 Skill 晋级门槛限制。
- `.trae/rules/project-harness.md`：Trae 的项目规则发现入口，只路由到 `AGENTS.md` 和公共工作流。

## 为什么默认使用导入文件

Claude Code 支持项目根目录的 `CLAUDE.md`，也支持在其中使用 `@AGENTS.md` 导入公共规则。符号链接同样可用，但 Windows 创建符号链接可能依赖管理员权限或开发者模式，因此初始化器默认生成可提交、可审查的导入文件。

需要符号链接的团队可以在初始化后自行将 `CLAUDE.md` 替换为指向 `AGENTS.md` 的链接，但不要同时维护两份正文。

## 兼容性验收

初始化 Smoke Test 验证：

1. `AGENTS.md` 和 `CLAUDE.md` 同时生成。
2. `CLAUDE.md` 导入或链接到 `AGENTS.md`，Trae 规则入口指向 `AGENTS.md` 和 `docs/workflows/`。
3. 十个公共工作流存在。
4. Codex 与 Claude Code 的 Harness 受管同名 Skill 入口内容一致，并指向同名公共工作流；项目自行维护的单工具 Skill 不受此限制。项目自有 Skill 仍应按稳定复用门槛晋级，不因 Harness 安装而自动创建。
5. Harness 检查验证这些路径仍在 `requiredPaths` 中。

工具升级后仍建议分别执行一次可观察测试：启动新会话，要求工具复述项目完成标准和验证入口，并确认它能定位 `docs/workflows/project-start.md`。这比仅检查文件存在更接近真实运行环境。

## 当前验证矩阵

| 工具 | 入口 | 最近验证 | 结果 |
|---|---|---|---|
| Codex | `AGENTS.md`、`.agents/skills/` | 2026-07-20，按当前官方发现路径和生成 Smoke Test | 结构通过 |
| Claude Code `2.1.205` | `CLAUDE.md` 导入 `AGENTS.md` | 2026-07-20，无工具非交互实测 | 正确识别 `AGENTS.md` 和仓库验证命令 |
| Trae CN | `.trae/rules/` 路由到 `AGENTS.md` | 2026-08-03，按官方项目规则发现路径与生成 Smoke Test | 结构通过；仍需客户端人工复测 |

该矩阵是已验证快照，不是对未来版本的永久承诺。升级工具后应重新执行兼容性验收并更新日期与结果。

文件被发现只能证明兼容入口存在，不能替代真实任务验证或机械安全边界。

CI 平台接入边界见 `docs/ci-platform-compatibility.md`；它与 Agent 规则发现是两个独立问题。

## 参考

- [Codex: Custom instructions with AGENTS.md](https://learn.chatgpt.com/docs/agent-configuration/agents-md)
- [Codex: Agent Skills](https://learn.chatgpt.com/docs/agent-configuration/skills)
- [Claude Code: How Claude remembers your project](https://code.claude.com/docs/en/memory)
- [Claude Code: Extend Claude with skills](https://code.claude.com/docs/en/skills)
- [Trae: Rules](https://docs.trae.ai/ide/rules)
