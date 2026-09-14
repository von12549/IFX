# ARCH.SAMPLE: Sample project must not reference Legacy

Generated view of `rules/ARCH.SAMPLE.json`. Edit the JSON block for policy changes, then run Import. Keep explanations in `notes/`.

<!-- guard-config-source: rules/ARCH.SAMPLE.json sha256: 22d66cf8663f53975f7cb862bfb4346eefd99a0296ffa29e9351af08c83239b1 -->

| Field | Value |
| --- | --- |
| ID | ARCH.SAMPLE |
| Kind | forbidden-project-reference |
| Enforcement | blocking |
| Detector coverage | partial |
| Authority | Synthetic sample policy; replace in a real profile |
| Applies to | src/App/** |
| Source pattern | src/**/*.csproj |
| Forbidden target | **/Legacy/*.csproj |
| Negative source | src/App/App.csproj |
| Negative reference | ../Legacy/Legacy.csproj |

```json
{
  "formatVersion": 1,
  "id": "ARCH.SAMPLE",
  "title": "Sample project must not reference Legacy",
  "kind": "forbidden-project-reference",
  "enforcement": "blocking",
  "coverage": "partial",
  "authority": "Synthetic sample policy; replace in a real profile",
  "appliesTo": ["src/App/**"],
  "sourcePattern": "src/**/*.csproj",
  "forbiddenTargetPattern": "**/Legacy/*.csproj",
  "negativeFixture": {
    "sourceProject": "src/App/App.csproj",
    "referenceInclude": "../Legacy/Legacy.csproj"
  }
}
```
