# Harness 验收

本目录存放可重复执行、与生产数据隔离的外部验收检查。不要只为满足目录约定而创建空测试。

每个 Harness 必须：

1. 有无隐藏交互步骤的文档化命令。
2. 通过返回 `0`，失败返回非零退出码。
3. 说明用途、前置条件、输入和预期结果。
4. fixture 放在 `tests/harness/data/`，不嵌入生产数据或凭据。
5. 能独立验证高价值行为、共享契约或重复性回归。

新增脚本后，把命令加入 `harness.config.json`。下方索引由 `scripts/update-artifact-catalog.ps1` 维护，不要手工编辑标记区块。

## 当前 Harness

<!-- PROJECT-HARNESS:CATALOG:BEGIN -->
### Harness checks
No matching files.
<!-- PROJECT-HARNESS:CATALOG:END -->
