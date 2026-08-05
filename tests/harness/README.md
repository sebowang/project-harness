# Harness 验收

本目录存放可重复执行、与生产数据隔离的外部验收检查。不要只为满足目录约定而创建空测试。

当变更新增或修改外部接口请求构造或响应解析、字段映射、共享契约，或仅靠代码审查难以确认的可独立验证逻辑时，必须存在覆盖该行为的自动化测试。优先更新项目已有单元测试或集成测试；没有合适入口时，在本目录新增 Harness。若无法自动化，交付说明必须记录原因、替代验证、遗留风险和下一步。

每个 Harness 必须：

1. 有无隐藏交互步骤的文档化命令。
2. 通过返回 `0`，失败返回非零退出码。
3. 说明用途、前置条件、输入和预期结果。
4. fixture 放在 `tests/harness/data/`，不嵌入生产数据或凭据。
5. 能独立验证高价值行为、共享契约或重复性回归。
6. 说明其防止的具体回归；与已有测试相比没有新增失败模式时，优先合并或增强已有测试。

优先断言可观察结果、状态或边界，不要只验证偶然的私有调用路径。临时调试检查不必作为长期 Harness 提交；不要为了测试数量、目录或覆盖率创建 Harness。

新增脚本后，把命令加入 `harness.config.json`。下方索引由 `scripts/update-artifact-catalog.ps1` 维护，不要手工编辑标记区块。

## 当前 Harness

`tests/initialize-smoke.ps1` 在临时目录执行，不访问生产数据或外部服务；命令由根目录 `harness.config.json` 的 `projectValidation` 配置。

<!-- PROJECT-HARNESS:CATALOG:BEGIN -->
### Harness checks
No matching files.
<!-- PROJECT-HARNESS:CATALOG:END -->
