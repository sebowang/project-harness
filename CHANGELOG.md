# Changelog

本项目遵循语义化版本。每个版本的模板版本来自 `templates/manifest.json`，目标仓库的 `harness.lock.json` 记录已安装版本。

## [1.3.6] - 2026-08-07

### Added

- `project-onboarding` 支持用户明确发起的“基线刷新”或“整理整个项目”：先只读审计项目事实和治理文档，再提交 Proposal 并等待确认。
- 可选 pre-commit Hook 现在校验暂存的 artifact catalog 和已配置文档漂移断言。

### Changed

- `Standard` 的 readiness 在存在项目验证要求、但未声明任何 `requiredValidationKinds` 且没有具体豁免时失败，避免把缺少证据策略误报为普通通过。
- 文档漂移断言只用于稳定的机械事实；项目地图的模块职责、边界和依赖仍由用户确认，不会自动改写。
- 受管 Agent 规则要求在执行命令前确认操作系统、Shell 和项目工具链，并优先复用仓库已有入口。

## [1.3.5] - 2026-08-06

### Added

- `projectValidation` 可选支持仓库内工作目录、命令级环境变量和正整数超时；超时命令在独立 PowerShell Job 中终止，配置中的环境变量不会保留到后续命令。
- 增加可复制的 GitHub Actions 统一验证示例。

### Fixed

- 初始化器与 onboarding 对齐构建信号：增加 CMake、Gradle Kotlin、Python `setup.py`，并递归识别 .NET solution、项目和 SDK 配置文件。
- 项目验证执行期间将原生命令 stderr 保持为非终止输出，避免 Windows PowerShell 5.1 因 stderr 合并而遮蔽可观察的退出码。

### Changed

- 统一规则入口优先使用跨平台 `pwsh`，并明确 Windows PowerShell 5.1 回退命令。
- 更新流程说明备份目录由目标仓库管理，初始化器不会静默改写已有 `.gitignore`。

## [1.3.4] - 2026-08-05

### Changed

- 为新增自动化测试补充价值筛查：要求说明保护的具体回归、可观察断言以及相对已有测试新增的失败模式；重复覆盖优先合并或增强已有测试。
- 明确临时调试检查不应仅为测试数量、目录或覆盖率而保留为长期 Harness，并避免将私有实现路径当作稳定契约。

## [1.3.3] - 2026-08-05

### Changed

- 对外部接口请求构造或响应解析、字段映射、共享契约和难以仅靠审查确认的可独立验证逻辑，明确要求新增或引用自动化测试；无法自动化时必须记录原因、替代验证、风险和下一步。
- 明确 Harness 是现有单元测试或集成测试之外的可选外部回归检查，不强制项目采用特定测试工具或为测试进行不必要的架构重构。
- 规定第三方依赖或遗留运行时的测试配方应先基于项目证据勘察，并在首次验证成功后沉淀到项目自身的 Reference 或 Lessons。

## [1.3.2] - 2026-08-05

### Changed

- 补充 Windows PowerShell 5.1 命令兼容规则：示例不使用 `&&`/`||`，并明确独立命令分隔与失败即停止检查的区别。

## [1.3.1] - 2026-08-05

### Fixed

- `-Update` 现在会报告落后的 `AGENTS.md` 受控区块、缺失的 project-owned 模板和 `harness.config.json`/lock 版本差异，避免 lock 升级后静默形成部分升级状态。
- `-Update -MergeProjectRules` 可以在预览和确认后备份并刷新 `AGENTS.md` 标记内的 Harness 区块，不覆盖项目规则区块外内容。
- Update 结束状态改为 `updated` 或明确的 project-owned follow-up，不再使用首次安装的状态措辞。

## [1.3.0] - 2026-08-05

### Added

- 为项目验证记录增加 `build`、`test`、`lint`、`smoke` 和 `custom` 类型，并支持在 readiness 中声明必须具备的验证类型。
- onboarding 会根据仓库中的构建信号提示配置真实构建或测试命令；未配置时不会把 Harness 自检当作业务构建证据。
- README 增加可直接交给 Agent 的 Harness 更新自然语言指令，并明确预览、冲突、备份和确认边界。

### Changed

- 缺少已声明的必需验证类型时，readiness 会失败；豁免只记录例外，不会把业务构建或测试标记为通过。
- 生成的协作规则补充受管区块边界、适用文档优先级、用户流程状态覆盖和单一提交动机等通用约束。

