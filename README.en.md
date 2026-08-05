# Project Harness v1.3.3

[中文](README.md) | English

> Switching to another person, another AI Agent, or picking up a project after a week — the rules, decisions, and validation commands you hashed out are trapped in a chat history nobody else can reach.
> Project Harness puts them in the repository, so anyone or any Agent can recover context from the repo instead of the last conversation.

Project Harness is a non-destructive setup for AI-assisted development. It installs only what is missing and never overwrites your existing rules. Codex, Claude Code, and Trae read the same `AGENTS.md` as the single source of rules and share one validation entry point, `verify.ps1`.

Current version: `v1.3.3`. See [CHANGELOG.md](CHANGELOG.md), the [release guide](docs/release.md), and [compatibility and migration](docs/compatibility-and-migration.md) for versioning and upgrade boundaries.

## What Problem It Solves

The hidden cost of AI-assisted development is lost context. An Agent built that API last month; the next person to touch it asks the same questions again: what is the build command, where does the code live, what are the conventions?

Project Harness:

- **Keeps context in version control.** Rules, project facts, decisions, and validation commands all live in the repo, independent of any chat history.
- **Never destroys what you have.** It creates missing files by default. If an `AGENTS.md` already exists, the Harness rules can be merged into a managed block, leaving the rest of the file untouched.
- **One set of rules for every tool.** Codex, Claude Code, and Trae all read the same `AGENTS.md` / `docs/workflows/` conventions.
- **One validation entry point.** `verify.ps1` checks Harness structure, project readiness, and the validation commands you configured.
- **Starts small, grows when needed.** Begin with `Light`; adopt `Standard` when the project gets complex. Plans, handoffs, and lessons are created only when they become useful.

It does not design your architecture or guess build commands. The templates are domain-, language-, and framework-neutral. The initializer is PowerShell: it runs natively on Windows, and on macOS/Linux once PowerShell 7 is installed.

## Quick Start

Run these three steps in the target repository root:

```powershell
# 1. Preview the installation plan. Nothing is written.
powershell -ExecutionPolicy Bypass -File scripts/initialize-project.ps1 `
  -TargetPath "C:\path\to\your-repository" -Profile Standard -WhatIf

# 2. Install after reviewing the preview.
powershell -ExecutionPolicy Bypass -File scripts/initialize-project.ps1 `
  -TargetPath "C:\path\to\your-repository" -Profile Standard

# 3. Check that the Harness is ready.
powershell -ExecutionPolicy Bypass -File scripts/verify.ps1 -Scope Harness
```

On PowerShell 7, use `pwsh -File ...` with `/path/to/repository`.

**If the target already has an `AGENTS.md`:** it is not modified by default. To connect the Harness rules into the same file, add `-MergeProjectRules`. The initializer only adds or refreshes the managed block between `<!-- PROJECT-HARNESS:BEGIN -->` and `<!-- PROJECT-HARNESS:END -->`, leaves everything outside it alone, and backs up the original file before writing it for the first time.

`verify.ps1 -Scope Harness` proves only that the Harness is installed and its entry points are readable — not that your project passes a real build or test.

### Have an Agent Install It

Open Codex, Claude Code, or any terminal-capable Agent in the target repository and hand it this instruction. The Agent fetches the latest stable Release from GitHub and installs it into the current repository — no dependency on the author's machine paths.

<details>
<summary>Expand and copy the full install instruction</summary>

> Install the latest stable Release of the GitHub repository `sebowang/project-harness` into the current Git repository. First check the repository root and `git status --short`, and keep all existing modifications. Resolve the latest stable version from GitHub Releases and report the actual version number to me; clone that version into a system temp directory, then run `scripts/initialize-project.ps1 -TargetPath <current repository> -Profile Standard -WhatIf` from the clone. The default install must not overwrite existing files. If the target already has an `AGENTS.md`, preview the managed-block merge with `-MergeProjectRules -WhatIf` and report what is preserved, then execute with `-MergeProjectRules` after my confirmation. If the preview shows a managed entry point (for example `CLAUDE.md`) conflicting with the template, report the conflict and wait for confirmation before using `-Force` for the managed-file migration. Do not modify business source, dependencies, deployment, or Git configuration. After the install, run the read-only Proposal phase of `project-onboarding` and clearly report whether the local catalog Hook is enabled, whether you recommend enabling it, and any conflict risk. Do not enable capabilities or run external side-effect commands; wait for my confirmation of the proposal.

</details>

