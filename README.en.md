# Project Harness v1.3.6

[Chinese](README.md) | [English](README.en.md)

> **Change hands, change Agents, reopen the project next week - context stays.**
> Rules, decisions, and validation methods live in the repository. Anyone, or any Agent, can resume from the repo instead of depending on the previous chat.

Current version: `v1.3.6`. See [CHANGELOG.md](CHANGELOG.md), the [release guide](docs/release.md), and [compatibility and migration](docs/compatibility-and-migration.md) for release and upgrade boundaries.

## At a Glance

Project Harness is a non-destructive initializer for AI-assisted development. It creates only missing files and does not overwrite existing rules. After installation, you get:

- **Context that survives handoffs.** Rules, project facts, important decisions, and validation commands are versioned in the repository. Switching people, tools, or time does not mean starting the explanation again.
- **Agent-led installation.** Give Codex, Claude Code, or Trae one instruction. It resolves the release, clones it, previews the installation plan, and waits for your approval before writing.
- **Your existing work stays intact.** Existing files are preserved by default. When `AGENTS.md` already exists, only the managed Harness block is added or refreshed.
- **One rule set across AI tools.** Codex, Claude Code, and Trae read the same source of rules. One validation entry point reports whether the project is ready.
- **Repeatable checks where they help.** An optional pre-commit check catches stale Harness artifacts and configured documentation drift. Before delivery, Agents can review regressions, defects, and verification gaps.
- **Only as much process as the project needs.** Start with `Light`; move to `Standard` when the project needs repeatable workflows, handoffs, or governance.

Project Harness does not design your business architecture or invent build commands. Templates are domain-, language-, and framework-neutral. The initializer uses PowerShell: Windows runs it directly; macOS and Linux require PowerShell 7.

## The Problem It Solves

The hidden cost of AI-assisted development is lost context. An Agent built an API last month; the next person asks the same questions: What is the build command? Where does the code live? What are the project conventions?

Project Harness writes those answers into the repository and makes validation repeatable. Installation, pre-commit work, and delivery each have an appropriate check, while material changes still wait for human confirmation.

## Who It Is For

**Good fit:** long-lived projects; repositories handed between people or Agents; complex work that spans sessions; teams tired of explaining the same project context repeatedly.

**Not a good fit:** one-off scripts; small projects that never use AI Agents; repositories with a complete governance system that do not need a different workflow.

**Boundary:** Project Harness does not replace tests, CI, permissions, or approvals. It does not prescribe your source layout. `code/`, `src/`, `assets/`, and `notes/` remain project-owned; the Harness records their real roles and boundaries.

## Quick Start

### Option 1: Have an Agent Install It (Recommended)

Open Codex, Claude Code, or another terminal-capable Agent in the target repository and give it the instruction below. It retrieves the latest stable GitHub Release, previews what it will preserve, and writes only after you approve. It never relies on a path from the author's machine.

<details>
<summary>Expand and copy the install instruction</summary>

> Install the latest stable Release of the GitHub repository `sebowang/project-harness` into the current Git repository. First check the repository root and `git status --short`, preserving all existing modifications. Resolve the latest stable version from GitHub Releases and report its actual version number; clone that version into a system temporary directory, then run `scripts/initialize-project.ps1 -TargetPath <current repository> -Profile Standard -WhatIf` from the clone. Do not overwrite existing files by default. If the target already has an `AGENTS.md`, preview the managed-block merge with `-MergeProjectRules -WhatIf` and report what will be preserved; execute it only after confirmation. If a managed entry point conflicts with the template, report it and wait for confirmation before using `-Force`. Do not modify business source, dependencies, deployment, or Git configuration automatically. After installation, run the read-only Proposal phase of `project-onboarding`, report the local Hook state and conflict risk, do not enable capabilities or run external side-effect commands, and wait for confirmation.

</details>

If no stable Release can be found, the Agent must stop and report that fact. It must not fall back to `main`. The complete instruction with all boundaries is in [docs/usage-guide.en.md](docs/usage-guide.en.md).

### Option 2: Run It Manually

Install the basics in three steps:

```powershell
# 1. Preview the installation plan. Nothing is written.
powershell -ExecutionPolicy Bypass -File scripts/initialize-project.ps1 `
  -TargetPath "C:\path\to\your-repository" -Profile Standard -WhatIf

