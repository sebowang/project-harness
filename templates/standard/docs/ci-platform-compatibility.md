# CI 平台兼容性

## 统一验证契约

无论使用哪个 CI 平台，都应在已安装 Harness 的目标仓库中执行：

```powershell
pwsh -NoProfile -File scripts/verify.ps1 -Scope All
```

该命令先检查 Harness 和 readiness，再运行项目在 `harness.config.json` 中确认的结构化验证命令。它不替代部署审批、生产权限或平台的 Secrets 管理。

## 平台状态

| 平台 | 支持方式 | 边界 |
|---|---|---|
| GitHub Actions | 本仓库 CI 已验证 | 目标项目需自行配置触发条件、分支保护和环境审批 |
| GitLab CI | 提供 `examples/ci/gitlab-ci.yml` | Runner 必须提供 `pwsh`，示例不创建或管理 Runner |
| CNB（cnb.cool） | 提供 `examples/ci/cnb.yml` 片段 | 使用前确认项目 Runner 已提供 `pwsh`，并按当前 CNB 配置规则合并 |

示例只验证已配置的项目，不包含发布、数据库迁移、云权限、Secrets 或审批步骤。高风险操作必须由目标平台的环境权限、受保护分支、审批与密钥管理机械约束。

## Onboarding 勘察

`project-onboarding` 的 Proposal 阶段应只读识别 Git remote 主机和现有 CI 入口：GitHub Actions、GitLab CI、CNB `.cnb.yml` 或未知平台。报告 remote 时只记录脱敏后的 host 和平台类型，不输出完整 URL、用户名或 Token。

已有 CI 只作为仓库事实和验证命令候选；没有用户确认时，不覆盖、迁移或复制 CI 文件。
