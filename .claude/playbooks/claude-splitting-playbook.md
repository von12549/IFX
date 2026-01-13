# Splitting Playbook for Existing CLAUDE.md

## Goal
Split the existing `CLAUDE.md` into a structured, maintainable instruction system:
- Root `CLAUDE.md` stays minimal and authoritative.
- Detailed guidance is decomposed into topical documents in `/.claude/`.
- Optional module-local `CLAUDE.md` files exist only when rules truly differ per module.

This process must minimize duplication, reduce irrelevant context, and preserve all meaningful constraints.

---

## Inputs
- Current file: `/CLAUDE.md` (the “legacy monolith”)
- Target folder: `/.claude/`

---

## Output Structure (Target)
Create or update these files as needed:

### Root
- `/CLAUDE.md` (keep short; index + golden rules only)

### Global Docs
- `/.claude/architecture.md` (DDD/Clean/Modular invariants)
- `/.claude/coding-standards.md` (general language-agnostic style)
- `/.claude/git-workflow.md` (commit/branch/versioning rules)
- `/.claude/decisions.md` (key decisions & rationale; stable ADR-like notes)
- `/.claude/glossary.md` (terms, abbreviations, module naming)

### Technology Packs (create only if relevant content exists)
- `/.claude/dotnet/overview.md`
- `/.claude/dotnet/ddd.md`
- `/.claude/dotnet/cqrs.md`
- `/.claude/dotnet/ef-core.md`
- `/.claude/dotnet/testing.md`
- `/.claude/r-bioinformatics/pipeline.md`
- `/.claude/r-bioinformatics/preprocessing.md`
- `/.claude/r-bioinformatics/ml.md`
- `/.claude/r-bioinformatics/visualization.md`

### Optional Module Local Rules
If and only if module-specific constraints exist, create:
- `src/Modules/<ModuleName>/CLAUDE.md`

---

## Splitting Method (Deterministic)

### Step 1 — Parse & Classify
Read the legacy `/CLAUDE.md` line-by-line and classify each instruction into exactly one bucket:

A) **Architecture invariants** (must always hold)
B) **Coding standards** (style, conventions, formatting, logging, error handling)
C) **Workflow** (Git, PR, branching, release)
D) **Technology-specific** (.NET / EF Core / AWS / R / Bioinfo)
E) **Module-specific** (applies only within one module)
F) **Examples / templates** (sample code, snippets, boilerplates)
G) **Historical / obsolete** (old decisions, deprecated rules)

If an instruction seems to fit multiple buckets, choose the narrowest scope:
- module-specific > tech-specific > global

### Step 2 — De-duplicate & Normalize
For each bucket:
- Remove exact duplicates.
- Merge near-duplicates into a single canonical rule.
- Preserve intent, constraints, and edge cases.
- Keep wording imperative and testable.

### Step 3 — Move Content into Target Files
Move each rule into the corresponding file:
- Architecture invariants → `/.claude/architecture.md`
- General conventions → `/.claude/coding-standards.md`
- Git/process rules → `/.claude/git-workflow.md`
- Tech rules → respective tech pack doc
- Module rules → module local `CLAUDE.md` only

### Step 4 — Keep Root CLAUDE.md Minimal
Rewrite `/CLAUDE.md` so it:
- Contains only golden rules + index + conflict resolution.
- Does NOT include detailed rules, examples, or module specifics.
- References the new docs instead.

### Step 5 — Create a “Decision Log” (If Needed)
If legacy content includes “why we do this” or tradeoffs:
- Put stable rationale into `/.claude/decisions.md`.
- Keep it brief and factual, not conversational.

### Step 6 — Verification Checklist
After split, verify:
1) No important constraint was lost.
2) Root file is short (ideally <= 150 lines).
3) Each new file has a clear scope header.
4) No rule appears in more than one place unless it is an index link.
5) Module local docs exist only where truly needed.

---

## Writing Standards for All New Docs
- Start each file with:
  - Purpose
  - Scope (what it covers / does not cover)
  - “Non-goals” if necessary
- Use consistent rule format:
  - **Rule:** imperative statement
  - **Rationale:** 1-2 lines (optional; only for non-obvious rules)
  - **Examples:** short, only if it prevents misinterpretation
- Keep each rule atomic and enforceable.
- Avoid long essays; prefer bullet points.

---

## Required Deliverables
When executing this playbook, produce:
1) Updated `/CLAUDE.md`
2) Created/updated `/.claude/*` documents
3) A brief `/.claude/split-report.md` that lists:
   - What moved where (high-level)
   - Any removed/deprecated items
   - Any ambiguities or conflicts detected and how they were resolved

---

## Guardrails
- Do not invent new project rules.
- Do not delete content unless clearly obsolete/redundant; if removed, record it in `split-report.md`.
- If a rule is unclear, preserve it but mark it with:
  - `TODO(clarify): ...` and include it in `split-report.md`.

End of playbook.
