# V3 stage coverage

<!-- GENERATED READ-ONLY. Edit authority sources, then run Docs Render. -->

Composite SHA-256: `a6791da22983d1cb2a58c279cf6f2946f26dd62f1980966bba4bf1f87e04b795`

Sources:

- `docs/guards/V3_ifx/stages/post/rules/ARCH.BINARY.DOMAIN.CONTRACTS.json` — authority
- `docs/guards/V3_ifx/stages/post/rules/ARCH.SEMANTIC.json` — authority
- `docs/guards/V3_ifx/stages/post/rules/L1.2.json` — authority
- `docs/guards/V3_ifx/stages/post/rules/L2.2.json` — authority
- `docs/guards/V3_ifx/stages/post/rules/L2.3.json` — authority
- `docs/guards/V3_ifx/stages/post/rules/L2.4.json` — authority
- `docs/guards/V3_ifx/stages/post/rules/L2.9.json` — authority
- `docs/guards/V3_ifx/stages/post/rules/L3.1.json` — authority
- `docs/guards/V3_ifx/stages/post/rules/L3.4.json` — authority
- `docs/guards/V3_ifx/stages/post/rules/L3.5.json` — authority
- `docs/guards/V3_ifx/stages/post/rules/L3.6.json` — authority

This table describes only detectors configured in the V3 stage profile. External gates require separate evidence; advisory rules do not block.

| Rule | Enforcement | Detector | Coverage | Authority |
| --- | --- | --- | --- | --- |
| [ARCH.BINARY.DOMAIN.CONTRACTS](rules/ARCH.BINARY.DOMAIN.CONTRACTS.md) | blocking | forbidden-type-dependency | partial | stages/post/rules/L2.2.json (parallel compiled-type evidence) |
| [ARCH.SEMANTIC](rules/ARCH.SEMANTIC.md) | advisory | none | none | policy/layerguard.json:ruleRefs |
| [L1.2](rules/L1.2.md) | advisory | none | none | policy/layerguard.json:ruleRefs[L1.2] (blocking in Invoke-IFX) |
| [L2.2](rules/L2.2.md) | blocking | forbidden-project-reference | partial | policy/layerguard.json:allowedReferences.Domain |
| [L2.3](rules/L2.3.md) | advisory | none | none | policy/layerguard.json:ruleRefs[L2.3] (blocking in Invoke-IFX) |
| [L2.4](rules/L2.4.md) | advisory | none | none | policy/layerguard.json:ruleRefs[L2.4] (blocking in Invoke-IFX) |
| [L2.9](rules/L2.9.md) | advisory | none | none | policy/layerguard.json:ruleRefs[L2.9] (blocking in Invoke-IFX) |
| [L3.1](rules/L3.1.md) | advisory | none | none | policy/layerguard.json:ruleRefs[L3.1] (blocking in Invoke-IFX) |
| [L3.4](rules/L3.4.md) | advisory | none | none | policy/layerguard.json:ruleRefs[L3.4] (blocking in Invoke-IFX) |
| [L3.5](rules/L3.5.md) | advisory | none | none | policy/layerguard.json:ruleRefs[L3.5] (blocking in Invoke-IFX) |
| [L3.6](rules/L3.6.md) | advisory | none | none | policy/layerguard.json:ruleRefs[L3.6] (blocking in Invoke-IFX) |
