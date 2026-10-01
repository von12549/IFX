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
| A2-4 | `Test-IFX051ProducerParity.ps1` | V3/V4 producer parity on one clean clone (record `a2-relocation/a2-4-parity.json`) |
| A2-5 | the 0.5.0-a harness, copied and substituted | `candidates/ifx-i2b-050a` copied byte for byte (README excepted) at the same depth, then: tree path, evidence root `artifacts/guards/p10-ifx-i2b/a2-051`, version 0.5.1, chain steps A2-7/A2-8 |
| A2-5 | `modules/` (five lock consumers), `change-spec.json`, `Invoke-IFX050EvidenceProducers.ps1`, `New-IFX050DraftBundle.ps1` | The relocated producers' ids, scripts, authority hashes and run prefixes; database source inventory v3; staging passes `-TargetRoot`; Profile `workspaceEvidence` names `producers/database` |
| A2-5 | `Compare-IFX051SuiteOutcomes.ps1` | The five changed suites on relocated-producer evidence against the A1-3 records (record `a2-relocation/a2-5-suites/index.json`) |
| A2-6 | `matrix-contract-050.json`, `fixture-spec-050.json` | Regenerated from the 0.5.1 inventory |
| A2-9 | `Export-IFX051C6dReviewPacket.ps1` | C6d review packet of 0.5.1 against the accepted 0.5.0 packet: only the five moved consumers and the Profile may change; producer changes listed; relocation evidence bound |
| A2-10 | `Invoke-IFX050C6eComposition.ps1`, `Invoke-IFX050P102Parity.ps1`, `Compare-IFX050MatrixParity.ps1`, `Compare-IFX051HostOutcomes.ps1`, `Test-IFX050CutoverRollback.ps1`, `a210-identity.json` | C6e composition of 1.1.6 + 0.5.1, parity against 0.5.0, and the P10.3 successor rehearsal with the v4-native ownership rule |
