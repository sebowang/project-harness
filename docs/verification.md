# 验证指南

## 分层验证

| 层级 | 证明内容 | 不证明内容 |
|---|---|---|
| Harness | 规则、配置和必需文件可读取 | 业务逻辑正确 |
| Build | 项目能够编译或打包 | 用户流程正确 |
| Tests | 已覆盖行为满足断言 | 未覆盖集成路径正确 |
| Lint/Type Check | 静态约束满足 | 运行时行为正确 |
| Smoke/Manual | 目标流程可观察地工作 | 全量回归通过 |

## 统一入口

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify.ps1 -Scope Harness
powershell -ExecutionPolicy Bypass -File scripts/verify.ps1 -Scope Project
powershell -ExecutionPolicy Bypass -File scripts/verify.ps1 -Scope All
```

`Harness` 验证安装结构、文档漂移断言和 artifact catalog。`All` 还会运行 readiness 检查和项目验证，是判断项目是否可以报告为 `ready` 或 `ready with waiver` 的入口。readiness 只检查配置是否覆盖项目声明的证据层级；命令是否实际通过仍以随后运行的项目验证结果为准。

`verify.ps1` 不比较受管文件与 `harness.lock.json` 中的安装基线。需要查看受管文件是否被本地修改、缺失或尚无可信基线时，运行 `scripts/harness-status.ps1`；它是状态诊断，不替代项目验证。

## 项目验证

本仓库已验证的项目检查写入 `harness.config.json`：`powershell -NoProfile -ExecutionPolicy Bypass -File tests/initialize-smoke.ps1`。该 Smoke Test 在临时目录验证安装、Light/Standard、WhatIf、Harness readiness、artifact catalog、可选 Hook、状态/doctor、受管文件更新、新文件升级和冲突停止。

`Standard` 默认要求至少一个项目验证命令。对编译型项目，应在 `readiness.requiredValidationKinds` 声明 `build`，并给每条命令标注 `kind`。确实没有可运行命令或关键证据层级缺失时，在 `readiness.projectValidationWaiver` 中记录具体原因；此时完整检查报告 `ready with waiver`，不代表业务构建或测试已经通过。

## 变更类型矩阵

涉及外部接口请求构造或响应解析、字段映射、共享契约，或仅靠代码审查难以确认的可独立验证逻辑时，“相关测试”必须是覆盖所改行为的自动化测试，可为已有或新增的单元、集成或 Harness 测试。无法自动化时，记录原因、替代验证、遗留风险和下一步，并优先评估最小的可测边界调整。

| 变更类型 | 必需验证 | 可选补充 |
|---|---|---|
| 文档 | Harness 检查、事实与链接复核 | 文档构建 |
| 局部逻辑 | 覆盖所改行为的自动化测试 | 全量测试 |
| 公共接口、数据契约 | 覆盖契约的自动化测试、调用方检查 | 集成测试 |
| 依赖/构建 | 构建、锁文件或产物检查 | Smoke Check |
| 用户流程 | 相关测试、正常与失败路径 | 端到端测试 |

## 无法验证时

记录：未运行的命令、原因、风险、已完成的替代检查和下一位实施者应执行的动作。不得把“未运行”写成“通过”。
