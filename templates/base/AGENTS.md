# {{PROJECT_NAME}} 协作指南

## 项目目标

TODO(HARNESS)：用两到三句话说明项目服务对象、核心能力和明确非目标。

## 修改前必读

1. 本文件。
2. `docs/project-map.md`。
3. 与任务相关的需求、决策、参考资料和模块 README。

若文档与代码冲突，先确认哪一项代表当前事实；不得静默选择更方便的解释。

## 变更规则

- 实施前确认目标、影响范围和验收路径，区分已验证事实与假设。
- 采用最小有效修改，不做无关重构、格式化或清理。
- 保留工作树中已有的用户修改，不覆盖或回退无关内容。
- 不根据目录名猜测架构、公共契约或运行时行为。
- 未经明确批准，不新增依赖、改变公共接口或执行破坏性操作。
- 发现任务范围显著扩大时，暂停并重新确认方案。

## 验证

- 使用 `docs/verification.md` 和 `harness.config.json` 选择真实检查。
- 运行与变更风险相称的构建、测试、Lint、Harness 或手工验收。
- 报告实际运行的命令、结果和尚未验证的内容。
- Harness 完整性通过不代表业务功能已经通过。

统一入口：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify.ps1 -Scope All
```

## 文档路由

- `docs/project-map.md`：当前架构事实、模块边界、依赖和验收入口。
- `docs/verification.md`：变更类型与验证证据的映射。

TODO(HARNESS)：Standard 模式下补充 PRD、ADR、Reference 与 Harness 的项目具体规则。

## 完成标准

只有在实现、验证和必要文档同步完成后，才能声称任务完成。无法运行检查时，明确记录原因、风险和建议的后续验证。