Existing rules and configuration are preserved. `-Force` is used only after your confirmation to migrate managed files, with a backup taken first. If no stable Release is found, the Agent stops and reports — it must not fall back to `main`.

### After Installation

Two configuration tasks make the Harness useful for your project:

1. Have the Agent run the read-only `project-onboarding` proposal, review it, and approve it before anything is written.
2. Fill in `docs/project-map.md` from real source, and configure the actual build, test, lint, or smoke commands under `projectValidation` in `harness.config.json`. Mark each command with its evidence `kind`; compiled projects should declare `build` under `readiness.requiredValidationKinds`.

Then run the full check:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify.ps1 -Scope All
```

`Standard` requires at least one project validation command. If no command can be configured, or a compiled project has no executable `build` evidence, explain why in `readiness.projectValidationWaiver`; the status then reads `ready with waiver` instead of a normal pass.

## How to Use It After Installation

Project Harness does not change your source-tree layout or prescribe how you write code. When people or Agents change, or work resumes after a gap, the repository still contains the same rules, project facts, and validation entry points. Four common situations:

| Situation | What to do |
|---|---|
| First adoption | Preview with `-WhatIf`; if an `AGENTS.md` already exists, decide whether `-MergeProjectRules` should connect the Harness block. Then have the Agent inspect the repository and confirm its understanding of the source layout and validation commands. |
| Everyday development | Describe the request normally, for example: "Implement this feature and validate it against the existing project rules." The Agent reads the repository rules and notes before it implements and verifies the change. |
| Complex or long-running work | Say "This task will take several days; create a plan first," or "Hand the current progress to the next session." Plans and handoffs are for cross-session, multi-phase, or high-risk work, not routine small tasks. |
| A decision or lesson worth keeping | Say "Check whether this discussion contains durable project knowledge. List candidates first; do not write files yet." The Agent records conclusions only after your confirmation and routes them to the correct project document. |

You still own project-specific decisions: real build and test commands, whether to merge existing rules, whether to enable a local hook, and permissions, approvals, and rollback for production operations. Project Harness does not replace tests, CI, permissions, or approvals.

The Harness does not prescribe source directories. `code/`, `src/`, `assets/`, and `notes/` remain owned by the target project; onboarding only records the real layout and responsibilities.

For the complete lifecycle, information routing, and workflow details, read the [detailed usage guide](docs/usage-guide.en.md).

## Profiles

| Profile | Intended use | Includes |
|---|---|---|
| `Light` | Small, short-lived, or documentation repositories | `AGENTS.md`, project map, verification guide, unified scripts |
| `Standard` | Long-lived repositories, or projects with repeated human and Agent handoffs | `Light` plus workflows, Skills, requirement/decision/lesson routing, document checks, artifact catalogs, optional Hook support |

There is no generic automatic `Full` profile. Configure CI, branch protection, permissions, approvals, deployments, databases, and production safeguards for the real project.

<details>
<summary>Structure generated by the Standard profile</summary>

```text
AGENTS.md
CLAUDE.md
harness.config.json
harness.lock.json
.trae/rules/project-harness.md
docs/
  harness-configuration.md
  project-map.md
  verification.md
  agent-compatibility.md
  workflows/*.md
  prd/README.md
  decisions/README.md
  reference/README.md
  lessons/README.md
.agents/skills/
  */SKILL.md
.claude/skills/
  */SKILL.md
scripts/
  check-artifact-catalog.ps1
  update-artifact-catalog.ps1
  install-git-hooks.ps1
  check-harness.ps1
  check-readiness.ps1
  check-doc-drift.ps1
  harness-status.ps1
  harness-doctor.ps1
  verify.ps1
tests/harness/README.md
.githooks/pre-commit
```

</details>

Small tasks do not need a plan or handoff file. Cross-session long-running work maintains one handoff file; with `durable-plan` enabled, only work that spans sessions, has ordered phases, crosses a high-risk boundary, or depends on multiple modules maintains a `docs/active-plan.md`.

## Updates and Maintenance

Update the Harness with the same initializer — preview first, then apply:

```powershell
# Preview the full update plan. Nothing is written.
powershell -ExecutionPolicy Bypass -File scripts/initialize-project.ps1 `
  -TargetPath "C:\path\to\your-repository" -Update -WhatIf

# Apply after reviewing.
powershell -ExecutionPolicy Bypass -File scripts/initialize-project.ps1 `
  -TargetPath "C:\path\to\your-repository" -Update