## [1.2.0] - 2026-08-04

### Added

- Standard 支持配置驱动的 artifact catalog，为 `tests/harness/*.ps1` 生成稳定的 README 受管索引，并在统一验证中检查漂移。
- 增加显式、可撤销的本地 pre-commit hook 安装器；不自动改 Git 配置，不覆盖已有 Hook，也不自动修改或暂存文件。

### Changed

- `verify.ps1 -Scope Harness/All` 会运行已配置的 artifact catalog 检查，CI 可直接复用同一入口。

## [1.1.3] - 2026-08-04

### Fixed

- 已有受管文件与模板一致时初始化会建立可信 lock 基线。
- 显式 `-Force` 迁移受管文件前会备份旧文件，并刷新迁移后的基线。
- Harness 结构检查现在验证 `CLAUDE.md` 和 Trae 规则入口确实路由到公共事实源。

### Added

- `-MergeProjectRules` 可将 Harness 受控区块合并到已有 `AGENTS.md`，保留项目专属规则、备份原文件，并支持重复执行收敛。

## [1.1.2] - 2026-08-04

### Changed

- 为 testing、change-plan 和 adversarial-review 工作流补充可执行的验证分级、行为验收、范围扩张和依赖影响要求。
- 中立性检查说明改为准确描述绝对本地路径检查与人工领域中立复核的边界。

## [1.1.1] - 2026-08-04

### Fixed

- 中立性检查改为覆盖任意盘符的 Windows 绝对路径与 Unix 绝对路径，并保留通用文档占位路径。
- 移除对历史项目名称的封闭式禁用词检查。
- 明确 `verify.ps1`、`harness-status.ps1` 以及非受管 CI 示例的职责边界。

## [1.1.0] - 2026-08-04

### Added

- GitLab CI 与 CNB（cnb.cool）参考示例，以及 CI 平台兼容性说明。
- onboarding 只读识别 Git remote 和已有 CI 文件，并在 proposal 中提出平台建议。

### Changed

- CI 示例不会默认写入目标项目；统一验证入口仍由目标仓库的 `scripts/verify.ps1 -Scope All` 配置决定。

## [1.0.4] - 2026-08-03

### Fixed

- Smoke Test 成功完成后显式返回退出码 `0`，避免 Linux PowerShell 将故意失败的负向断言遗留为整个测试的失败状态。

## [1.0.3] - 2026-08-03

### Fixed

- Smoke Test 会根据当前平台使用可发现的 `powershell` 或 `pwsh` 执行项目验证。

## [1.0.2] - 2026-08-03

### Fixed

- Linux/macOS PowerShell 初始化现在会正确枚举并安装 `.trae/rules/` 等隐藏模板路径。

## [1.0.1] - 2026-08-03

### Fixed

- `-Force` 现在只覆盖 manifest 标记为 `managed` 的模板文件，不再覆盖 `AGENTS.md`、项目文档、`harness.config.json` 或既有 lock。
- 统一 Windows 与跨平台路径分隔符后再判断模板所有权。

## [1.0.0] - 2026-08-03

### Added

- `Light` / `Standard` 非破坏性初始化，以及 `installed`、`ready`、`ready with waiver` 状态。
- `harness.lock.json` 受管文件基线、`harness-status.ps1` 和 `harness-doctor.ps1`。
- `-Update -WhatIf` 安全更新、受管文件所有权、冲突停止、备份和失败恢复；上游移除文件默认保留为 `ORPHANED`，显式 `-Prune` 仅清理未修改文件。
- 基于仓库证据的 `project-onboarding` proposal/confirm/apply 工作流。
- 面向大项目的可选 `durable-plan`、架构、数据库和部署风险能力入口，以及测试、系统化调试和跨会话计划工作流。
- Codex、Claude Code 与 Trae 的项目规则入口，其中 Trae 使用 `.trae/rules/` 路由到 `AGENTS.md`。
- 模板中立性检查、Windows PowerShell 5.1 与 PowerShell 7 Smoke Test CI，并完成仓库 dogfooding。

### Not Included

- Cursor、Gemini、GitHub Copilot、OpenSpec、Spec Kit、Superpowers 集成。
- 通用二进制发布物或无法由项目配置验证的安全命令守卫。

## Upgrade Notes

从 0.x 升级前先运行 `-Update -WhatIf`。没有 `harness.lock.json` 的目标仓库应先按首次安装流程安装；升级不会静默覆盖项目所有文件。
