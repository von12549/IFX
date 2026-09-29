# IFX I2-B — CI evidence design and successor bundle (starts with IFX-V4-006)

Status: `ACTIVE — B0–B2 COMPLETE 2026-09-29; B3 awaits the operator decision; implementation needs a separate authorization`

Formal Plan ID: `20260929-v4-ifx-i2b-ci-evidence-and-bundle`. Phase I2-B of the program Plan
`20260929-v4-ifx-i2-p10-gate-successor`.

## 1. Why

The inactive specimen runs `stage run --stage post --with-dependencies` on a GitHub runner. That cannot pass with
bundle 0.4.4 (program Plan F1).

- **Pinned, expiring, commit-bound locks.** The 0.4.4 Profile pins six evidence locks by path and SHA-256, and
  database authorities by hash. The locks are produced locally under the git-ignored `artifacts/guards/…`, bound
  to one commit (`44536a6a`), and expire after 1 h (type, graph, generated) or 24 h (solution, assembly,
  frontend, database).
- **The producers wrap V3 (found 2026-09-29).**
  - Four of the seven producers run the V3 gate command `docs/guards/V3_ifx/commands/Invoke-IFXGuardrails.ps1`:
    - solution: `-Mode Quality -QualityTarget Solution`, which builds, runs the tests and audits NuGet;
    - assembly and frontend: `-Mode Quality`;
    - database: `-Mode Specialized`.
  - The type producer reads V3_ifx policies.
  - The cutover proposal nevertheless maps `v3-quality-solution/assembly/frontend` and
    `v3-specialized-database` to V4 modules that only re-attest those V3-produced locks. Removing those V3
    contexts would remove the evidence producer.
- **I2-A found three Post couplings in the bundle.**
  - `ifx-c1-type-provenance` reads V3_ifx authorities.
  - `ifx-c1-evaluated-reference` reads `docs/guards/candidates` policies, which are not in the 2B adoption package.
  - The G03/G05 modules read the V3-generated `layerguard-governance-input.json`.
- **IFX-V4-006.** A C6c Linux copy-back takes about 90 minutes. Every bundle change needs a full C6c run, so this
  comes first.

## 2. Steps

| Step | Action | Effect |
| --- | --- | --- |
| B0 | Commit this Plan pair after `plan validate` | Local commit |
| B1 | **IFX-V4-006 fix.** The next C6c harness archives the native Linux results in one tar inside the container and copies the archive plus the small reports back: Linux summary, positive, matrix summary, case manifest, failure records. The parallel runner reads the same report paths, and the archive keeps the full evidence. Negative controls: the archive listing equals the native listing; the copied reports are byte-identical; a truncated archive is rejected. A container benchmark with a synthetic 65k-file tree compares per-file copy with the archive | Local harness commit; evidence |
| B2 | **CI evidence design study (read-only, plus local experiments that write only runtime evidence).** For each of the seven producers and their consumer modules, record inputs, tools, runtime, V3 dependence, determinism and freshness semantics. Measure the producers on a clean checkout. Write the design note `v4-adoption/plans/12-ci-evidence-design.md` with the options below and a recommendation | Local doc commit; evidence |
| B3 | **Decision point (operator).** Choose the option. The chosen implementation is added to this Plan as an amendment: bundle 0.5.0, producers, harness, C6c, human review, composition, parity, successor specimen and proposal. It is executed only after a separate authorization | **Operator decision** |

## 3. Options to be worked out in B2

- **D-A — CI runs the existing producers from the trusted base.**
  - The workflow runs the seven producers from the trusted base on the PR head and publishes the locks as job
    artifacts.
  - The 0.5.0 Profile binds the producer contracts: producer ID and source hashes, `targetCommit == HEAD`, and a
    freshness window. It no longer binds lock hashes.
  - V4 still depends on the V3 quality and database gates for evidence during coexistence. Porting them becomes an
    I3 prerequisite.
  - Smallest change that makes V4 Post real in CI.
- **D-B — V4-native producers.**
  - Solution build and test, NuGet audit, assembly, frontend, database and type evidence move into the curated
    `docs/guards/v4-adoption` package, independent of V3_ifx.
  - The largest change. It removes the circular ownership and unblocks I3.
- **D-C — narrow V4 ownership during coexistence.**
  - The V4 aggregate owns Pre and the lock-free Post families (G03, G04, G05, Plan04, history).
  - The lock-based families (C1 type, graph and generated evidence; C4 database; C5 solution, assembly and
    frontend) stay owned by their V3 contexts. Proposal ownership is rewritten; the Profile or Stage
    configuration excludes those modules in CI.
  - The fastest route to a green V4 aggregate, but P10.GATE would cover less than the P10.3 design claimed.

