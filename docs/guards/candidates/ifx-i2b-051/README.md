# IFX I2-B amendment A2 — bundle 0.5.1, the producer relocation (lab tree)

Plan `20260929-v4-ifx-i2b-ci-evidence-and-bundle`, §10. This tree holds the A2 lab material; the relocated
producers themselves live in `docs/guards/v4-adoption/producers/` (ruling R6).

| Step | File | Purpose |
| --- | --- | --- |
| A2-1 | `relocation-spec.json` | Every file to relocate (origin → destination), the files deliberately not relocated, the evidence-output prefixes and the literal classifications |
| A2-1 | `New-IFX051RelocationInventory.ps1` | Hashes every origin (raw, LF-normalized, Git blob) and scans each PowerShell origin for file references. A reference into `docs/guards` must be relocated, declared or classified; otherwise the inventory fails. `-Check` re-derives and compares |
| A2-1 | `relocation-inventory.json` | The committed inventory |
