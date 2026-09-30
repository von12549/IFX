# C6d review packet: ifx_profile 0.5.1 on V4 Guards 1.1.6

Status: `ready-for-designated-human-review` - review decision pending (A2-9).

- Target commit `351b504bd6549a8e9cede9ab34571986f6188c49`; bundle manifest `b7a6751612f2279809b07988916112b499c52e7b1b36ae175c68924bd979e5e7`; base archive `92f1ec54db83de24c9d2096c8da5831b0a50bba0d53b9a4c719ad741f1b392c8`.
- C6c decision `309af8b25cb6630718f12f8bba0ab0fd754ef06884d06d11b58c6de4d1c96e7d`: Windows product certification pass (independent matrix 191/191, controls 180 capability + 42 staged-evidence); Linux portability pass (191/191, semantic projection equal, non-blocking).
- Predecessor: the accepted 0.5.0 packet (`9d1e95d0…`, bundle `086a3911…`).

## What to decide

Accept or reject this exact packet. 0.5.1 changes one thing: the four V3-wrapping producers (solution, assembly, frontend, database) and the type producer now run from `docs/guards/v4-adoption/producers/`, and no consumed producer reads anything under `docs/guards/V3` or `V3_ifx`. What every module claims ("pass means") is the accepted 0.5.0 text, unchanged. Acceptance permits writing the production review record and continuing with A2-10 locally; it does not authorize a push, a workflow, a ruleset or publishing.

## What changed against 0.5.0

- 19 package files changed, none added or removed; module ceilings identical.
- Profile: the version, the `policySha256` of the five moved consumers, and one `workspaceEvidence` root:
  `docs/guards/V3_ifx/stages/post/gates/specialized` -> `docs/guards/v4-adoption/producers/database`.

| Module | Version | Producer (0.5.0 -> 0.5.1) | Script |
| --- | --- | --- | --- |
| `ifx-solution-evidence` | 0.2.0 -> 0.2.1 | `ifx-c5b-controlled-v1` -> `ifx-v4a-solution-v1` | `docs/guards/v4-adoption/producers/solution/Invoke-IFXSolutionEvidenceProducer.ps1` |
| `ifx-assembly-evidence` | 0.2.0 -> 0.2.1 | `ifx-c5c-controlled-v1` -> `ifx-v4a-assembly-v1` | `docs/guards/v4-adoption/producers/assembly/Invoke-IFXAssemblyEvidenceProducer.ps1` |
| `ifx-frontend-evidence` | 0.2.0 -> 0.2.1 | `ifx-c5d-controlled-v1` -> `ifx-v4a-frontend-v1` | `docs/guards/v4-adoption/producers/frontend/Invoke-IFXFrontendEvidenceProducer.ps1` |
| `ifx-database-evidence` | 0.3.0 -> 0.3.1 | `ifx-c4b-controlled-v2` -> `ifx-v4a-database-v1` | `docs/guards/v4-adoption/producers/database/Invoke-IFXDatabaseEvidenceProducer.ps1` |
| `ifx-c1-type-provenance` | 0.2.0 -> 0.2.1 | `ifx-c1-r1b-controlled-v1` -> `ifx-v4a-type-v1` | `docs/guards/v4-adoption/producers/type/Invoke-IFXCompiledTypeEvidenceProducer.ps1` |

Authority hashes that change are those of the relocated gate scripts (the V3 quality, package-audit and assembly-guard scripts, now adapted copies); the Domain policy and the type rule copies are byte-identical, so their pins are unchanged.

## Evidence that the relocated producers behave like the V3 gates

- **Inventory (A2-1).** 18 files relocated; every file reference of every origin is classified; no unlisted read into `docs/guards`.
- **Byte-identical copy, then a separate adaptation (A2-2, A2-3).** The copy commit's Git blobs equal the origins; the adaptation commit is reviewable line by line. Static controls pass with five negative mutations (no V3/V3_ifx/lab path in any case, no escape from the package, refusal without an explicit Target root).
- **V3/V4 parity (A2-4).** On one clean clone the lab producers (V3 gates) and the relocated producers produce semantically identical evidence for all five gates: 0 differences. Negative parity 3/3: a lint error, an unsafe migration policy and a failing test fail both sides at the same check with the same message.
- **Consumer suites (A2-5).** 60 catalog cases on relocated-producer evidence all pass; the cases shared with the accepted A1-3 records agree in kind, expectation, outcome, findings and message.
- **Trial and readiness (A2-6, A2-7), C6c (A2-8).** All pass; see the bound records.

## Open limits

- The V3 originals of the relocated gate logic stay in docs/guards/V3_ifx and keep running in V3 CI during coexistence. Copy-IFX051Producers.ps1 -Check reports any later change to them as drift for review; it does not sync.
- The CI workflow with producer, staging and upload steps is still not installed; the hosted runner's prerequisites for the producers (for example SQL Server for the database matrix) are proved only when the specimen is installed and negative-tested.
- Five G03 module policies still name V3_ifx specialized scripts as provenance metadata (sourceScripts); their adapters never read them. Outside A2.
- The graph producer stays in the lab tree (candidates/ifx-gate-coverage-c1r2b); it reads nothing under V3.
- Linux remains a non-blocking portability assessment; the synthetic review fixture is a test input, not acceptance.
- V3 retirement, the ruleset, publishing and P10.GATE remain separate decisions.

## Files

`review-packet.json` binds this file, `predecessor-comparison.json` (every changed file, producer and Profile change), `file-inventory.json`, `module-ceilings.json` and the relocation evidence by SHA-256.
