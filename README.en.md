# Project Harness v1.2.0

[中文](README.md) | English

Project Harness is a generic, non-destructive setup for AI-assisted software development. It puts project rules, verified architecture facts, decisions, repeatable workflows, and validation commands in the repository so future Codex, Claude Code, and Trae sessions can recover context from files instead of relying on chat history.

It is domain-, language-, and framework-neutral. The templates do not contain EasyBIM, BackStage, WPF, or other private project assumptions.

## What It Does

- Provides `Light` and `Standard` installation profiles.
- Uses `AGENTS.md` as the single shared rule source.
- Routes Claude Code through `CLAUDE.md` and Trae through `.trae/rules/` without duplicating the rules.
- Adds common workflows for project startup, planning, testing, debugging, handoff, and review.
- Keeps project-owned files and existing rules by default.
- Records managed-file baselines in `harness.lock.json` for safer updates.
- Checks Harness structure, readiness, configured drift rules, and artifact catalogs through one verification entry point.
- Provides routing for PRDs, Decision Records, references, durable lessons, and one active plan for long-running work without imposing a source-tree layout.
- Supports explicit, reversible merging of a managed Harness block into an existing `AGENTS.md`.
- Provides an optional Git pre-commit Hook for local catalog feedback without changing Git configuration automatically.

## Quick Start

From the target repository, preview the installation first:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/initialize-project.ps1 `
  -TargetPath "C:\path\to\your-repository" `
  -Profile Standard -WhatIf
```

Install after reviewing the preview:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/initialize-project.ps1 `
  -TargetPath "C:\path\to\your-repository" `
  -Profile Standard
```

If the target already has an `AGENTS.md`, use `-MergeProjectRules` to add the Harness-managed block while preserving the rest of the file. Use `-Force` only after reviewing a managed-file migration; project-owned files such as `AGENTS.md`, `harness.config.json`, and project documentation are not overwritten by `-Force`.

After installation:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify.ps1 -Scope Harness
powershell -ExecutionPolicy Bypass -File scripts/verify.ps1 -Scope All
```

`Harness` verifies the Harness itself. `All` also runs readiness checks and the project validation commands explicitly configured in `harness.config.json`.

## How to Use It After Installation

Project Harness does not change your source-tree layout or prescribe how you write code. It solves a different problem: when people or Agents change, or work resumes after a gap, everyone can recover the same rules, project facts, and validation entry points.

There are four common situations:

1. **First adoption**: preview with `-WhatIf`. If an `AGENTS.md` already exists, decide whether `-MergeProjectRules` should connect the Harness block. Then ask the Agent to inspect the repository and confirm its understanding of the source layout and validation commands.
2. **Everyday development**: describe the request normally, for example: “Implement this feature and validate it against the existing project rules.” The Agent should recover context, implement, and verify without requiring you to orchestrate every internal workflow.
3. **Complex or long-running work**: say “This task will take several days; create a plan first,” or “Hand the current progress to the next session.” Plans and handoffs are for cross-session, multi-phase, or high-risk work, not routine small tasks.
4. **A decision or lesson worth keeping**: say “Check whether this discussion contains durable project knowledge. List candidates first; do not write files yet.” The Agent records conclusions only after confirmation and routes them to the correct project document.

```text
Install and confirm project configuration -> Everyday development and validation
                                           -> Plan or handoff for complex work
                                           -> Confirmed capture of durable knowledge
