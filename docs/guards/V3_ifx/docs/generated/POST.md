# IFX Post stage

<!-- GENERATED READ-ONLY. Edit authority sources, then run Docs Render. -->

Composite SHA-256: `e0713218a5e6f15258dd9970cdc857bfcf8616096479c085e4af99510453ea28`

Sources:

- `docs/guards/V3_ifx/policy/layerguard.json` — profile-policy
- `docs/guards/V3_ifx/profiles/ifx/rules/ARCH.BINARY.DOMAIN.CONTRACTS.json` — profile-policy
- `docs/guards/V3_ifx/profiles/ifx/rules/ARCH.SEMANTIC.json` — profile-policy
- `docs/guards/V3_ifx/profiles/ifx/rules/L1.2.json` — profile-policy
- `docs/guards/V3_ifx/profiles/ifx/rules/L2.2.json` — profile-policy
- `docs/guards/V3_ifx/profiles/ifx/rules/L2.3.json` — profile-policy
- `docs/guards/V3_ifx/profiles/ifx/rules/L2.4.json` — profile-policy
- `docs/guards/V3_ifx/profiles/ifx/rules/L2.9.json` — profile-policy
- `docs/guards/V3_ifx/profiles/ifx/rules/L3.1.json` — profile-policy
- `docs/guards/V3_ifx/profiles/ifx/rules/L3.4.json` — profile-policy
- `docs/guards/V3_ifx/profiles/ifx/rules/L3.5.json` — profile-policy
- `docs/guards/V3_ifx/profiles/ifx/rules/L3.6.json` — profile-policy
- `docs/guards/V3_ifx/shared/commands.json` — command-contract
- `docs/guards/V3_ifx/stages/post/stage.json` — trust-contract

Post commands: ifx-guardrails, v3-runner, v3-docs, ifx-architecture, ifx-specialized, ifx-quality, ifx-historical-integrity, ifx-policy-sync, ifx-history-manifest.

## Gates

| Gate | Trust type | Executes head | Consumes head artifacts | Guarantee |
| --- | --- | --- | --- | --- |
| v3-architecture | mixed | False | False | Evaluator, policy binding and policy all come from base; the verdict covers project references, rings, ownership, declarations, packages, imports and the G03/G04/G05 bindings as declared in csproj XML and C# source text, with the composite policy hash bound to the reviewed baseline. Blind to references and properties that only exist after MSBuild evaluation (imports, Conditions, SDK defaults, generated items), which v3-quality-assembly cross-covers by checking the compiled assemblies of the same commit; blind to runtime behaviour, which the quality and specialized gates cover. |
| v3-specialized-g03 | judging | False | False | Base owns the verdict; detectors are static. |
| v3-specialized-g04 | judging | False | False | Base owns the verdict; detectors are static. |
| v3-specialized-g05 | judging | False | False | Base owns the verdict; detectors are static. |
| v3-specialized-plan04 | judging | False | False | Base owns the verdict; detectors are static. |
| v3-specialized-database | executing | True | True | Base fixes commands, arguments, exit-code judgement and required evidence only. |
| v3-quality-solution | executing | True | False | Base fixes commands and thresholds only. |
| v3-quality-assembly | mixed | False | True | Evaluator trusted; assembly provenance is head-controlled. |
| v3-quality-frontend | executing | True | False | Base fixes commands and thresholds only. |
| v3-historical-integrity | judging | False | False | Base owns the verdict. |

## Stage profile rules

| Rule | Enforcement | Detector | Coverage |
| --- | --- | --- | --- |
| ARCH.BINARY.DOMAIN.CONTRACTS | blocking | forbidden-type-dependency | partial |
| ARCH.SEMANTIC | advisory | none | none |
| L1.2 | advisory | none | none |
| L2.2 | blocking | forbidden-project-reference | partial |
| L2.3 | advisory | none | none |
| L2.4 | advisory | none | none |
| L2.9 | advisory | none | none |
| L3.1 | advisory | none | none |
| L3.4 | advisory | none | none |
| L3.5 | advisory | none | none |
| L3.6 | advisory | none | none |
