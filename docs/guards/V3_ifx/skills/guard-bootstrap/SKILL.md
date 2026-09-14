---
name: guard-bootstrap
description: Analyze a target repository and configure a Guardrails V3 profile that can generate and verify an independent .NET gate.
---

Read the V3_ifx `README.md`, `DEPLOYMENT.md`, rule contract and technical design. The IFX profile is already in `profiles/ifx/`; run `Invoke-V3Setup.ps1 -Mode Analyze` and review its inventory against actual project structure, commands, existing policy and CI before revising it. Keep technology and commands in `tech-stack.json`, areas/owners/risk triggers in `project-map.json`, and supported stage rules in `rules/*.json`. The complete independent architecture policy is in `policy/layerguard.json`. Treat analysis findings as candidates, never automatic policy. For each proposed rule, state what its detector proves and misses; use `kind: none`, `advisory`, `coverage: none` when no stage detector exists. Never label a prose-only stage rule blocking.

Use `Invoke-V3Docs.ps1 -Mode Render` and `-Mode Check` for readable profile views; JSON is authoritative. Preview semantic Markdown edits with `-Mode Import`, then apply only against a matching source hash. Run `Validate`, `Generate`, `Check`, and `Test` for both `Invoke-V3.ps1` and `Invoke-IFX.ps1` as documented in `DEPLOYMENT.md`. Verify a compliant and deliberately violating fixture for every new detector. Keep the old production gate unchanged. Report unsupported rules, required host-specific CI/Skill/Hook installation, and whether required merge checks are actually configured.