Every option also removes the three I2-A couplings:

- the V3_ifx rule content is packaged into `ifx-c1-type-provenance`;
- `ifx-c1-evaluated-reference` embeds its source policies instead of reading `docs/guards/candidates`;
- a non-V3 source is defined for the G03 projection.

IFX-V4-005 (flaky drain test) would fail CI producer runs intermittently under D-A and D-B, so its fix is
recommended alongside them. It is an IFX product change under its own Plan.

## 4. Acceptance for B0–B3

- B1: the archive copy-back is byte-faithful (listing and report hashes), and the benchmark shows the speed-up;
  the harness controls pass.
- B2: the design note covers all seven producers and all 13 context-ownership rows, states the V3 dependence
  honestly, and recommends one option with its cost.
- No bundle, Profile, module, remote, workflow or ruleset change before the B3 decision and its authorization.

## 5. Out of scope

1A and the V3 allowlist change, publishing, workflow installation, the ruleset, V3 retirement and Guard product
changes.

## 6. Planned paths (B0–B2)

- `docs/guards/plans/20260929-v4-ifx-i2b-ci-evidence-and-bundle.md` and `.plan.json`
- `docs/guards/candidates/ifx-i2b`
- `docs/guards/v4-adoption/plans/12-ci-evidence-design.md`
- `artifacts/guards/p10-ifx-i2b`
- `docs/guards/TODO.md`

## 7. Outcome of B0–B2 (2026-09-29)

Evidence: `D:\IFX-Root\v4-todo-008-evidence\I2B-ci-evidence` (`commands.jsonl`, `logs/`, `SHA256SUMS`).

- **Command sequence numbers:** the benchmark (`003-b1-benchmark`) ran concurrently with runs 003–006, so two
  runs carry sequence 003. Their log files are distinct.
- **Tracked records:** `artifacts/guards/p10-ifx-i2b/`.

| Step | Result | Record |
| --- | --- | --- |
| B0 | Plan pair committed `52d8cef4` after `plan validate` | — |
| B1 | `candidates/ifx-i2b/IFXI2B.NativeArchive.psm1` (`d20b774c`, tar pin `647c4bcb`). Controls 26/26 on the Linux image and Windows tar (run 002). Benchmark on a replica of the I1 Linux results: 69,945 files, 817 MB, 9p out mount. **Per-file copy 5,696.5 s; archive copy-back 27.5 s (207×).** The listing equals the source, and the Windows deep re-check passes | `b1-copyback/controls-summary.json`, `benchmark.json` |
| B2 | Producer timing on a fresh clone passes in attempt 2: solution 960.7 s, database 935.9 s, generated 918.3 s, frontend 48.5 s, graph 23.9 s, assembly 2.6 s, type 1.3 s. Post-binding inventory; V3 CI job timings; design note `v4-adoption/plans/12-ci-evidence-design.md` | `b2-producers/producer-timing.json`, `b2-design/post-bindings.json`, `b2-design/v3-ci-timing.json` |

Attempts kept:

- **B1 controls attempt 1 (run 001).** Launched from Git Bash, `tar` resolved to Git's GNU tar, which reads
  `D:\…` as a remote host. Fixed by pinning `System32\tar.exe` in `647c4bcb`.
- **B2 producer attempt 1 (run 005, `b2-producers/attempt1-flaky-drain-test/`).** It failed on IFX-V4-005.

Findings beyond the Plan (design note 12):

- **F3 / IFX-V4-007.** Twenty of the 27 Post modules pin 230 target hashes, including the whole `src/**/*.cs`
  tree. The 0.4.4 Post attests commit `44536a6a` and fails any PR that edits `src`.
- **F5.** The Host refuses network-capable modules, so restore and audits must be workflow steps.
  `architecture-conformance` and `ifx-c1-type-provenance` need the type run's manifest staged into EvidenceRoot.
- **Couplings.** Three V3 couplings beyond I2-A:
  - the generated producer's V3 scanner source;
  - `workspaceEvidence` including `V3_ifx/…/specialized`;
  - LayerGuard baselines.

Recommendation for B3: **D-B in two steps.**

1. 0.5.0-a: the PR-gate rework — lock binding by producer contract, the pin split and the couplings.
2. 0.5.0-b: relocate the V3-wrapping producers with a V3/V4 parity run.

No bundle, Profile, module, remote, workflow or ruleset changed.