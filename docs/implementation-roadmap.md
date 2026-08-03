# 持续实施计划

本文记录 Project Harness 从可用初始化器发展为可持续维护工具的实施顺序。每个阶段只在验收条件满足后进入下一阶段；模型能力提升可以简化工作流，但不得削弱非破坏性、事实优先和验证证据等不变量。

## 已完成基线

### 初始化与跨 Agent 入口

- 非破坏性 `Light` / `Standard` 初始化。
- Codex、Claude Code、Trae 共用 `AGENTS.md` 和公共工作流。
- 结构化项目验证命令和 Harness Smoke Test。

### Readiness 与模板所有权

- `installed`、`ready`、`ready with waiver` 状态语义。
- `-Scope All` 拒绝未清除的项目占位符和缺失的 Standard 项目验证。
- `-WhatIf` 对新目录只预览，不写入。
- 配置 schema、普通文件类型和仓库内路径检查。
- `templates/manifest.json` 统一声明版本、模板层和 `managed` / `project` 所有权。
- Windows PowerShell 5.1 与 Linux `pwsh` CI。

对应提交：`1432eab`、`cf722ae`。

## 阶段一：安全持续维护

目标：同一条 apply 命令能够识别首次安装、状态检查和安全升级。

实施项：

1. 生成 `harness.lock.json`，记录安装版本、profile 和受管文件的基线 SHA-256。
2. 提供 `status`，区分未修改、项目修改、上游可更新、缺失和冲突文件。
3. 提供 `update -DryRun`，在任何写入前输出完整计划。
4. 仅自动更新未被项目修改的 `managed` 文件。
5. `project` 文件只给出建议，不自动覆盖。
6. 双方都修改时停止整个更新，不进行部分写入。
7. 更新前备份将被替换的文件；配置使用字段级迁移。
8. 覆盖首次安装、无变化重跑、上游更新、本地修改、双方冲突、回滚和 `-WhatIf` 测试。

验收：重复运行不会破坏项目修改；冲突时目标仓库保持更新前状态；预览与实际更新计划一致。

## 阶段二：Agent 引导配置

目标：一条指令启动安装和仓库勘察，但有产品后果的选择仍由用户确认。

流程：

```text
安装中性脚手架
  -> Agent 只读勘察
  -> 输出事实、证据、未知项和配置建议
  -> 用户确认
  -> 写入项目文件
  -> doctor 与完整验证
```

实施项：只读 proposal、精确目标文件、验证命令候选、风险能力建议、确认后的 apply，以及可复核的 onboarding 报告。

验收：Agent 不根据文件名写入架构结论，不自动批准数据库、部署、权限或生产操作规则。

## 阶段三：大小项目的可选能力

目标：核心流程保持轻量，大项目按实际风险启用能力。

候选能力：

- `durable-plan`：跨会话 active/completed plan。
- `architecture-checks`：依赖方向和共享契约检查。
- `database-risk`：数据库写入、迁移和恢复验证入口。
- `deployment-risk`：发布环境、审批和回滚证据。
- `document-drift`：项目化高价值事实断言。

验收：小项目不因未启用能力承担额外状态文件；大项目的高风险要求由真实 CI、权限或脚本机械执行。

## 阶段四：项目自身产品化

1. 使用稳定版初始化器为本仓库完成 dogfooding。
2. 将生成结果与升级场景纳入 golden test。
3. 发布带 tag 的版本和 `CHANGELOG.md`。
4. 提供可校验的 GitHub Release 下载方式。
5. 建立兼容和迁移策略。

## 阶段五：扩展

- Skill 静态质量和触发准确性评估。
- Cursor、Gemini、GitHub Copilot 入口。
- OpenSpec、Spec Kit、Superpowers 等可选集成。

扩展不得早于安全升级和 Agent 引导配置，也不得把外部流程变成所有项目的默认负担。
