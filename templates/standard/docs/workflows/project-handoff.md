# Project Handoff

仅在任务必须跨会话或跨实施者继续时，创建或更新唯一的 `docs/handoff.md`。固定路径让下一位实施者可以在不猜测文件名的情况下发现未完成工作；基础初始化不预建空文件。

交接内容包括：

- 目标和验收条件
- 已完成工作和变更文件
- 实际验证命令与结果
- 未解决问题与风险
- 接下来三个具体步骤
- 精确恢复位置

不同时创建 `session-state`、`progress-map` 和 `command-history` 等多份状态文件。恢复任务时先读取 `docs/handoff.md`，再核对 Git 状态和实际验证结果。任务完成后按项目文档策略归档或删除 `docs/handoff.md`；长期结论转入 PRD、Decision Record、Reference 或 Lessons，而不是保留在交接文件中。
