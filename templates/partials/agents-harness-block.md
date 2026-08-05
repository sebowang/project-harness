<!-- PROJECT-HARNESS:BEGIN -->
## Project Harness 集成

以下区块由 Project Harness 管理。项目专属规则保留在区块外；重新合并时只更新本区块。

- 修改前阅读 `docs/project-map.md`、`docs/verification.md`，以及与任务相关的需求、决策、参考资料和模块 README。
- 目标项目的源码、素材和临时记录目录由项目自己决定；不要因为 Harness 模板创建、移动或重命名 `code/`、`src/`、`assets/`、`notes/` 等目录。
- 开始实施、规划、调试、测试、审查或交接时，使用 `.agents/skills/` 或 `.claude/skills/` 中对应入口，并以 `docs/workflows/` 为公共流程事实源。
- 开始实施前按 `project-start` 恢复上下文；若 `docs/handoff.md` 存在，先读取并按其中状态恢复或完成交接。
- 如果 `harness.config.json` 启用了 `durable-plan`，按 `docs/workflows/durable-plan.md` 判断是否命中长任务触发条件；命中时必须先创建或恢复唯一的 `docs/active-plan.md`。
- 不把目录名或模板占位符当作架构事实；项目事实、验证命令和风险能力必须基于目标仓库证据配置。
- 保留工作树中的既有修改，采用最小有效变更，不覆盖或回退无关内容。
- 完成前运行与风险相称的项目检查；统一入口为 `powershell -ExecutionPolicy Bypass -File scripts/verify.ps1 -Scope All`。
- 用户明确要求发现或沉淀知识，或出现重复纠正、重复失败、共享契约等强信号时，使用 `knowledge-capture` 工作流；默认先报告候选，不自动创建长期规则、Decision Record 或 Skill。
- Harness 完整性通过只证明工程规则和入口可读取，不代表业务构建、测试或用户流程已经通过。
<!-- PROJECT-HARNESS:END -->
