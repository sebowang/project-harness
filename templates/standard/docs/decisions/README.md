# 决策记录

本目录记录后续工作必须理解的长期选择和不变量，不为每个需求、Bug 或临时方案创建文件。

统一使用一种 `Decision Record`，通过 `Type` 区分：

- `System Invariant`：系统必须长期保持的行为、公共契约、兼容性要求或禁止事项。
- `Architecture Decision`：架构、依赖、实现路线或技术方案之间的长期选择。

状态使用 `Proposed`、`Active` 或 `Superseded`。一个决策一个文件，文件名使用 `decision-NNN-short-title.md`。

```markdown
# DECISION-NNN：决策标题

## Type
System Invariant | Architecture Decision

## Status
Proposed | Active | Superseded

## Context
## Decision Or Invariant
## Rationale
## Alternatives
## Constraints And Prohibited Behavior
## Consequences
## Verification
## Related Material
## Change History
```

创建前确认该内容具有跨任务价值、预期长期有效，并能说明影响范围或验证方式。仅当前任务有效的内容进入计划或 handoff；产品需求进入 PRD；经验教训进入 Lessons；可重复执行流程才考虑 Skill。
