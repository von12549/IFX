# ARCH.SEMANTIC: Semantic symbol ownership review

Generated view of `rules/ARCH.SEMANTIC.json`. Edit the JSON block for policy changes, then run Import. Keep explanations in `notes/`.

<!-- guard-config-source: rules/ARCH.SEMANTIC.json sha256: 436a9c16b47b9a640bdf1caf3bb1bae24494b4e7c5079b85897b4ed169c224b5 -->

| Field | Value |
| --- | --- |
| ID | ARCH.SEMANTIC |
| Kind | none |
| Enforcement | advisory |
| Detector coverage | none |
| Authority | policy/layerguard.json:ruleRefs |
| Applies to | src/**/*.cs |

```json
{
  "formatVersion": 1,
  "id": "ARCH.SEMANTIC",
  "title": "Semantic symbol ownership review",
  "kind": "none",
  "appliesTo": ["src/**/*.cs"],
  "enforcement": "advisory",
  "coverage": "none",
  "authority": "policy/layerguard.json:ruleRefs"
}
```
