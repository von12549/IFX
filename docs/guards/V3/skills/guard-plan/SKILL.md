---
name: guard-plan
description: Create or revise a coding Plan using a configured Guardrails V3 profile before a substantial or high-risk implementation.
---

Read the package `README.md`, selected profile's `project-map.json`, `tech-stack.json`, applicable rule files, and `templates/plan/README.md`. Locate affected areas, owners, nearby examples, risk triggers and focused command IDs. For an ordinary edit, run `commands/Invoke-V3.ps1 -Mode Pre -PlannedPaths <exact-paths>` and record the summary. For substantial or risk-triggered work, create matching Markdown and JSON files from the template, with an observable goal, acceptance criteria, exact paths, all affected area IDs, all applicable rule IDs, focused validation command IDs and covering decisions. Run `-Mode Pre -PlanPath <sidecar>`, read its JSON report and revise until it passes. A successful Pre result is advisory and does not verify future code or decision quality. When implementation reveals another path or risk, update the Plan and rerun Pre. After coding, run the generated .NET check and applicable target CI checks; report uncovered rules explicitly. Do not copy the synthetic sample rule into a production profile.
