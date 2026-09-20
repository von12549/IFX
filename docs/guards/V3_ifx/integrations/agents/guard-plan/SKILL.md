---
name: guard-plan
description: Create or revise a coding Plan using a configured Guardrails V3 profile before a substantial or high-risk implementation.
---

Read the package `README.md`, `shared/profile-layout.json`, `stages/pre/project-map.json`, `shared/toolchain.json`, applicable `stages/post/rules/*.json`, `policy/layerguard.json`, and `templates/plan/README.md`. Identify exact proposed paths, owning areas, nearby examples, risk triggers and focused validation command IDs. For an ordinary low-risk edit, run `commands/Invoke-IFXGuardrails.ps1 -Mode Pre -PlannedPaths <exact-paths>` and record its JSON summary. For substantial or risk-triggered work, create matching Markdown and JSON Plan files with a goal, acceptance criteria, exact paths, all affected area IDs, all applicable rule IDs, focused command IDs and covering decisions. Run `-Mode Pre -PlanPath <sidecar>` and revise until it passes. A successful Pre report is advisory; it does not check code or decision quality. When scope or risk changes, update the Plan and rerun Pre. After coding, run the V3 stage `Test`, independent architecture gate, Diff and other applicable CI checks. Report uncovered semantics explicitly.
