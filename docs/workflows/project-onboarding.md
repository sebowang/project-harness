# Project Onboarding

## 目标

基于仓库证据完成首次配置，或响应用户明确提出的“基线刷新”（baseline refresh）或“整理整个项目”请求。先提出方案，得到用户明确确认后再写入。

日常开发不触发本工作流的全量勘察；只在本次变更可能影响文档事实时，按项目规则判断相关文档是否需要同步。

## Proposal

1. 只读检查规则文件、Git 状态、源码入口、现有源码、素材与临时记录目录、构建配置、测试、CI、模块文档和外部依赖。没有 CI 配置也要明确记录为“未配置”，不把它当作 Harness 失败或自动补齐目标平台。
   读取 Git remote 时只记录脱敏后的 host；识别 GitHub Actions（`.github/workflows/`）、GitLab CI（`.gitlab-ci.yml`）、CNB（`.cnb.yml`）或未知平台，并只列出文件路径和可观察验证入口。
2. 将结论分为“已验证事实”“推断”“未知项”，每项事实给出文件路径或命令证据。
3. 提出对 `AGENTS.md`、`docs/project-map.md`、`docs/verification.md` 和 `harness.config.json` 的精确修改，并列出 PRD、Decision Record、Reference、Lessons、临时 notes 和 Skill 的现有位置或建议路由。已有治理规则与 Harness 工作流重叠时，保留项目规则为事实源，只通过受管区块和入口路由接入，不复制第二份正文。
   目标项目的 `code/`、`src/`、`assets/`、`notes/` 等目录属于项目所有；只记录真实用途，不创建、移动、重命名或强制统一布局。
   基线刷新还要将现有项目地图、PRD、Decision Record、Reference、验证记录和 Harness 配置与当前仓库证据逐项比对，列出缺失、过期和待确认事实。结构清单可以辅助勘察，但模块职责、依赖方向和业务边界属于语义事实，只能在 Proposal 中提出，不能自动改写。
4. 验证命令使用 `executable + arguments`，并逐条标注 `kind`（`build`、`test`、`lint`、`smoke` 或 `custom`）。勘察 `package.json`、`pyproject.toml`、`requirements.txt`、`setup.py`、`Cargo.toml`、`go.mod`、`pom.xml`、`build.gradle`、`build.gradle.kts`、`gradlew`、`Makefile`、`CMakeLists.txt`，以及任意目录中的 `.sln`、`.csproj`、`.fsproj`、`.vbproj`、`Directory.Build.props`、`global.json` 等构建信号；发现后 Proposal 必须明确提醒“构建验证尚未配置”或给出已有构建证据。根据项目类型提出 `readiness.requiredValidationKinds`，由用户选择补充 `build` 检查或记录具体 waiver。不能用 Harness 自身脚本或文档检查替代 `build`，也不能仅凭文件名猜测实际命令。已有 CI 只作为候选证据，不自动复制、迁移或执行其部署步骤。
   Agent 不得把“请自行填写验证命令”留给没有工程经验的用户。应基于已验证证据提供可确认的 `harness.config.json` 片段，逐条说明命令会做什么、为什么适用、尚未证明什么；证据不足时，说明一项明确的补充信息或工具安装动作，不写入猜测出的命令。
   对 C#/.NET，先读取项目的 `Sdk` 属性、`TargetFramework`/`TargetFrameworks`、`global.json`、solution、测试项目、已有 CI 和脚本，再检查 `dotnet --list-sdks`、`MSBuild`、`vstest.console` 是否可用。确认 SDK 风格项目和 SDK 都存在时，Proposal 可提供已确认 `.sln` 或项目路径的 `dotnet build` 候选；只有找到测试项目或已有测试入口时才提供 `dotnet test` 候选。确认 .NET Framework 目标且本机工具可用时，Proposal 改为对应的 `MSBuild` 和测试入口候选。混合目标或工具缺失时，清楚列出要选择的项目范围或要安装的工具；不得自动记录 waiver。
5. 单独列出数据库、部署、权限、生产数据和昂贵操作风险。可以建议能力，但不得替用户批准。
   可选能力说明见 `docs/capabilities.md`；小项目默认保持空数组。
   如果仓库存在跨会话、多阶段、等待外部输入、高风险变更或多个模块的先后依赖，在 proposal 中建议是否启用 `durable-plan`，并说明命中哪些触发条件。
6. 检查 `scripts/install-git-hooks.ps1` 是否存在，并在 proposal 中明确报告本地 Hook 当前未启用、启用后会校验暂存的 artifact catalog 和已配置文档漂移断言、与已有 `core.hooksPath` 的冲突风险，以及是否建议启用。
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
