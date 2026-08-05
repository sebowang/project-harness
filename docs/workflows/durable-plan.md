# Durable Plan

## 使用条件

仅在 `harness.config.json` 的 `capabilities` 已确认包含 `durable-plan` 后使用。未启用时不得静默修改配置；偶发交接使用 `project-handoff`。

启用后，任务满足以下任一条件时，必须在实施前创建或更新唯一的 `docs/active-plan.md`：

- 用户明确要求分阶段、稍后继续或交接给其他实施者。
- 当前会话无法完成全部验收条件。
- 需要等待外部信息、用户确认、构建环境或其他协作者。
- 涉及数据库迁移、部署、权限、认证、公共 API 或共享数据结构等高风险变化。
- 多个模块存在明确的先后实施依赖。
- 仓库已经存在状态为 `Active` 或 `Blocked` 的 `docs/active-plan.md`。

能够在当前会话完成并验证的单文件、小范围修复、文字调整和一次性查询不创建计划文件。

## 步骤

1. 在修改代码前创建或更新唯一的 `docs/active-plan.md`，写明 `Status`、目标、范围、非范围、验收条件、阶段、风险、阻塞、验证和下一动作。
2. 每次恢复工作先阅读该文件，再核对 Git 状态和最近验证；不要把聊天摘要当作唯一事实源。
3. 完成一个可验证阶段后立即更新阶段状态、实际结果和下一动作，不复制 `session-state`、`progress-map` 或命令历史。
4. 会话结束但任务未完成时，状态保持 `Active`；无法继续时使用 `Blocked` 并写明解除阻塞所需输入。
5. 全部验收完成后使用 `Complete`，将有长期价值的结论路由到 PRD、Decision Record、Reference 或 Lessons，再归档或删除临时计划，并在交付说明中记录去向。

## 最小结构

```markdown
# Active Plan

## Status
Active | Blocked | Complete

## Goal
## Scope
## Out of Scope
## Acceptance Criteria
## Milestones
## Decisions
## Risks and Blockers
## Verification
## Next Action
```
