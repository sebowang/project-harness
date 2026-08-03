# 可选项目能力

Standard 只提供能力入口，不默认启用额外状态、依赖或外部系统操作。由 `project-onboarding` 根据仓库证据提出建议，用户确认后才写入项目文件。

## 能力选择

| 能力 | 适用场景 | 确认后应留下的项目证据 |
|---|---|---|
| `durable-plan` | EasyBIM 级跨会话、多阶段任务 | 一个 `docs/active-plan.md`，包含目标、已完成、下一步、验证、风险和阻塞；完成后归档或删除 |
| `architecture-checks` | 多模块、共享契约或依赖方向容易回归 | 项目自己的依赖/契约检查和 CI 入口；不能只写一段说明 |
| `database-risk` | 迁移、批量写入、恢复或生产数据 | 真实迁移前检查、备份/恢复演练和隔离环境证据 |
| `deployment-risk` | 有发布环境、审批和回滚要求 | CI/CD 检查、审批边界、发布记录和可验证回滚路径 |

`harness.config.json` 的 `capabilities` 是项目选择的标识数组，例如：

```json
{
  "capabilities": ["durable-plan", "database-risk"]
}
```

这个数组不构成安全边界，也不会自动授予权限或执行数据库、部署操作。高风险要求必须由项目真实的 CI、Hook、Sandbox、审批和环境权限机械执行。

小项目可以保持空数组；只有当重复工作或风险值得其维护成本时才启用能力。