```

Updates replace only managed files that have not been locally modified since the last install. If both sides changed the same path, a file is missing, or a path conflicts, the update stops before writing; the original files and lock are backed up under `.harness-backup/<timestamp>/`. A file a new version no longer manages is kept by default and marked `ORPHANED`; once you confirm it is not needed and it has not been locally modified, clean it up explicitly with `-Prune`. The update plan also reports missing project-owned templates, configuration-version differences, and a stale managed `AGENTS.md` block; preview and confirm `-MergeProjectRules` when that block needs refreshing.

### Ask an Agent to Update It

In a target repository that already has Harness installed, give the following natural-language instruction to your Agent:

<details>
<summary>Expand and copy the update instruction</summary>

> Update Project Harness in the current Git repository. First confirm the repository root, `git status --short`, `harness.lock.json`, and the current Harness version, preserving all existing modifications. Resolve the latest stable Release from GitHub Releases and report the exact version, then clone that fixed version into a system temp directory and run `scripts/initialize-project.ps1 -TargetPath <current repository> -Update -WhatIf` from the clone. Report planned files, locally modified or missing managed files, conflicts, `ORPHANED` files, missing project-owned templates, configuration-version differences, whether the managed `AGENTS.md` block is stale, backup location, and expected impact. Do not use `-Force` to resolve an `-Update` conflict, and do not rewrite content outside the managed `AGENTS.md` block, `harness.config.json`, project map, verification docs, or business source. If the managed block needs refreshing, separately preview `-Update -MergeProjectRules -WhatIf`, then use `-Update -MergeProjectRules` only after confirmation; other project-owned files remain report-only. Wait for my confirmation before applying the selected update. After the update, run `scripts/harness-doctor.ps1` and `scripts/verify.ps1 -Scope Harness`; run and report `scripts/verify.ps1 -Scope All` only when project validation is configured and confirmed. Do not install dependencies, enable Git Hooks, modify CI, or run deployment operations automatically.

</details>

`-Update` changes only Harness-managed files and the lock baseline. It does not configure project builds, tests, dependencies, or CI. If `harness.lock.json` is missing, the local baseline cannot be inferred safely; stop and report whether to reinstall or perform a manual migration.

Optional capabilities:

- **Artifact catalog**: The Standard profile indexes `tests/harness/*.ps1` in a managed README block. Run `scripts/update-artifact-catalog.ps1` after adding or removing scripts; `verify.ps1 -Scope Harness` reports a stale catalog.
- **Local pre-commit hook**: `scripts/install-git-hooks.ps1`, with `-Uninstall` to remove. It works only when `core.hooksPath` is unset or already `.githooks`, never overwrites an existing hook, and is not installed automatically; CI should still run `scripts/verify.ps1 -Scope All`.
- **Read-only diagnostics**: `scripts/harness-status.ps1` and `scripts/harness-doctor.ps1`.

## Compatibility

| Tool | Entry point | Shared source |
|---|---|---|
| Codex | `AGENTS.md`, `.agents/skills/` | `docs/workflows/` |
| Claude Code | `CLAUDE.md` importing `AGENTS.md`, `.claude/skills/` | `docs/workflows/` |
| Trae | `.trae/rules/project-harness.md` routing to `AGENTS.md` | `docs/workflows/` |

Tool-specific entries only point to the shared workflow; they do not duplicate the full rules. See the [Agent compatibility strategy](docs/agent-compatibility.md) for details.

## Configuring Real Validation

Configure each project validation command as an evidence kind, executable, and arguments in `harness.config.json`, so the Harness can run it reliably:

```json
{
  "projectValidation": [
    {
      "name": "Run tests",
      "kind": "test",
      "executable": "dotnet",
      "arguments": ["test", "MyProject.sln", "--no-restore"]
    }
  ]
}
```

Then run `scripts/verify.ps1 -Scope All` for the full check.

## Principles and Workflows

- [Design principles](docs/design-principles.md)
- [Initialization workflow](docs/initialization-workflow.md)
- [Detailed usage guide](docs/usage-guide.en.md)
- [Knowledge Capture workflow](docs/workflows/knowledge-capture.md)
- [Decision Record guide](docs/decisions/README.md)
- [Lessons guide](docs/lessons/README.md)
- [Agent compatibility](docs/agent-compatibility.md)
- [CI platform compatibility](docs/ci-platform-compatibility.md)
- [Harness configuration](docs/harness-configuration.md)

## License

[MIT](LICENSE)