# 2. Install after reviewing the preview.
powershell -ExecutionPolicy Bypass -File scripts/initialize-project.ps1 `
  -TargetPath "C:\path\to\your-repository" -Profile Standard

# 3. Check that the Harness is installed and readable.
powershell -ExecutionPolicy Bypass -File scripts/verify.ps1 -Scope Harness
```

On PowerShell 7, use `pwsh -File ...` and `/path/to/repository`.

**When the target already has `AGENTS.md`:** it remains unchanged by default. Add `-MergeProjectRules` to connect Harness rules to the same file. The initializer adds or refreshes only the block between `<!-- PROJECT-HARNESS:BEGIN -->` and `<!-- PROJECT-HARNESS:END -->`; rules outside the block remain intact and the file is backed up before its first write.

### Configure the Project After Installation

Two configuration tasks make the Harness useful for a real project:

1. You do not need to know the build or test commands yourself. Ask an Agent to follow the read-only `project-onboarding` workflow and present a Proposal. It uses existing source, CI, and local tools to propose a configuration you can confirm before it writes project files.
2. Populate `docs/project-map.md` from real source, then configure the build, test, lint, or smoke checks that actually run under `harness.config.json.projectValidation`. Mark each command with a `kind`; compiled projects declare `build` in `readiness.requiredValidationKinds`.

Then run the full check:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify.ps1 -Scope All
```

`Standard` needs at least one project validation command. When no executable command is available, or a compiled project has no executable `build` evidence, record the specific reason in `readiness.projectValidationWaiver`. The result is `ready with waiver`, not an ordinary pass.

## What It Checks Automatically

Harness turns repeated checks into repeatable checkpoints while keeping humans in control of material changes.

| Capability | What happens | Boundary |
|---|---|---|
| **Pre-commit check** (optional) | On commit, checks whether the artifact catalog is synchronized and configured documentation assertions still hold, catching missed artifacts and documentation drift | Not installed automatically. Enable it explicitly with `scripts/install-git-hooks.ps1`. It checks Harness assets and documentation consistency, not business tests. |
| **Pre-delivery review** | Before delivery, an Agent can follow `adversarial-review` to inspect defects, regressions, scope drift, and verification gaps | A workflow for the Agent, not a CI gate. Use it when the task calls for that review. |
| **Unified validation** | One entry point checks Harness structure with `-Scope Harness`, and readiness plus real project commands with `-Scope All` | `-Scope All` is meaningful only after project validation commands are configured. |
| **Read-only diagnostics** | Reports installation state and pinpoints gaps | Does not modify files. |

`-Scope Harness` proves only that the Harness is installed and readable. It does not prove that the project builds or tests successfully. Hooks, tests, CI, permissions, and approvals do not replace one another.

## How to Use It After Installation

Harness does not change your source layout or dictate how you write code. When people or Agents change, or work resumes after a gap, everyone can find the same rules, project facts, and validation entry points.

| Situation | What to do |
|---|---|
| First adoption | Preview with `-WhatIf`. If an `AGENTS.md` already exists, decide whether to use `-MergeProjectRules`. Then have an Agent inspect the repository and confirm its understanding of the source layout and validation commands. |
| Everyday development | State the request and acceptance expectation, for example: "Implement this feature and validate it against the existing project rules." The Agent reads relevant context, then implements and verifies the change. |
| Whole-project refresh | Explicitly say "run a governance baseline refresh" or "organize the whole project." The Agent audits source and governance documentation read-only, presents a difference Proposal, and updates semantic documents such as the project map only after confirmation. |
| Complex or long-running work | Say "This task will take several days; create a plan first," or "Hand the current progress to the next session." Plans and handoffs are for cross-session, multi-phase, or high-risk work. |
| A decision or lesson worth keeping | Say "Check whether this discussion contains durable project knowledge. List candidates first; do not write files yet." The Agent records conclusions in the appropriate project document only after confirmation. |

For the full lifecycle, information routing, and workflow details, see the [detailed usage guide](docs/usage-guide.en.md).

## Profiles

| Profile | Intended use | Includes |
|---|---|---|
| `Light` | Small, short-lived, or documentation repositories | `AGENTS.md`, a project map, verification guidance, and unified scripts |
| `Standard` | Long-lived repositories with repeated human or Agent handoffs | Light plus workflows, Skills, requirements, decisions, lessons, documentation checks, an artifact catalog, and optional Hook support |

There is no generic automatic `Full` profile. Production releases, databases, infrastructure, and paid operations still need project-specific CI, permissions, approvals, and Hooks.

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

Small tasks do not need a plan or handoff file. Cross-session work keeps one handoff file; with `durable-plan` enabled, only work that spans sessions, has ordered phases, crosses a high-risk boundary, or depends on multiple modules keeps one `docs/active-plan.md`.

## Updates and Maintenance

Update the Harness with the same initializer: preview first, then apply.

### Ask an Agent to Update It

In a repository that already has Project Harness, give the Agent this instruction:

<details>
<summary>Expand and copy the update instruction</summary>

> Update Project Harness in the current Git repository. First confirm the repository root, `git status --short`, `harness.lock.json`, and the current Harness version, preserving all existing modifications. Resolve the latest stable Release from GitHub Releases and report its actual version number; clone that version into a system temporary directory, then run `scripts/initialize-project.ps1 -TargetPath <current repository> -Update -WhatIf` from the clone. Report planned changes, locally modified or missing managed files, conflicts, `ORPHANED` files, backup location, and expected impact. Do not use `-Force` to resolve an `-Update` conflict. Do not rewrite content outside the managed `AGENTS.md` block, `harness.config.json`, the project map, verification documentation, or business source. If the `AGENTS.md` managed block needs refreshing, first preview `-Update -MergeProjectRules -WhatIf`; run it only after confirmation. Wait for confirmation before applying the selected update. Afterward, run `scripts/harness-doctor.ps1` and `scripts/verify.ps1 -Scope Harness`; run `-Scope All` only when project validation is configured, confirmed, and actually passes. Do not install dependencies, enable Git Hooks, modify CI, or run deployment operations automatically.

</details>

The complete instruction with all boundaries is in [docs/usage-guide.en.md](docs/usage-guide.en.md).

### Update Manually

```powershell
# Preview the complete update plan. Nothing is written.
powershell -ExecutionPolicy Bypass -File scripts/initialize-project.ps1 `
  -TargetPath "C:\path\to\your-repository" -Update -WhatIf

# Apply after reviewing the preview.
powershell -ExecutionPolicy Bypass -File scripts/initialize-project.ps1 `
  -TargetPath "C:\path\to\your-repository" -Update
