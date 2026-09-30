# IFX I2-B amendment A2 — bundle 0.5.1, the producer relocation (lab tree)

Plan `20260929-v4-ifx-i2b-ci-evidence-and-bundle`, §10. This tree holds the A2 lab material; the relocated
producers themselves live in `docs/guards/v4-adoption/producers/` (ruling R6).

| Step | File | Purpose |
| --- | --- | --- |
| A2-1 | `relocation-spec.json` | Every file to relocate (origin → destination), the files deliberately not relocated, the evidence-output prefixes and the literal classifications |
| A2-1 | `New-IFX051RelocationInventory.ps1` | Hashes every origin (raw, LF-normalized, Git blob) and scans each PowerShell origin for file references. A reference into `docs/guards` must be relocated, declared or classified; otherwise the inventory fails. `-Check` re-derives and compares |
| A2-1 | `relocation-inventory.json` | The committed inventory |
| A2-2 | `Copy-IFX051Producers.ps1` | Copies the inventoried origins byte for byte into `v4-adoption/producers/` and writes `producers/origins.json`; `-Check` is the origin drift control (R7) |
| A2-3 | `Test-IFX051ProducerControls.ps1` | Static controls of the relocated producers (no V3, V3_ifx or lab path in any case; no escape from the package; parse; refusal without a Target root; inventory re-derived; no origin drift) with five negative mutations |
| A2-4 | `Test-IFX051ProducerParity.ps1` | V3/V4 producer parity on one clean clone: semantic evidence comparison per gate, identity changes listed apart, and a committed negative mutation per gate that must fail the same way on both sides (R11) |
