# Project Onboarding

## 目标

基于仓库证据完成首次配置。先提出方案，得到用户明确确认后再写入。

## Proposal

1. 只读检查规则文件、Git 状态、源码入口、构建配置、测试、CI、模块文档和外部依赖。
2. 将结论分为“已验证事实”“推断”“未知项”，每项事实给出文件路径或命令证据。
3. 提出对 `AGENTS.md`、`docs/project-map.md`、`docs/verification.md` 和 `harness.config.json` 的精确修改。
4. 验证命令使用 `executable + arguments`；只提出仓库中已有证据支持的命令。
5. 单独列出数据库、部署、权限、生产数据和昂贵操作风险。可以建议能力，但不得替用户批准。
   可选能力说明见 `docs/capabilities.md`；小项目默认保持空数组。
6. 展示 proposal、预计写入文件和仍需用户决定的问题，然后暂停。

Proposal 阶段不得编辑文件、安装依赖、运行会改变仓库或外部系统状态的命令。

## Apply

仅在用户明确确认当前 proposal 后：

1. 重新检查 `git status --short`，保留 proposal 后出现的用户修改。
2. 只修改已确认的文件；不把推断写成事实，不清除仍未解决的项目占位符。
3. 将确认后的项目事实、验证方式和规则保存在仓库文件中。
4. 如果确认启用能力，在 `harness.config.json` 的 `capabilities` 中记录标识，并创建该能力要求的最小项目文件。
5. 运行 `scripts/harness-doctor.ps1` 和 `scripts/verify.ps1 -Scope All`。
6. 报告写入文件、实际证据、失败或未运行的验证及剩余未知项。

用户只确认部分 proposal 时，只 apply 已确认部分，并保持项目为 `installed`，直到 readiness 条件真实满足。