```

An update replaces only managed files that have not been changed locally since the last installation. When both sides changed a path, a file is missing, or a path conflicts, it stops before writing. Original files and the lock are backed up to `.harness-backup/<timestamp>/`. Files no longer managed by a new version are kept as `ORPHANED`; after confirming they are no longer needed and remain unmodified, remove them explicitly with `-Prune`.

`-Update` changes only managed Harness files and the lock baseline. It does not automatically configure project builds, tests, dependencies, or CI. Without `harness.lock.json`, it cannot safely infer the local baseline; report the situation and choose between reinstalling and a manual migration.

Optional capabilities:

- **Artifact catalog:** Standard indexes `tests/harness/*.ps1`. After adding or removing a script, run `scripts/update-artifact-catalog.ps1`; unified validation checks that the index is current.
- **Pre-commit check:** `scripts/install-git-hooks.ps1` enables it and `-Uninstall` removes it. It checks staged artifact catalogs and configured documentation-drift assertions. It operates only when `core.hooksPath` is unset or already `.githooks`, never overwrites an existing Hook, is not enabled during initialization, and does not replace full CI validation.
- **Read-only diagnostics:** `scripts/harness-status.ps1` and `scripts/harness-doctor.ps1`.

## Agent Compatibility

| Tool | Automatic entry point | Shared workflow source |
|---|---|---|
| Codex | `AGENTS.md`, `.agents/skills/` | `docs/workflows/` |
| Claude Code | `CLAUDE.md` importing `AGENTS.md`, `.claude/skills/` | `docs/workflows/` |
| Trae | `.trae/rules/project-harness.md` routing to `AGENTS.md` | `docs/workflows/` |

Tool-specific Skill entries only route to the shared workflow; they do not duplicate the rules. See the [Agent compatibility strategy](docs/agent-compatibility.md).

## Configure Real Validation

Under `harness.config.json.projectValidation`, configure each command with an evidence kind, executable, and arguments so the Harness can run it reliably:

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

Run the full check after configuration.

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
- [Implementation roadmap](docs/implementation-roadmap.md)

## License

[MIT](LICENSE)
