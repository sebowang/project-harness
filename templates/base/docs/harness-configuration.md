# Harness 配置

`harness.config.json` 保存本项目确认后的 Harness 配置。

`harness.lock.json` 保存安装版本和受管文件基线，供只读 `harness-status.ps1` 和后续安全更新使用。

## 字段

| 字段 | 类型 | 说明 |
|---|---|---|
| `schemaVersion` | number | 配置结构版本；当前只支持 `1` |
| `harnessVersion` | string | 创建或最近迁移该配置的 Harness 版本 |
| `profile` | `Light` 或 `Standard` | 初始化级别 |
| `projectName` | string | 项目显示名称 |
| `requiredPaths` | string array | 必须存在的 Harness 普通文件 |
| `projectValidation` | object array | 真实项目验证命令 |
| `driftChecks` | object array | 文档漂移断言 |
| `readiness` | object | 项目就绪条件和豁免 |

## 项目验证

```json
{
  "name": "Run tests",
  "executable": "dotnet",
  "arguments": ["test", "Example.sln", "--no-restore"]
}
```

使用 `executable + arguments`，不要配置交给 `Invoke-Expression` 的完整命令字符串。

## Readiness

`Standard` 默认设置 `readiness.requireProjectValidation` 为 `true`。确实没有可执行项目验证时，在 `projectValidationWaiver` 中记录具体原因；这会得到 `ready with waiver`，不代表项目验证已经通过。

所有项目事实占位符清除后，运行：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify.ps1 -Scope All
```

## 文档漂移

`driftChecks[].pattern` 是 .NET 正则表达式。每个条目还需要 `path`、`description` 和布尔值 `expectMatch`。
