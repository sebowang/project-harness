# Harness 配置

`harness.config.json` 保存目标项目确认后的 Harness 配置。初始化器创建初始配置；项目可以补充验证命令、漂移断言和 readiness 豁免，但不得删除未知字段后假定旧工具仍兼容。

## 顶层字段

| 字段 | 类型 | 说明 |
|---|---|---|
| `schemaVersion` | number | 配置结构版本；当前只支持 `1` |
| `profile` | `Light` 或 `Standard` | 初始化级别 |
| `projectName` | string | 目标项目显示名称 |
| `requiredPaths` | string array | Harness 必需文件；当前条目都必须是普通文件 |
| `projectValidation` | object array | 真实项目验证命令 |
| `driftChecks` | object array | 项目定义的文档漂移断言 |
| `readiness` | object | 项目就绪条件和豁免 |

## 项目验证

每个 `projectValidation` 条目使用结构化命令：

```json
{
  "name": "Run tests",
  "executable": "dotnet",
  "arguments": ["test", "Example.sln", "--no-restore"]
}
```

`executable` 必须是可发现的程序，`arguments` 是字符串数组。不要把完整命令行作为单个字符串，也不要依赖 `Invoke-Expression`。

## Readiness

```json
{
  "readiness": {
    "requireProjectValidation": true,
    "projectValidationWaiver": null
  }
}
```

`Standard` 默认要求至少一个项目验证命令。项目确实没有可执行验证时，填写具体 `projectValidationWaiver`；完整检查会报告 `ready with waiver`。豁免不是验证通过，也不应用于仅仅尚未完成配置的项目。

## 文档漂移

```json
{
  "description": "Documented entrypoint remains current",
  "path": "docs/project-map.md",
  "pattern": "src/main\\.ts",
  "expectMatch": true
}
```

`pattern` 是 .NET 正则表达式，不是普通文本。`path` 必须指向目标仓库内的普通文件。
