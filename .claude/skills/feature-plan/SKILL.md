---
name: feature-plan
description: Create and manage a feature implementation plan. Guides through branch creation, plan file, and tracks status from Plan → Implementing → Testing → Done. Use when starting any non-trivial new feature.
argument-hint: [feature-name] [short description]
---

# Feature Plan: $ARGUMENTS

Create a structured feature plan for **$ARGUMENTS**, following the IFX project workflow.

## Step 1 — Read existing context

Before writing the plan:
- Read `CLAUDE.md` for architecture rules and golden rules
- Read `/.claude/architecture.md` for layer responsibilities
- Read any related existing plan files in `/.claude/Plans/` that may overlap
- Explore relevant source files to understand the current state

## Step 2 — Create the feature branch

Derive the branch name from `$ARGUMENTS` using the format `feature/<kebab-case-name>`.

```bash
git checkout -b feature/<kebab-case-name>
```

Confirm the branch was created and is checked out.

## Step 3 — Write the plan file

Save the plan to `/.claude/Plans/YYYYMMDD-<kebab-case-name>.md` (use today's date).

The plan file MUST include these sections:

```markdown
# Plan: <Feature Name>

**Status:** Plan

## Overview
One paragraph explaining what this feature does and why it is needed.

## Goals
- Bullet list of specific, measurable goals

## Non-Goals
- What is explicitly out of scope

## Architecture
- Which layers are touched (Domain / Application / Infrastructure / Presentation / Frontend)
- New entities, commands, queries, or endpoints
- Any new dependencies or external services
- ABAC / GlobalRole / multi-tenant considerations (if applicable)

## Implementation Steps
Ordered checklist of concrete tasks:
- [ ] Step 1
- [ ] Step 2
- ...

## Testing Plan
- Unit tests: what to cover
- Integration tests: what scenarios
- Manual tests: what to verify in the browser / API

## Open Questions
- Any unknowns that need resolution before or during implementation

## Status History
| Date | Status | Notes |
|------|--------|-------|
| YYYY-MM-DD | Plan | Plan created |
```

## Step 4 — Confirm before implementing

After the plan file is saved and the branch exists, **stop and present a summary** to the user:

- Branch name
- Plan file path
- High-level implementation steps
- Ask: "Ready to start implementing?"

Do NOT begin writing any production code until the user confirms.

## Status Lifecycle

Update the `Status:` field in the plan file header as work progresses:

| Status | Meaning |
|--------|---------|
| `Plan` | Plan created, no implementation started |
| `Implementing` | Active development in progress |
| `Testing` | Implementation complete; unit tests written; manual testing in progress; PR not yet merged |
| `Done` | PR merged to main |

When the user says "start implementing", update the plan header to `**Status:** Implementing`.
When the user says "ready for testing" or "open PR", update to `**Status:** Testing`.
When the PR is merged, update to `**Status:** Done`.

## Golden Rules (from CLAUDE.md)

- Dependencies flow inward only (Domain → Application → Infrastructure → Presentation)
- Domain has zero external dependencies
- One handler per command/query
- Result pattern for expected failures
- Provider-neutral Application layer
- New auth code goes in the correct subdomain folder (Users / Identity / Authorization)
