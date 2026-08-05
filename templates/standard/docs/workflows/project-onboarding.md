# Project Onboarding

## 目标

基于仓库证据完成首次配置。先提出方案，得到用户明确确认后再写入。

## Proposal

1. 只读检查规则文件、Git 状态、源码入口、现有源码、素材与临时记录目录、构建配置、测试、CI、模块文档和外部依赖。没有 CI 配置也要明确记录为“未配置”，不把它当作 Harness 失败或自动补齐目标平台。
   读取 Git remote 时只记录脱敏后的 host；识别 GitHub Actions（`.github/workflows/`）、GitLab CI（`.gitlab-ci.yml`）、CNB（`.cnb.yml`）或未知平台，并只列出文件路径和可观察验证入口。
2. 将结论分为“已验证事实”“推断”“未知项”，每项事实给出文件路径或命令证据。
3. 提出对 `AGENTS.md`、`docs/project-map.md`、`docs/verification.md` 和 `harness.config.json` 的精确修改，并列出 PRD、Decision Record、Reference、Lessons、临时 notes 和 Skill 的现有位置或建议路由。已有治理规则与 Harness 工作流重叠时，保留项目规则为事实源，只通过受管区块和入口路由接入，不复制第二份正文。
   目标项目的 `code/`、`src/`、`assets/`、`notes/` 等目录属于项目所有；只记录真实用途，不创建、移动、重命名或强制统一布局。
4. 验证命令使用 `executable + arguments`，并逐条标注 `kind`（`build`、`test`、`lint`、`smoke` 或 `custom`）。发现 `.sln`、`.csproj`、`package.json`、`pyproject.toml`、`pom.xml`、`build.gradle`、`Cargo.toml` 或 `CMakeLists.txt` 等构建信号时，Proposal 必须明确提醒“构建验证尚未配置”或给出已有构建证据；根据项目类型提出 `readiness.requiredValidationKinds`，由用户选择补充 `build` 检查或记录具体 waiver。不能用 Harness 自身脚本或文档检查替代 `build`，也不能仅凭文件名猜测实际命令。已有 CI 只作为候选证据，不自动复制、迁移或执行其部署步骤。
5. 单独列出数据库、部署、权限、生产数据和昂贵操作风险。可以建议能力，但不得替用户批准。
   可选能力说明见 `docs/capabilities.md`；小项目默认保持空数组。
   如果仓库存在跨会话、多阶段、等待外部输入、高风险变更或多个模块的先后依赖，在 proposal 中建议是否启用 `durable-plan`，并说明命中哪些触发条件。
6. 检查 `scripts/install-git-hooks.ps1` 是否存在，并在 proposal 中明确报告本地 catalog Hook 当前未启用、启用后的作用、与已有 `core.hooksPath` 的冲突风险，以及是否建议启用。
7. 展示 proposal、预计写入文件和仍需用户决定的问题，然后暂停。

Proposal 阶段不得编辑文件、安装依赖、运行会改变仓库或外部系统状态的命令。

## Apply

仅在用户明确确认当前 proposal 后：

1. 重新检查 `git status --short`，保留 proposal 后出现的用户修改。
2. 只修改已确认的文件；不把推断写成事实，不清除仍未解决的项目占位符。
3. 将确认后的项目事实、验证方式和规则保存在仓库文件中。
4. 如果确认启用能力，在 `harness.config.json` 的 `capabilities` 中记录标识；当前任务命中 `durable-plan` 触发条件时，才创建唯一的 `docs/active-plan.md`。
5. 运行 `scripts/harness-doctor.ps1` 和 `scripts/verify.ps1 -Scope All`。
6. 报告写入文件、实际证据、失败或未运行的验证及剩余未知项。

用户只确认部分 proposal 时，只 apply 已确认部分，并保持项目为 `installed`，直到 readiness 条件真实满足。
