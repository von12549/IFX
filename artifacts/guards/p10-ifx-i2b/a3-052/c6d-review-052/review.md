# C6d review packet: ifx_profile 0.5.2 on V4 Guards 1.1.6

Status: `ready-for-designated-human-review` - review decision pending (A3-9).

- Target commit `3600988cc9e91f0a523ec60f5f4378dd4c83c541`; bundle manifest `a2f619a31c2751949058812d73fdf6a6b6142832c85e772d23a714f40304e372`; base archive `92f1ec54db83de24c9d2096c8da5831b0a50bba0d53b9a4c719ad741f1b392c8`.
- C6c decision `5b5edf13fe7c3bc2ff97a5f62a2f08d68e14eb54c6bf91ea2a2b41262c99da90`: Windows product certification pass (independent matrix 191/191, controls 180 capability + 42 staged-evidence); Linux portability pass (191/191, semantic projection equal, non-blocking).
- Predecessor: the accepted 0.5.1 packet (`f65fa234…`, bundle `b7a67516…`).

## What to decide

Accept or reject this exact packet. 0.5.2 changes one thing (finding F-C1 of I2-C): the graph lock consumer pins the graph producer relocated to `docs/guards/v4-adoption/producers/graph/`, and the Profile lineage names the staging script under `docs/guards/v4-adoption/ci/`, so no producer or staging path of the bundle lies under `docs/guards/candidates`. What every module claims ("pass means") is the accepted 0.5.1 text, unchanged. Acceptance permits writing the production review record and continuing with A3-10 locally; it does not authorize a push, a workflow, a ruleset or publishing.

## What changed against 0.5.1

- 6 package files changed, none added or removed; module ceilings identical; one version change: `ifx-c1-evaluated-reference` 0.2.0 -> 0.2.1.
- Producer: `ifx-c1-r2b-controlled-v1` -> `ifx-v4a-graph-v1`; script `docs/guards/candidates/ifx-gate-coverage-c1r2b/Invoke-IFXEvaluatedGraphProducer.ps1` -> `docs/guards/v4-adoption/producers/graph/Invoke-IFXEvaluatedGraphProducer.ps1`; script and policy hashes accordingly.
- Adapter: four lines (the header comment naming the staging script, the lock path prefix `p10-ifx-c1-r2b/evaluation-runs` -> `v4a-producers/graph-runs`, the producer id in the lock check). No check or claim changes.
- Profile: the version and the module's `policySha256`. Lineage: `stagingScript` -> `docs/guards/v4-adoption/ci/Invoke-IFXEvidenceProducers.ps1`, the graph producer entry, and the source commit, inventory and change-spec hashes.
- Authority map: the module's version and hashes, the source commit and change-spec hash, and 25 provenance `sourcePath` values of the lab tree (`ifx-i2b-051` -> `ifx-i2b-052`).

## Evidence that the relocated closure behaves like the lab one

- **Closure inventory (A3-1).** 46 references over 18 roots; nothing unlisted; every path outside `v4-adoption` is a listed relocate origin and maps under `v4-adoption` after relocation.
- **Byte-identical copy, then a separate adaptation (A3-2, A3-3).** The copy commit's Git blobs equal the origins; the adaptation is reviewable line by line. Closure controls pass with nine negative mutations (lab and V3 paths in any case, a staging script naming a missing or lab producer, a policy source back in the lab or with a drifted hash, an escape from the package, a parsed source policy, a parse error).
- **Parity (A3-4).** On one clean clone the lab and relocated graph producers give semantically equal locks (155 edges, 58 projects; 0 differences). Negative parity 4/4. The extracted aggregate equals the lab branch for 16/16 input combinations.
- **Consumer suite (A3-5).** 12 catalog cases pass on evidence from the relocated staging script and producers; the cases shared with the accepted A1-3 record agree in kind, expectation, outcome, findings and message.
- **Trial, readiness (A3-6, A3-7) and C6c (A3-8).** All pass; see the bound records.

## Open limits

- The lab originals of the relocated graph producer, its policy, the two source policies and the staging script stay in docs/guards/candidates on the development branch; Copy-IFX052Closure.ps1 -Check reports any later change to them as drift for review; it does not sync.
- The two source policies under producers/graph/policies are byte copies kept as hashed data: their provenance fields still name V3 paths, which the producer never reads (A3-3 control).
- The specimen and proposal still bind 0.5.1 and the lab-tree staging and aggregate paths; A3-10 rebinds them to 0.5.2 and adds the closure rule with its negative controls.
- The hosted runner's prerequisites for the producers (for example the pinned .NET SDK 10.0.303 of the graph producer and SQL Server for the database matrix) are proved only when the specimen is installed and negative-tested (I2-E).
- Linux remains a non-blocking portability assessment; the synthetic review fixture is a test input, not acceptance.
- Publishing to main (I2-D), the ruleset, P10.GATE and V3 retirement remain separate decisions.

## Files

`review-packet.json` binds this file, `predecessor-comparison.json` (every changed file, field and adapter line), `file-inventory.json`, `module-ceilings.json` and the closure evidence by SHA-256.