```

You still own project-specific decisions: real build and test commands, whether to merge existing rules, whether to enable a local Hook, and permissions, approvals, and rollback for production operations. Harness does not replace tests, CI, permissions, or approvals.

The Harness does not prescribe source directories. `code/`, `src/`, `assets/`, and `notes/` remain owned by the target project; onboarding only records the real layout and responsibilities.

For the complete lifecycle, information routing, and workflow details, read the [detailed usage guide](docs/usage-guide.en.md).

## Existing Projects

The initializer preserves existing files by default. For a repository that already has project-specific rules, the safe adoption path is:

1. Run initialization with `-WhatIf`.
2. Use `-MergeProjectRules` if the existing `AGENTS.md` should also route to Harness rules.
3. Review any managed-entry collision before using `-Force`.
4. Run the read-only `project-onboarding` proposal workflow.
5. Configure only verified project build, test, lint, or smoke commands.

Updates use `harness.lock.json` to distinguish unchanged managed files from local modifications. Conflicting updates stop before writing and preserve a backup under `.harness-backup/<timestamp>/`.

## Artifact Catalogs

Standard projects can register directories whose files are indexed in a project-owned README block. The default catalog covers `tests/harness/*.ps1`.

The Harness does not create or move project-owned `code/`, `src/`, `assets/`, or `notes/` directories. It records the layout discovered during onboarding. When `durable-plan` is explicitly enabled, a task that spans sessions, has ordered phases, waits for external input, crosses a high-risk boundary, or has dependent modules must use the single `docs/active-plan.md`; small tasks do not create an empty plan.

```powershell
powershell -ExecutionPolicy Bypass -File scripts/update-artifact-catalog.ps1
powershell -ExecutionPolicy Bypass -File scripts/check-artifact-catalog.ps1
```

The updater replaces only the block between `PROJECT-HARNESS:CATALOG:BEGIN` and `PROJECT-HARNESS:CATALOG:END`. Text outside the markers remains project-owned. `verify.ps1 -Scope Harness` fails when the catalog is stale.

## Optional Git Hook

The Standard profile includes a pre-commit Hook file, but installation is deliberately explicit because it changes the repository's local `core.hooksPath` setting:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/install-git-hooks.ps1
powershell -ExecutionPolicy Bypass -File scripts/install-git-hooks.ps1 -Uninstall
```

The installer refuses to overwrite another hooks path and never edits or stages the catalog automatically. Hooks are local feedback, not a security boundary; CI should still run `scripts/verify.ps1 -Scope All`.

`harness-doctor.ps1` reports whether the optional catalog Hook is enabled. The `project-onboarding` proposal also surfaces this decision so users do not need to know the Hook exists in advance.

## Profiles

| Profile | Intended use | Includes |
|---|---|---|
| `Light` | Small, short-lived, or documentation repositories | Rules, project map, verification guide, and unified scripts |
| `Standard` | Long-lived repositories with repeated human or Agent participation | `Light` plus workflows, skills, PRD/decision/reference/lesson routing, drift checks, artifact catalogs, and optional Hook support |

There is no generic automatic `Full` profile. CI, branch protection, permissions, approvals, deployments, databases, and production safeguards must be configured from the real project's evidence.

## Compatibility Model

| Tool | Entry point | Shared source |
|---|---|---|
| Codex | `AGENTS.md`, `.agents/skills/` | `docs/workflows/` |
| Claude Code | `CLAUDE.md` importing `AGENTS.md`, `.claude/skills/` | `docs/workflows/` |
| Trae | `.trae/rules/project-harness.md` | `AGENTS.md`, `docs/workflows/` |

Tool-specific entries are thin routing files. Compatibility means that the repository exposes the expected entry points; it does not guarantee that a model will follow every instruction or replace mechanical controls such as CI, permissions, and approvals.

## Development and Release Checks

From this repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests/initialize-smoke.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tests/check-template-neutrality.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify.ps1 -Scope All
git diff --check
```

See [CHANGELOG.md](CHANGELOG.md), [release guide](docs/release.md), and [compatibility and migration](docs/compatibility-and-migration.md) for versioning and upgrade boundaries.

Additional design and workflow references:

- [Design principles](docs/design-principles.md)
- [Initialization workflow](docs/initialization-workflow.md)
- [Detailed usage guide](docs/usage-guide.en.md)
- [Knowledge Capture workflow](docs/workflows/knowledge-capture.md)
- [Decision Record guide](docs/decisions/README.md)
- [Lessons guide](docs/lessons/README.md)
- [Agent compatibility](docs/agent-compatibility.md)

## License

[MIT](LICENSE)
