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

## End-to-End Development Flow

Project Harness is not a one-time file generator. An installed project should use the same recoverable and verifiable flow for each meaningful change:

1. **Install and connect rules**: preview with `-WhatIf`; when `AGENTS.md` already exists, the user decides whether to add the managed block with `-MergeProjectRules`.
2. **Onboard the repository**: run the read-only `project-onboarding` Proposal stage. The Agent inspects source and existing documentation for real directories, module boundaries, build entry points, validation commands, existing rules, and risk capabilities. It writes project configuration only after confirmation.
3. **Start a task**: `project-start` reads `AGENTS.md`, the project map, verification guide, relevant PRDs, Active Decision Records, references, lessons, and `docs/handoff.md` when present.
4. **Plan the change**: non-trivial work uses `change-plan`. When `durable-plan` is enabled and a task crosses sessions, ordered phases, high-risk boundaries, or dependent modules, create or resume the single `docs/active-plan.md` before implementation.
5. **Implement and verify**: preserve existing work, make scoped changes, and run risk-proportionate build, test, lint, and Harness checks.
6. **Review and deliver**: shared or high-risk behavior uses `adversarial-review`, followed by `scripts/verify.ps1 -Scope All`.
7. **Capture durable knowledge**: the user can ask the Agent to inspect accessible conversation context and repository evidence. Discovery requests list candidates without writing; explicit capture requests route confirmed knowledge to the correct file.
8. **Continue across sessions**: `project-handoff` maintains the single `docs/handoff.md`. Completed work moves lasting conclusions into their durable sources instead of keeping a permanent session log.

```text
Installation preview -> Onboarding Proposal -> User confirms configuration
                     -> Project Start -> Change Plan / Active Plan
                     -> Implementation -> Tests -> Review -> Scope All
                     -> Knowledge candidates -> Confirmed capture -> Delivery or Handoff
```

The Harness improves rule discovery and context recovery, but it cannot guarantee that a model will never miss an instruction. Tests, CI, permissions, and approvals remain necessary mechanical controls.

## Where Project Knowledge Belongs

| Content | Primary location | Boundary |
|---|---|---|
| Stable mandatory development rules | `AGENTS.md` | Keep concise; project-specific rules stay outside the managed Harness block |
| Product goals, scope, and acceptance criteria | `docs/prd/` | Describes user needs, not architecture choices |
| Long-term choices and system invariants | `docs/decisions/` | One Decision Record format; use `Type` for `System Invariant` or `Architecture Decision` |
| Verified architecture, module, and interface facts | `docs/project-map.md`, `docs/reference/` | Must be verifiable from source, interfaces, or the environment |
| Reusable corrections, failures, and lessons | `docs/lessons/` | Does not replace rules, facts, or temporary logs |
| Stable repeatable procedures | `docs/workflows/` and the matching Skill | Promote only after at least two independent successful uses with clear validation |
| Current long-running task state | `docs/active-plan.md` | Keep one; do not create empty plans for small tasks |
| Cross-session handoff state | `docs/handoff.md` | Keep one; archive or remove it after completion |

See the [Knowledge Capture workflow](docs/workflows/knowledge-capture.md), [Decision Record guide](docs/decisions/README.md), and [Lessons guide](docs/lessons/README.md).

### Natural-language requests users can make

No fixed keyword or command syntax is required:

> Inspect the currently accessible conversation context and repository evidence for durable knowledge. List candidates and suggested destinations without modifying files.

> Record the compatibility decision we just confirmed. First decide whether it belongs in a Decision Record, a rule, or Lessons, then update the correct source.

> Decide whether this debugging procedure is mature enough to become a Skill. If it lacks reuse evidence, explain what is missing and do not create it yet.

The Agent must state the context and files it can actually access. It must not reconstruct unavailable sessions from memory or write files merely because words such as “Skill” or “decision” appeared.

## What Users Must Configure or Confirm

- Choose `Light` or `Standard`, and decide whether Harness rules should be merged into an existing `AGENTS.md`.
- Review the `project-onboarding` Proposal and confirm real module boundaries, validation commands, risk capabilities, and knowledge locations.
- Maintain executable build, test, lint, or smoke commands in `harness.config.json.projectValidation`.
- Decide whether to enable capabilities such as `durable-plan` and whether to install the optional local Git Hook.
- Run `scripts/verify.ps1 -Scope All` in CI. A bypassable local Hook cannot replace CI, permissions, or approvals.
- Preview upgrades with `-Update -WhatIf`, then resolve local conflicts and review `ORPHANED` files before applying them.
- Keep project-specific controls for production releases, database migrations, external messages, paid operations, and other high-impact actions.

The Harness does not prescribe source directories. `code/`, `src/`, `assets/`, and `notes/` remain owned by the target project; onboarding only records the real layout and responsibilities.

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
- [Knowledge Capture workflow](docs/workflows/knowledge-capture.md)
- [Decision Record guide](docs/decisions/README.md)
- [Lessons guide](docs/lessons/README.md)
- [Agent compatibility](docs/agent-compatibility.md)

## License

[MIT](LICENSE)
