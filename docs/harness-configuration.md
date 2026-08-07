# Harness 配置

`harness.config.json` 保存本项目确认后的 Harness 配置。

`harness.lock.json` 保存安装版本和受管文件基线，供只读 `harness-status.ps1` 和后续安全更新使用。

`harness.config.json` 属于项目。安全 Update 不会自动改写它；若其中的 `harnessVersion` 与 lock 不同，Update plan 会提示人工复核该配置是否需要迁移。

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
| `artifactCatalogs` | object array | 由目录内容生成并校验的 README 索引 |
| `capabilities` | string array | 已由项目确认启用的可选能力标识 |
| `readiness` | object | 项目就绪条件和豁免 |

## 项目验证

```json
{
  "name": "Run tests",
  "kind": "test",
  "executable": "dotnet",
  "arguments": ["test", "Example.sln", "--no-restore"],
  "workingDirectory": "src/Example",
  "environment": { "DOTNET_NOLOGO": "1" },
  "timeoutSeconds": 300
}
```

使用 `executable + arguments`，不要配置交给 `Invoke-Expression` 的完整命令字符串。

`kind` 可选值为 `build`、`test`、`lint`、`smoke`、`custom`；省略时按 `custom` 处理。它描述这条命令能提供哪一层证据，不是对命令行为的自动认证。

`workingDirectory`、`environment` 与 `timeoutSeconds` 都是可选项。工作目录必须是仓库内的相对目录；环境变量只在该验证命令执行期间生效，不要把 Token、密码或其他 Secret 写入会提交的配置；超时必须是正整数秒，适合防止测试挂起。未配置时，命令在仓库根目录执行、继承当前环境且不设置超时。

## Readiness

`Standard` 默认设置 `readiness.requireProjectValidation` 为 `true`。确实没有可执行项目验证时，在 `projectValidationWaiver` 中记录具体原因；这会得到 `ready with waiver`，不代表项目验证已经通过。

需要某类证据才能报告普通 `ready` 时，在 `readiness.requiredValidationKinds` 中列出类别，例如 `["build", "test"]`。缺少类别且没有具体豁免会使 readiness 失败；有豁免时只能报告 `ready with waiver`。这允许遗留项目如实记录“结构和 Smoke Check 已通过，但本机没有可运行的 .NET Framework 构建工具”。

所有项目事实占位符清除后，运行：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify.ps1 -Scope All
```

## 文档漂移

`driftChecks[].pattern` 是 .NET 正则表达式。每个条目还需要 `path`、`description` 和布尔值 `expectMatch`。

只为稳定、可机械验证的项目事实配置窄断言，例如必须出现的模块名或已经废弃的旧表述。它不能自动判断项目地图中的职责和依赖是否真实。`scripts/check-doc-drift.ps1 -Staged` 会读取 Git 暂存区中的配置和文件；没有暂存的配置或受检路径时会跳过，避免普通提交产生无关负担。

## Artifact catalog

```json
{
  "name": "Harness checks",
  "directory": "tests/harness",
  "include": "*.ps1",
  "indexPath": "tests/harness/README.md"
}
```

`directory` 和 `indexPath` 必须位于仓库内，`include` 只能是文件名匹配模式。更新器按稳定顺序枚举目录的直接子文件，并只替换 README 中唯一的 `PROJECT-HARNESS:CATALOG` 标记区块：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/update-artifact-catalog.ps1
powershell -ExecutionPolicy Bypass -File scripts/check-artifact-catalog.ps1
```

若本项目从旧版 Standard 升级，项目拥有的 `harness.config.json` 和 `tests/harness/README.md` 不会被静默改写；应显式加入配置与标记区块后再启用检查。
