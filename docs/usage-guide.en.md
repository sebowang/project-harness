# Project Harness Usage Guide

This guide explains the complete Harness workflow. For a first introduction, start with “How to Use It After Installation” in the root `README.en.md`; small tasks do not require memorizing the terms below.

## Two Things to Remember

Harness is not a new development framework and does not require a source-tree migration. It moves collaboration information that would otherwise live in chat history, personal habits, or tool settings into readable, updateable, and verifiable project files.

Users do not need to orchestrate every Skill. For routine work, state the request and expected outcome. Ask explicitly for a plan, handoff, or knowledge review only when the work is complex, spans sessions, or produces a durable lesson or decision.

## Four Common Situations

| Situation | What the user does | What the Agent does |
|---|---|---|
| First adoption | Preview installation and decide whether to merge existing rules | Inspect the repository and present an onboarding Proposal without changing business configuration unilaterally |
| Everyday work | Describe the request and acceptance expectations | Recover relevant context, make the smallest change, and validate it |
| Long-running or cross-session work | Ask for a plan or handoff explicitly | Maintain one active plan or handoff file rather than multiple state logs |
| A decision or lesson worth keeping | Ask for candidates first, or explicitly request a record | Inspect only accessible conversation context and repository evidence, then route knowledge to one appropriate durable location |

Natural-language requests are enough:

> Implement this feature and validate it against the existing project rules.

> This task will take several days. Create a plan before implementation.

> Hand the current progress to the next session, including verified work, remaining risks, and next steps.

> Check whether this discussion contains durable project knowledge. List candidates and suggested locations first; do not modify files.

## The Agent Workflow

This is how Harness brings a meaningful development task to a verified conclusion. It is the default internal workflow; users do not need to invoke each step manually.

1. **Adopt and inspect**: preview installation with `-WhatIf`. When `AGENTS.md` already exists, the user decides whether to use `-MergeProjectRules`. Then `project-onboarding` identifies real directories, module boundaries, build entry points, validation commands, and risk capabilities from source and existing documentation. It presents a Proposal before changing project configuration.
2. **Start a task**: `project-start` reads project rules, the project map, verification guidance, and relevant requirements, decisions, references, lessons, and handoff material.
3. **Plan a change**: non-trivial work uses `change-plan` to define expected behavior, scope, unacceptable behavior, and verification. When `durable-plan` is enabled, cross-session, multi-phase, high-risk, or multi-module work must create or resume the single `docs/active-plan.md` first.
4. **Implement and validate**: the Agent preserves existing worktree changes, makes only task-related edits, and runs risk-proportionate build, test, lint, or smoke checks.
5. **Review and deliver**: shared or high-risk behavior uses `adversarial-review` to identify regressions, scope drift, and missing checks, followed by `scripts/verify.ps1 -Scope All`.
6. **Capture or hand off**: `project-handoff` maintains the one `docs/handoff.md` file when work continues in a later session. Lasting conclusions move into durable project documentation rather than remaining in plans or handoffs forever.

## Where Information Belongs

| Content | Primary location | Boundary |
|---|---|---|
| Stable mandatory development rules | `AGENTS.md` | Keep concise; project-specific rules stay outside the managed Harness block |
| Product goals, scope, and acceptance criteria | `docs/prd/` | Describes user needs, not architecture choices |
| Long-term choices and system invariants | `docs/decisions/` | One Decision Record format; `Type` is `System Invariant` or `Architecture Decision` |
| Verified architecture, module, and interface facts | `docs/project-map.md`, `docs/reference/` | Must be verifiable from source, interfaces, or the environment |
| Reusable corrections, failures, and lessons | `docs/lessons/` | Does not replace rules, facts, or temporary logs |
| Stable repeatable procedures | `docs/workflows/` and the matching Skill | Promote only after two independent successful uses with clear input, output, and validation |
| Current long-running task state | `docs/active-plan.md` | Keep one; do not create empty plans for small tasks |
| Cross-session handoff state | `docs/handoff.md` | Keep one; archive or remove it after completion |

Do not put every detail in `AGENTS.md`, and do not turn a one-off lesson into a Skill. See the [Knowledge Capture workflow](workflows/knowledge-capture.md), [Decision Record guide](decisions/README.md), and [Lessons guide](lessons/README.md) for the routing rules.

## Discovering and Recording Knowledge

Users do not need fixed keywords. They can naturally ask to inspect, record, or preserve knowledge. The Agent must first state its actual review scope: only readable conversation context and repository evidence count. It must not reconstruct inaccessible historical sessions from memory.

When the request is discovery-only, the Agent reports candidates, evidence, suggested destinations, and the risk of not recording them without changing files. It writes only after an explicit request to record or update; when classification would materially affect the result, it presents the recommendation before writing.

Even when a user asks to “make it a Skill,” the Agent should not create one immediately. A workflow needs at least two independent successful uses and a clear description of inputs, steps, failure signals, verification, and limitations before promotion.

## What Users Still Confirm

- Choose `Light` or `Standard`, and decide whether Harness rules should merge into an existing `AGENTS.md`.
- Review the `project-onboarding` Proposal and confirm real module boundaries, validation commands, risk capabilities, and knowledge locations.
- Maintain executable build, test, lint, or smoke commands in `harness.config.json.projectValidation`.
- Decide whether to enable capabilities such as `durable-plan` and whether to install the optional local Git Hook.
- Run `scripts/verify.ps1 -Scope All` in CI. A bypassable local Hook cannot replace CI, permissions, or approvals.
- Preview upgrades with `-Update -WhatIf`, then resolve local conflicts and review `ORPHANED` files before applying them.
- Keep project-specific controls for production releases, database migrations, external messages, paid operations, and other high-impact actions.
