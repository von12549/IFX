---
name: guard-bootstrap
description: Analyze a target repository and configure a Guardrails V3 profile that can generate and verify an independent .NET gate.
---

Read the V3 `README.md`, `DEPLOYMENT.md`, rule contract and technical design. Inspect the target repository's actual project structure, build/test commands, existing policy authorities and CI jobs before creating a profile outside the reusable default example. Put the technology selection in `tech-stack.json`, risk paths in `profile.json`, and one rule JSON per stable ID. Reuse existing authoritative detectors rather than copying their policy values. For each candidate rule, state what the supported detector proves and what it misses; use `kind: none`, `advisory`, `coverage: none` when no detector exists. Never label a prose-only rule blocking.

Run `Validate`, `Generate`, `Check`, and the generated `Test` in an isolated target or output directory first. Verify at least one compliant and one deliberately violating fixture for every new detector kind. Keep target-specific profile files and generated trial output separate from the reusable V3 default package. Report unsupported rules, required host-specific CI/Skill/Hook installation, and whether required merge checks are actually configured. Do not change an existing production gate as a side effect of bootstrapping V3.
