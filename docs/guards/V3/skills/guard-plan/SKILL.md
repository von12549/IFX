---
name: guard-plan
description: Create or revise a coding Plan using a configured Guardrails V3 profile before a substantial or high-risk implementation.
---

Read the package `README.md`, the target profile, relevant rule files and `templates/plan/README.md`. For a formal Plan, create matching Markdown and JSON files from the template, with repository-relative expected paths, relevant rule IDs, validation commands and decision paths. Run `scripts/Invoke-V3.ps1 -Mode Pre` against the JSON sidecar and use its findings to revise the Plan. Pre validates a proposed change only; do not report code as checked. When implementation reveals a new path or risk, update the Plan and run Pre again before continuing. After coding, use the generated .NET check and the target repository's CI process; report unimplemented coverage explicitly. Do not copy the synthetic sample rule into a production profile.
