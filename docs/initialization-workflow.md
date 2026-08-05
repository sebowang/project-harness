# 初始化工作流

## 阶段一：只读勘察

在写入前检查：

- Git 根目录和工作树状态
- 入口项目、包或解决方案
- 主要目录及真实职责
- 构建、测试、Lint、CI 和现有脚本
- 已有 `AGENTS.md`、Decision Record、设计文档和模块 README
- 外部依赖、数据库、发布和生产数据风险

如果仓库已有未提交修改，初始化器仍可创建缺失文件，但实施者必须先确认不会覆盖用户工作。

## 阶段二：选择级别

使用 `Light` 的条件：项目较小、生命周期短、流程简单，当前只需要规则、项目地图和验证入口。

使用 `Standard` 的条件：项目长期维护，Agent 会重复参与，存在跨模块决策、外部契约或值得固化的开发流程。

高风险生产项目先安装 Standard，再由项目团队增加 CI、审批、Hook、发布保护和环境隔离。不要依赖通用 Full 模板猜测这些边界。

## 阶段三：安装脚手架

```powershell
powershell -ExecutionPolicy Bypass -File scripts/initialize-project.ps1 `
  -TargetPath "C:\path\to\repository" `
  -Profile Standard
```

默认行为：

- 创建不存在的目录和文件。
- 替换模板中的项目名称。
- 保留已有文件并报告 `SKIP`。
- 为 Claude Code 创建导入 `AGENTS.md` 的 `CLAUDE.md`。
- Standard 模式为 Codex 与 Claude Code 创建指向公共工作流的 Skill 入口。
- 生成 `harness.config.json`。
- Standard 为 `tests/harness/*.ps1` 配置 README 索引检查。
- 不修改业务源码、依赖、数据库、部署脚本或 Git 配置；Git Hook 文件会随 Standard 安装，但只在显式运行安装器后启用。

`-Force` 只覆盖 manifest 标记为 `managed` 的模板文件；执行前会备份已存在的受管文件并在 lock 中记录新基线。`AGENTS.md`、项目地图、验证指南和 `harness.config.json` 等项目所有文件仍会保留。建议先用 `-WhatIf` 查看迁移范围。

已有 `AGENTS.md` 但需要接入 Harness 时，显式使用 `-MergeProjectRules`。初始化器只管理 `<!-- PROJECT-HARNESS:BEGIN -->` 与 `<!-- PROJECT-HARNESS:END -->` 包围的区块，区块以外仍完全属于目标项目；首次改写前会备份 `AGENTS.md`。若标记只有开始或结束一侧、或出现多个区块，初始化器会停止，避免猜测合并结果。

## 持续维护

目标仓库已存在 `harness.lock.json` 后，先预览再更新：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/initialize-project.ps1 `
  -TargetPath "C:\path\to\repository" -Update -WhatIf

powershell -ExecutionPolicy Bypass -File scripts/initialize-project.ps1 `
  -TargetPath "C:\path\to\repository" -Update
```

`-Update` 使用 lock 中的 profile、项目名和 SHA-256 基线，不接受 `-Force` 作为冲突解决方式。更新遵循以下规则：

- 上游变化且本地仍等于基线：自动更新。
- 新的受管文件且目标路径不存在：自动创建。
- 本地与上游都变化、受管文件缺失或路径碰撞：整次更新在写入前停止。
- 上游已移除的受管文件：默认报告为 `ORPHANED` 并保留；只有 `-Update -Prune` 才会删除仍等于受信基线的文件。无基线、已修改或非普通文件的孤儿路径必须人工处理。
- 项目所有文件和 `harness.config.json`：不自动覆盖。缺失的项目拥有模板、`AGENTS.md` 受控区块与目标版本不同、或配置版本与 lock 不同，都会在 Update plan 中以 `NOTICE` 列出；这些提示不会静默视为完整升级。
- 需要刷新已有 `AGENTS.md` 的受控区块时，显式使用 `-Update -MergeProjectRules`。它只改写标记内区块、先备份原文件；项目规则区块外内容仍不会覆盖。其他缺失的项目拥有模板仍由项目确认后创建。
- 成功更新前备份受影响文件和原 lock；写入失败时尝试恢复到备份状态。

配置 schema 需要迁移时，由对应版本提供显式迁移步骤；v1 不会借模板升级静默重写项目验证、豁免或漂移规则。`harness.config.json.harnessVersion` 与 lock 不同时会提示人工复核，不表示配置已自动迁移。

## 阶段四：填写项目事实

至少完成：

1. 在 `docs/project-map.md` 记录已验证入口、模块、依赖方向和风险。
2. 在 `docs/verification.md` 记录变更类型到验证证据的映射。
3. 在 `harness.config.json` 配置实际可执行的项目验证命令，为每条命令标注 `kind`，并按项目类型填写 `readiness.requiredValidationKinds`。
4. 删除所有 `TODO(HARNESS)` 标记。
5. 运行 Harness 检查和项目验证。
6. 分别在实际使用的 Agent 中确认规则入口已加载。

新增或删除 `artifactCatalogs` 覆盖的文件后，运行 `scripts/update-artifact-catalog.ps1` 更新受管索引。需要提交前反馈时可显式运行 `scripts/install-git-hooks.ps1`；它不会覆盖已有的 `core.hooksPath`，也不能代替 CI 中的完整验证。

初始化器完成文件写入后，项目处于 `installed` 状态。Standard 安装输出会明确提示 catalog Hook 尚未启用及安装命令；只有用户明确同意后才运行该命令。只有 `scripts/verify.ps1 -Scope All` 通过后，项目才处于 `ready`；使用项目验证豁免时应报告为 `ready with waiver`。

`Standard` 默认要求真实项目验证命令。对编译型项目，缺少 `build` 证据时必须记录具体的 `readiness.projectValidationWaiver`，不得使用 Harness Smoke Test 冒充构建，也不得使用空字符串或笼统的“暂不需要”。

## 阶段五：验证

```powershell
# 只检查 Harness 自身
powershell -ExecutionPolicy Bypass -File scripts/verify.ps1 -Scope Harness

# 只运行项目验证命令
powershell -ExecutionPolicy Bypass -File scripts/verify.ps1 -Scope Project

# 全部运行
powershell -ExecutionPolicy Bypass -File scripts/verify.ps1 -Scope All
```

初始化验收报告必须明确：创建/跳过的文件、Harness 检查结果、项目验证结果、尚未验证的内容和下一步责任人。
