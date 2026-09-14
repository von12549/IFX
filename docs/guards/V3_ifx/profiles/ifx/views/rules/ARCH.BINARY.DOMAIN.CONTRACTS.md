# ARCH.BINARY.DOMAIN.CONTRACTS: CRM Domain compiled entity types do not depend on CRM public contract types

Generated view of `rules/ARCH.BINARY.DOMAIN.CONTRACTS.json`. Edit the JSON block for policy changes, then run Import. Keep explanations in `notes/`.

<!-- guard-config-source: rules/ARCH.BINARY.DOMAIN.CONTRACTS.json sha256: b54bc598b45645d579b7c9badc2a4bbf8a7640b26c2e973e36c1ba65a2e1f565 -->

| Field | Value |
| --- | --- |
| ID | ARCH.BINARY.DOMAIN.CONTRACTS |
| Kind | forbidden-type-dependency |
| Enforcement | blocking |
| Detector coverage | partial |
| Authority | profiles/ifx/rules/L2.2.json (parallel compiled-type evidence) |
| Applies to | src/Modules/CRM/IFX.Modules.CRM.Domain/** |
| Source assembly/namespace | IFX.Modules.CRM.Domain:IFX.Modules.CRM.Domain.Entities |
| Forbidden assembly/namespace | IFX.Modules.CRM.Contracts:IFX.Modules.CRM.Contracts.V1 |
| Minimum matches | 1 |

```json
{
  "formatVersion": 1,
  "id": "ARCH.BINARY.DOMAIN.CONTRACTS",
  "title": "CRM Domain compiled entity types do not depend on CRM public contract types",
  "kind": "forbidden-type-dependency",
  "enforcement": "blocking",
  "coverage": "partial",
  "authority": "profiles/ifx/rules/L2.2.json (parallel compiled-type evidence)",
  "appliesTo": ["src/Modules/CRM/IFX.Modules.CRM.Domain/**"],
  "sourceAssembly": "IFX.Modules.CRM.Domain",
  "sourceNamespace": "IFX.Modules.CRM.Domain.Entities",
  "forbiddenAssembly": "IFX.Modules.CRM.Contracts",
  "forbiddenNamespace": "IFX.Modules.CRM.Contracts.V1",
  "minimumMatches": 1
}
```
