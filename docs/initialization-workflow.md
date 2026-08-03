# 初始化工作流

## 阶段一：只读勘察

在写入前检查：

- Git 根目录和工作树状态
- 入口项目、包或解决方案
- 主要目录及真实职责
- 构建、测试、Lint、CI 和现有脚本
- 已有 `AGENTS.md`、ADR、设计文档和模块 README
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
- 不修改业务源码、依赖、数据库、部署脚本或 Git Hook。

`-Force` 会覆盖同名 Harness 文件，只应在确认差异后使用。

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
- 项目所有文件和 `harness.config.json`：不自动覆盖。
- 成功更新前备份受影响文件和原 lock；写入失败时尝试恢复到备份状态。

配置 schema 需要迁移时，由对应版本提供显式迁移步骤；v1 不会借模板升级静默重写项目验证、豁免或漂移规则。

## 阶段四：填写项目事实

至少完成：

1. 在 `docs/project-map.md` 记录已验证入口、模块、依赖方向和风险。
2. 在 `docs/verification.md` 记录变更类型到验证证据的映射。
3. 在 `harness.config.json` 配置实际可执行的项目验证命令。
4. 删除所有 `TODO(HARNESS)` 标记。
5. 运行 Harness 检查和项目验证。
6. 分别在实际使用的 Agent 中确认规则入口已加载。

初始化器完成文件写入后，项目处于 `installed` 状态。只有 `scripts/verify.ps1 -Scope All` 通过后，项目才处于 `ready`；使用项目验证豁免时应报告为 `ready with waiver`。

`Standard` 默认要求真实项目验证命令。项目确实不存在可执行验证时，在 `harness.config.json` 的 `readiness.projectValidationWaiver` 中记录具体原因，不得使用空字符串或笼统的“暂不需要”。

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
