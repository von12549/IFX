# V3 stage coverage

This table describes only detectors configured in the V3 stage profile. External gates require separate evidence; advisory rules do not block.

| Rule | Enforcement | Detector | Coverage | Authority |
| --- | --- | --- | --- | --- |
| [ARCH.BINARY.DOMAIN.CONTRACTS](rules/ARCH.BINARY.DOMAIN.CONTRACTS.md) | blocking | forbidden-type-dependency | partial | profiles/ifx/rules/L2.2.json (parallel compiled-type evidence) |
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
