# 发布指南

## 发布内容

Project Harness v1 以 Git tag 和源码发布。PowerShell 脚本不需要编译二进制；GitHub clone/pull 只是传输方式，目标仓库中的 `AGENTS.md`、配置、项目地图和验证记录仍由目标仓库自己长期版本控制。

发布前在干净工作树执行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests/initialize-smoke.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tests/check-template-neutrality.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify.ps1 -Scope All
git diff --check
```

确认 `templates/manifest.json`、根目录 `harness.config.json` 和 `harness.lock.json` 版本一致后，创建 tag：

```powershell
git tag -a v1.0.0 -m "Project Harness v1.0.0"
git push origin main --follow-tags
```

用户可以克隆固定 tag 后运行初始化器；后续维护从新 tag 或分支获取脚本，先 `-Update -WhatIf` 再执行 `-Update`。

## 发布边界

CI 的通过只证明 Harness 自身和本仓库 Smoke Test 通过，不证明任何目标业务项目、生产数据库或部署环境通过。高风险项目必须在自己的 CI、审批和环境权限中建立机械检查。
