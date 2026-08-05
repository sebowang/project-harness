# Project Start

## 目标

修改前恢复经过验证的仓库上下文。

## 步骤

1. 阅读适用的 `AGENTS.md` 规则链。
2. 阅读 `docs/project-map.md` 和 `docs/verification.md`。
3. 阅读任务相关的 PRD、Active Decision Record、Reference、Lessons 和模块 README。
4. 检查 `git status --short`，保留已有工作。
5. 若 `docs/handoff.md` 存在，先读取它并核对其中的 Git 状态、验证结果和下一步；状态已完成或过期时，归档或删除它，不把它当作当前事实。
6. 检查 `harness.config.json` 是否启用 `durable-plan`，并按 `docs/workflows/durable-plan.md` 判断当前任务是否必须先创建或恢复 `docs/active-plan.md`。
7. 总结目标、已验证架构事实、影响区域、验收路径、风险和开放问题。

上下文恢复阶段不编辑代码。文档与源码冲突时，先报告冲突再选择方向。
