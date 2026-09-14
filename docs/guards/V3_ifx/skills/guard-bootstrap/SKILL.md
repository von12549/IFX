---
name: guard-bootstrap
description: Analyze a target repository and configure a Guardrails V3 profile that can generate and verify an independent .NET gate.
---

Read the V3_ifx `README.md`, `DEPLOYMENT.md`, rule contract and technical design. The IFX profile is already in `profiles/ifx/`; inspect the target repository's actual project structure, build/test commands and CI jobs before revising it. Put technology selection in `tech-stack.json`, risk paths in `profile.json`, and supported stage rules in `rules/*.json`. The complete independent architecture policy is in `policy/layerguard.json`. For each proposed new rule, state what the detector proves and misses; use `kind: none`, `advisory`, `coverage: none` when no stage detector exists. Never label a prose-only stage rule blocking.

Run `Validate`, `Generate`, `Check`, and `Test` for both `Invoke-V3.ps1` and `Invoke-IFX.ps1` as documented in `DEPLOYMENT.md`. Verify a compliant and deliberately violating fixture for every new detector. Keep `V3_backup` and the old production gate unchanged. Report unsupported rules, required host-specific CI/Skill/Hook installation, and whether required merge checks are actually configured.
