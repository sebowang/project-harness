# Project Harness 协作指南

## 项目目标

本仓库维护一套通用、非破坏性的 AI 辅助研发初始化方案。发布到本仓库的模板、脚本与示例必须保持领域、语言和框架中立，不得嵌入私有项目代码、名称、路径或业务约定。该限制不适用于安装后的目标仓库：目标项目可以并且应当保留自身的私有代码、名称、路径和业务约定。

`AGENTS.md` 是跨工具协作规则的唯一事实来源。`CLAUDE.md` 只负责导入它；`.agents/skills/`、`.claude/skills/` 只负责把各工具路由到 `docs/workflows/` 中的公共流程。

## 修改前

1. 阅读 `README.md`、`docs/design-principles.md`、`docs/agent-compatibility.md` 和 `docs/initialization-workflow.md`。
2. 修改模板时，同时检查初始化器、Smoke Test 和生成结果。
3. 区分模板完整性检查与目标项目的真实构建/测试，不能用前者代替后者。

## 变更规则

- 默认保留目标仓库已有文件；`-Force` 只允许覆盖 manifest 标记为 `managed` 的模板文件，不覆盖项目所有文件。
- 不根据文件名自动写入未经验证的架构结论或构建命令。
- 不把命令字符串交给 `Invoke-Expression`；验证命令使用 `executable + arguments` 结构。
- 不把安全检查脚本描述成无法绕过的安全边界。
- 新增模板文件时，更新初始化器生成的 `requiredPaths` 和 Smoke Test。
- 不在 `AGENTS.md`、`CLAUDE.md` 和两个 Skill 目录中复制三份同义规则。
- 保持 Windows PowerShell 5.1 兼容；使用 PowerShell 7 专属语法前必须有明确理由。

## 验证

提交前运行：

```powershell
powershell -ExecutionPolicy Bypass -File tests/initialize-smoke.ps1
powershell -ExecutionPolicy Bypass -File tests/check-template-neutrality.ps1
```

第二个命令检查发布表面不包含绝对本地路径；私有代码、名称和业务约定仍须在代码审查中按领域中立原则人工复核。

## 文档

项目自有文档默认使用简体中文；命令、路径、配置键和代码字面量保持原样。每个提交只聚焦一个动机，不做无关格式化或重构。
