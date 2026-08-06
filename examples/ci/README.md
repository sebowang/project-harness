# CI 参考示例

这些示例将 Harness 的统一验证入口接入 GitHub Actions、GitLab CI 与 CNB（cnb.cool）。它们不是默认模板，也不会由初始化器写入目标项目。

复制前确认项目 Runner 中存在 `pwsh`，并将项目自己的构建、测试和 Lint 命令配置到 `harness.config.json`。发布、Secrets、审批、数据库迁移和云权限必须由目标项目的平台配置处理。
