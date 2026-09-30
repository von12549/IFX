# IFX I2-B — CI evidence design and successor bundle (starts with IFX-V4-006)

Status: `ACTIVE — B0–B3 COMPLETE 2026-09-29 (B3: A accepted, D-B two-step chosen); B1–B2 pushed; amendment A1 (0.5.0-a) ACTIVE — rulings R1–R5 taken; A1-2 accepted; A1-3 to A1-6 complete (A1-6 C6c pass); IFX-V4-005 fixed; A1-7 accepted 2026-09-30 ("接受"); amendment A1 (0.5.0-a) COMPLETE 2026-09-30, pushed `ffe03be5..13502169`; amendment A2 (0.5.0-b, bundle 0.5.1) ACTIVE — rulings R6–R11 taken as recommended; A2-0 to A2-7 authorized (local)`

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
## 8. B3 decision (2026-09-29)

Operator statement: "A 接受，B 是 。授权推送".

- **(a) Accepted: the pin split rule of design note 12, finding F3.**
  - Pins stay only for governance authorities: ADRs, phase evidence, closeout records and release templates.
  - Product, test and deployment sources, and whole trees, are evaluated on the current content.
  - This changes what the certified 0.4.4 modules claim, so the successor modules need a new human review (C6d).
- **(b) Chosen target: D-B in two steps.**
  1. 0.5.0-a: the PR-gate rework — lock binding by producer contract, the pin split and the couplings.
  2. 0.5.0-b: relocate the V3-wrapping producers into `v4-adoption/producers/`, with a V3/V4 parity run.
- **Push:** B0–B2 were pushed as a fast-forward, `13cf8965..b5cee75f`.

Next: an amendment to this Plan with the concrete 0.5.0-a module changes, harness successors (using the B1
archive copy-back) and the C6 chain re-run. It is executed only after its own authorization. IFX-V4-005 needs
its own IFX product Plan before any option builds and tests the solution in CI.
## 9. Amendment A1 — bundle 0.5.0-a, the PR-gate rework

A1 implements the first D-B step chosen at B3. It produces `ifx_profile` 0.5.0: every Post module checks the
current commit and still blocks real violations. Relocating the V3-wrapping producers is the second step,
0.5.0-b, under its own amendment.

### 9.1 Scope, from the recorded classification

Record: `artifacts/guards/p10-ifx-i2b/a1-design/pin-classification.json` (run 008). It classifies every repository
path named by a 0.4.4 Post module policy, by ordered path rules:

| Class | Distinct paths | A1 action |
| --- | --- | --- |
| governance — `docs/architecture/review/**`, `.claude/Plans/**`, history-integrity entries | 119 | keep the Profile/policy pin; a change needs a bundle update |
| live-source — `src`, `tests`, `deployment`, compose files, `IFX.sln`, `Directory.*`, `.github/CODEOWNERS` | 113 | drop the pin; the module's predicates run on current content |
| live-registry — G03 catalog, two G03 snapshots, two Plan04 registries | 5 | drop the pin; reconcile with current source (ruling R1) |
| v3-coupling — V3-generated `layerguard-governance-input.json` (G03 core, G05 protocol, G05 governance) | 1 | replace (ruling R2) |
| lab-coupling — `docs/guards/candidates` policies read by `ifx-c1-evaluated-reference` and `ifx-plan04-abstractions` | 3 | embed into the module |
| provenance-only — G03 `sourceScripts` (never read by the adapter) | 8 | unchanged |

Four couplings are hard-coded in adapters or the Profile rather than named by policy, and are also removed:

- `ifx-c1-type-provenance` reads two V3_ifx files;
- the generated producer pins the V3 scanner source;
- `workspaceEvidence.relativeRoots` includes `V3_ifx/…/specialized`;
- the frontend producer sets a fixed Windows `PATH`.

The 0.4.4 checks already evaluate content. `g04-runtime` and the G05 modules use regex predicates;
`g05-inventory` counts surfaces in every `src/**/*.cs`. The hash pins sit in front of those checks as freshness
locks. Removing a live pin therefore keeps the check and removes only the snapshot condition. Any check found to
depend on the hash alone is listed in the change specification (A1-2) and rewritten.

Module dispositions:

- **Unchanged: the 10 Pre modules, `architecture-conformance` (built into the base) and `ifx-history-integrity`
  (all pins are historical records).**
- **Lock binding (6):**
  - `ifx-solution-evidence`, `ifx-assembly-evidence`, `ifx-frontend-evidence`;
  - `ifx-database-evidence` (also pin split);
  - `ifx-c1-type-provenance` (also coupling);
  - `ifx-c1-evaluated-reference` (also coupling).
- **Pin split (19 more):**
  - G03: core, catalog semantics, source reconciliation, snapshots, docs closeout;
  - G04: manifests, runtime, closeout;
  - Plan04: extraction, tenant, projection, abstractions;
  - G05: inventory, protocol, execution/HTTP, carriers, governance, closeout;
  - `ifx-plan05-security`.

### 9.2 Lock binding by producer contract

- **Profile.** The 0.5.0 Profile no longer carries `evidenceLockPath` or `evidenceLockSha256`.
- **Where the lock lives.** Each lock consumer reads `locks/<gate>/evidence-lock.json` and its evidence files from
  EvidenceRoot. The type consumer and `architecture-conformance` also read `assembly-manifest.json` and the four
  DLLs there.
- **What the module verifies.**
  - The producer id.
  - The producer script SHA-256 values, pinned in the module policy.
  - `targetCommit` equal to HEAD.
  - The freshness window, unchanged: 24 h or 1 h.
  - The source-tree fingerprint and the hash of every listed evidence file.
  - The lineage between locks.
  - Missing evidence is `prerequisite-missing`; anything else inconsistent is `integrity-failure`.
- **Staging.** A staging script (`candidates/ifx-i2b-050a/Invoke-IFX050EvidenceProducers.ps1`) runs the seven
  producers in C6 chain order and writes that layout. It is used by the harness and, from 0.5.0-b on, by the
  workflow.
- **Cost of this choice.** Relocating the producers in 0.5.0-b changes their hashes. That step therefore issues
  0.5.1, with its own C6 chain.

### 9.3 Steps

| Step | Action | Gate |
| --- | --- | --- |
| A1-0 | Operator rulings R1–R4 (§9.4); commit this amendment and the classification record | **Operator** |
| A1-1 | IFX-V4-005 fixed under its own IFX product Plan (the drain test), before A1-6 | Separate Plan and authorization |
| A1-2 | **Change specification** `candidates/ifx-i2b-050a/change-spec.json`. For each of the 37 modules: disposition, removed and kept pins, and whether each check depends on content or only on the hash. New versions: changed modules go from 0.1.x to 0.2.0. Rewrites for hash-only checks | Local commit; operator reads the spec |
| A1-3 | Module successors under `candidates/ifx-i2b-050a/modules/<id>`, each with its suite. New suite cases per changed module: (a) a benign edit to a formerly pinned live file still passes; (b) a rule-breaking edit still blocks; (c) an edited governance file is still `integrity-failure`. Lock consumers also reject a missing lock, an expired lock, a wrong commit, a forged producer hash and a tampered evidence file | Local commits; suites pass |
| A1-4 | Harness successors under `candidates/ifx-i2b-050a/`. **Pipeline:** inventory; contract handshake (0.4.4 → 0.5.0, changed claims re-qualified, not inherited); draft bundle builder (Profile without lock or live pins); focused qualification. **C6c tests:** regenerated matrix contract and fixture spec, independent matrix, and C6c with the Linux leg using `IFXI2B.NativeArchive.psm1`. **Harness controls** add the **PR-gate cases**: synthetic PR commits on a clean clone with producers re-run at each commit — a benign `src` edit passes Post, a rule-breaking edit blocks with the expected rule, a governance edit fails closed | Local commits; controls pass |
| A1-5 | Readiness: two deterministic candidates (A/B), focused qualification, controls | Local |
| A1-6 | **Single C6c** for 0.5.0 (Windows matrix, controls, Linux on native storage with archive copy-back) | **Authorization** |
| A1-7 | C6d review packet; **human review** of the changed claims (what "pass" now means per module) | **Operator acceptance** |
| A1-8 | C6e composition and installed-Host Pre/Post on the S7-style Targets. **P10.2 parity against 0.4.4:** differences expected only where live pins were removed, and each difference listed. **P10.3 successor rehearsal:** new specimen with producer, staging and upload steps; proposal ownership saying "re-attests the V3 producer" until 0.5.0-b | Local |
| A1-9 | Local verification: V3, V3_ifx and `.github` byte-identical, `git fsck`, `plan validate`, planned paths. Receipt and evidence index | Local |
| A1-10 | Push the A1 commits | **Authorization** |

### 9.4 Operator rulings needed before A1-2

- **R1 — live registries.** The G03 contract-event catalog, the G03 API and serialization snapshots, and the
  Plan04 tenant-bypass and projection registries change with ordinary contract work.
  - *Recommended:* treat them as live. Drop the pin; the existing reconciliation and snapshot checks compare them
    with the current source.
  - *Alternative:* keep them pinned as governance. Then every new event or projection needs a bundle update.
- **R2 — the G03 projection** (`generated/layerguard-governance-input.json`, generated today by the V3 script
  `Export-G03LayerGuardGovernance.ps1`).
  - *Recommended:* the G03 core module regenerates the projection from the current catalog, using the IFX export
    logic embedded in the module, and requires the committed file to equal it. G05 protocol and governance read
    the checked file.
  - *Alternative:* keep it pinned as governance, which breaks with R1 "live".
- **R3 — source location.**
  - *Recommended:* develop the 0.5.0 modules and harness in the lab tree `docs/guards/candidates/ifx-i2b-050a`, as
    for every earlier bundle. The curated `docs/guards/v4-adoption` receives only the published bundle (I2-D, per
    decision 2B).
  - *Alternative:* develop in `v4-adoption` directly.
- **R4 — IFX-V4-005 order.**
  - *Recommended:* fix the drain test under a separate IFX product Plan before the A1-6 C6c, because the chain runs
    the solution producer and the PR-gate controls re-run it per synthetic commit.
  - *Alternative:* accept retries in the harness. Not recommended: it hides a product defect.

**Rulings (2026-09-29, operator: "R1-R4都按照推荐项决定"):**

- R1: the registries are live.
- R2: the G03 core module regenerates the projection.
- R3: the lab tree `candidates/ifx-i2b-050a`.
- R4: IFX-V4-005 is fixed first, under its own IFX product Plan.

### 9.6 Progress

- A1-0: committed `89fa7ede`.
- A1-2: change specification `candidates/ifx-i2b-050a/change-spec.json` committed `1797d554`.
  **Accepted by the operator on 2026-09-29 ("审阅完毕，同意变更").**
- A1-3 is delivered in batches, each committed after its suites pass:
  1. the shared suite runner;
  2. G04;
  3. G05 and Plan05;
  4. G03;
  5. Plan04;
  6. the lock consumers and the staging script.
- Batch results so far, all on a fresh IFX clone with the 1.1.6 Host:
  - G04: 3 modules; interim recorded runs 013–015.
  - G05 and Plan05: 7 modules; interim runs 016–022.
  - G03: 4 of 5 modules pass. `ifx-g03-docs-closeout` is blocked by finding F-A1-1.
  - The formal recorded pass of every suite runs from the final A1-3 commit.
- Two live-to-live content bindings were found and kept as content checks:
  - the G04 release manifest names the hashes of eight deployment files;
  - the G03 projection records the catalog hash (R2).

  A lone edit of a bound file now blocks (G04-MANIFEST, G03-PROJECTION or G05-FIELD-GOVERNANCE). An edit together
  with its binding passes.
- **Finding F-A1-1 — governance pins hash checkout bytes.**
  - 0.4.4 pins governance files by the SHA-256 of the lab working tree bytes.
  - Of the 99 distinct governance files 0.5.0-a keeps pinned:
    - 78 are CRLF in the Windows working tree, so a Linux checkout writes different bytes;
    - 3 have mixed line endings (the G03 closeout and the zh/en governance documents), so their pins match only the
      lab checkout and even a fresh Windows clone differs.
  - With UTF-8 text hashed after CRLF→LF normalization, all 99 match between the lab tree and a fresh clone. The
    database inventory contract already uses this rule (`utf8-lf-sha256`).
- **Ruling R5 taken 2026-09-29 ("确认R5按推荐继续"), recommended form.** Governance pins compare the UTF-8/LF-normalized SHA-256 for text files and the raw SHA-256 for
  binary files. The 0.5.0 Profile computes them from the Target commit's content, not from a working tree. This
  changes every kept pin and the pin helper of the 20 pinning modules.
- R5 is implemented:
  - every pinning adapter compares kept pins with `Get-PinSha256`;
  - the suite computes kept pins from the Target checkout;
  - `ifx-g03-docs-closeout` passes (25 cases).
- Batch 5 (Plan04) passes:
  - extraction 8, tenant 9, projection 16 and abstractions 11 cases;
  - `ifx-plan04-abstractions` packages the two V4 policies it read from `docs/guards/candidates`.
- Batch 6 (the six lock consumers) passes, all on staged evidence from `Invoke-IFX050EvidenceProducers.ps1`:

  | Module | Cases |
  | --- | --- |
  | `ifx-solution-evidence` | 10 |
  | `ifx-assembly-evidence` | 11 |
  | `ifx-frontend-evidence` | 10 |
  | `ifx-database-evidence` | 13 |
  | `ifx-c1-evaluated-reference` | 10 |
  | `ifx-c1-type-provenance` | 12 |

  - The Produce phase runs the seven producers.
  - The Stage phase copies each run to `EvidenceRoot/locks/<gate>/`, writes `locks/staging.json` with the producer
    script's R5 hash, and places the type run's manifest and DLLs at the EvidenceRoot root for
    `architecture-conformance`.
  - The consumers resolve paths under a staged run prefix into the staged directory. They require the pinned
    producer (id, script, R5 script hash; for type and graph also the hash of the policy their 0.4.4 producer
    reads), then keep every 0.4.4 lock check.
  - `ifx-c1-type-provenance` packages the two V3_ifx files it read; `ifx-c1-evaluated-reference` packages its two
    policies.
  - Every consumer rejects:
    - a missing manifest or lock;
    - a forged producer;
    - a tampered lock or evidence file;
    - another commit;
    - an expired lock;
    - a gate mismatch.
  - Lineage tampering, and a source or input changed after production, are rejected where they apply.
- **A1-3 complete (2026-09-29).**
  - Formal recorded pass from harness commit `f8a5f28b` on a fresh IFX clone at `1797d554`, evidence runs 024–049:
    - evidence produced once (run 024);
    - the six lock consumers first, then the other 19.
  - **All 25 modules pass: 516 cases, 0 failed, and 25 installed-Host Post runs pass on the 1.1.6 base.**
  - Records: `artifacts/guards/p10-ifx-i2b/a1-suites/` (`index.json` with the harness and specification hashes, one
    summary per module, the production record).
  - Next: A1-4, the harness successors.
- **A1-4 complete (2026-09-29).** Harness successors under `candidates/ifx-i2b-050a/` (README, section "Harness
  successors"); commits `83a6cb6e`, `d1062c55`, `d245c891`, `31a5ae79`, `83fa809e`, `50e77de6`, `25531643`,
  `a35a0748`, `e13ac68c`.
  - **Matrix.** `matrix-contract-050.json` and `fixture-spec-050.json` are derived from the I1 files; the verifier
    re-derives both and compares them. Reclassifying the A1-3 captures showed 15 gaps in the changed modules. Ten
    catalog cases close them: fixed-checklist zero and violation fixtures for the four checklist evidence
    modules, two evaluated-graph edges, and the I1 supplemental recipes for G04/G05 evidence, handoff and field
    governance. The runner gains staged `find`/`replace` and `relock` edits for them.
  - **Independent matrix.** The 25 successor suites run in capture mode against the composed candidate on one
    Target clone with one production (lock consumers first). The 11 unchanged suites go through the I1 wrapper.
    `Test-IFX050SupplementalFixtures.ps1` keeps the 15 unchanged supplemental fixtures.
  - **Certification controls.** The 180 capability controls and the root controls are kept. 42 staged-evidence
    controls replace the Profile lock controls: current, missing staging, forged producer, altered lock, stale,
    wrong commit, and a Target change after production, for each of the six consumers.
  - **Production transfer** (`IFX050.Production.psm1`). The C6c produces once on a Windows clone. The controls
    and the Linux leg import a snapshot of it: run directories, the DLLs the locks bind, and the producing
    checkout's tracked bytes.
  - **C6c runners.** Parallel certification, readiness (no lock gate: the candidate binds no lock), single C6c,
    the C6c entry with the R4 gate (`Status: COMPLETE` of the IFX-V4-005 Plan), and the chain with
    `-ReadinessOnly`.
  - **Harness controls** (at `e13ac68c`): 12 Windows, 4 PR-gate and 10 Linux controls pass. The PR-gate cases use
    synthetic PR commits on clean clones, with the producers re-run at each commit:
    - a benign `src` comment passes Post (27 modules, no finding);
    - a rule-breaking `src` edit (backpressure decision code) blocks with G04-BACKPRESSURE;
    - a governance edit (`open-items-v1.json`) fails closed with `integrity-failure`;
    - evidence produced for another commit is rejected.
  - **Trial** at `a35a0748` (not the A1-6 C6c):
    - the readiness chain passes: inventory, handshake (11 inherit, 1 base, 25 requalified), production,
      candidates A and B identical on all five determinism fields, focused qualification, readiness;
    - parallel certification passes: Windows matrix 191/191; controls 180 + 42; Linux 191/191, semantic
      projection equal.
    - Records: `artifacts/guards/p10-ifx-i2b/a1-harness/` (`index.json`). Evidence
      `I2B-ci-evidence/a1-4-trials` (SHA256SUMS `3c5ff13c…`).
  - Findings fixed on the way:
    - clones under the temp directory need `core.longpaths`;
    - a snapshot import must make the DLLs newer than the checkout (stale check);
    - the Linux checkout must take the producing checkout's bytes, because the long-lived worktree holds a
      mixed-EOL test file that a fresh clone writes as CRLF;
    - the harness read the 0.4.4 Profile and authority map from `D:`; they are now byte copies in `baseline-044/`;
    - the accepted 0.4.4 suites leave directory links in the Linux evidence; they are recorded in
      `native-links.json` and replaced before the archive copy-back;
    - a candidate under the repository must be copied out before composition.
  - IFX-V4-005 failed again during the PR-gate controls (solution producer, drain test): the fifth recorded
    failure. It stays a prerequisite of A1-6 (R4).
  - Known limit: the `zero-source` catalog cases delete ignored build outputs in the Target clone; the matrix runs
    the lock consumers first, so no later suite needs them.
  - Next: IFX-V4-005 under its own Plan (authorization), then A1-5 readiness on that commit and the A1-6 C6c
    (authorization).
- **IFX-V4-005 fixed (2026-09-30).** Plan `20260930-ifx-v4-005-drain-wait-race` complete: `739fc279`, pushed.
- **A1-5 complete (2026-09-30).** `Invoke-IFX050C6Chain.ps1 -ReadinessOnly` at `739fc279` passes in 711 s:
  - inventory; handshake 11 inherit, 1 base, 25 requalified;
  - one production at HEAD (357 s);
  - candidates A and B equal on the bundle manifest (`682d1e42…`), Profile, inventory, production record,
    composition receipt projection and composed package fingerprint;
  - focused qualification: 7 consumers, 58 negative cases;
  - readiness pass: matrix contract re-derived, I1 C6c records preserved; authorization
    `readiness-only-full-c6c-not-authorized`.
  - The harness under `candidates/` is unchanged since the A1-4 harness controls (`e13ac68c`).
  - Records: `artifacts/guards/p10-ifx-i2b/a1-readiness/` (`index.json`); evrun 050 in `I2B-ci-evidence`.
  - Next: the A1-6 single C6c (authorization).
- **A1-6 complete (2026-09-30, authorized).** `Invoke-IFX050C6Chain.ps1 -AuthorizeA16C6c` at `c0d927eb` passes in
  2,498 s; the single C6c took 1,809 s. The A1-5 run trees were moved to the ignored `a1-5-run/` first, because the
  chain requires absent outputs.
  - readiness steps again at HEAD: handshake 11/1/25, candidates A and B deterministic (bundle manifest
    `086a3911…`; it differs from A1-5 only because the source commit is part of the candidate), focused
    qualification pass;
  - product certification (Windows, blocking): pass. Independent matrix 191/191 core cases; controls 180
    capability + 42 staged-evidence;
  - portability assessment (Linux, non-blocking): pass, 191/191, semantic projection equal, network none, image
    `sha256:7d373379…`; archive copy-back 59,592 files;
  - decision `phase-1-complete-stop-for-human-review` (`c6c-decision.json`, sha256 `315a8251…`);
  - no IFX-V4-005 failure: the solution producer ran twice (chain production and C6c production).
  - Records at their natural paths under `artifacts/guards/p10-ifx-i2b/` (as I1 did): `c6c-attempt.json`,
    `c6c-decision.json`, `a1-chain.json`, `c6c-full/**` reports, readiness and chain inputs, `chain/*.log`.
    Evidence: evrun 051 in `I2B-ci-evidence`.
  - Next: A1-7, the C6d review packet and the human review of the changed claims (operator acceptance).
- **A1-7 packet ready (2026-09-30); human decision pending.** `Export-IFX050C6dReviewPacket.ps1` (`b797b565`, fix
  `777d4764`) wrote `artifacts/guards/p10-ifx-i2b/c6d-review-050/`: `review.md` for the reader, `review-packet.json`
  (sha256 `9d1e95d0…`), `claim-changes.json` (per module: what "pass" means, dropped and kept pins, lock checks,
  couplings, check changes, C6c cases), `predecessor-comparison.json` (0.4.4 -> 0.5.0: 25 module versions, 103
  package files changed, 6 embedded policies added, none removed; four lock consumers gain EvidenceRoot reads only),
  `file-inventory.json` (262 files) and `module-ceilings.json` (36 modules). Evidence: evrun 053 (052 hung on the
  `$input` automatic variable and was stopped; fixed in `777d4764`).
- **A1-7 accepted (2026-09-30).** The operator accepted the exact packet `9d1e95d0…` ("接受"). Records in
  `c6d-review-050/`: `c6d-decision.json` (`c6d-exact-bundle-human-review-accepted`) and
  `production-extension-review.json` (id `20260930-ifx-0-5-0-production-review`, scope `production`, 36 module
  ceilings; valid against the 1.1.6 `extension-review.schema.json`). Acceptance permits A1-8 locally; it does not
  authorize a push, a workflow, a ruleset or publishing.
- **A1-8 complete (2026-09-30, local).**
  - **A1-8a C6e** (`Invoke-IFX050C6eComposition.ps1`): production composition `releases/v4-guards-1.1.6-ifx-0.5.0`,
    package `f94d724a…`, receipt `dc0e2aaf…`, on two clean clones at `c0d927eb`. Installed Host: clean Pre 10 modules /
    22 claims; the deliberate `A18Fault.cs` blocks with `IMPORT-DIRECTION`; Post on staged evidence 27 modules / 57
    claims; the dependency run 37 modules / 79 claims; Post without staged evidence fails closed
    (`prerequisite-missing`, stopping at `architecture-conformance`). Protected roots and Git facts unchanged.
    Decision `a1-8a-decision.json` `6bbe11b7…`. Attempts 1–3 stopped on harness faults and are kept:
    1 used worktrees (the producers need a `.git` directory), 2 did not create the compose roots, 3 expected
    every lock consumer to be listed for the unstaged Post although the Host stops at the first missing
    prerequisite (all positive checks passed).
  - **A1-8b parity against 0.4.4**: the P10.2 replay (`Invoke-IFX050P102Parity.ps1`, literal successor) passes
    52/52 with zero gaps and the same 15 strengthenings, row by row equal to the accepted 0.4.4 replay.
    `Compare-IFX050MatrixParity.ps1`: the 191 C6c cases equal the 0.4.4 matrix in IDs, kinds, rules, claims and
    expected and actual outcomes; 7 cases report a different first finding because the fixtures changed, each
    listed in `p10-2-parity-050/parity-against-044.json`.
  - **A1-8c P10.3 successor**: specimen with producer, staging (from the trusted base, before Pre and Post) and
    always-run upload steps; proposal with the staged-by-workflow evidence model and the four V3-wrapping
    producers declared `re-attests-v3-producer-until-0.5.0-b`; rollback anchor `ffe03be5…` from a GET-only
    snapshot; design note 13. Rehearsal passes with 13 negative controls rejected; decision
    `fab31b2b…`.
  - Identity file `candidates/ifx-i2b-050a/a18-identity.json`. Evidence: evrun 054–061 in `I2B-ci-evidence`.
  - Next: A1-9 local verification, then A1-10 push (authorization).
- **A1-9 complete (2026-09-30).** Local verification at `2a42fe13` passes: clean worktree; V3, V3_ifx and `.github`
  byte-identical to `07f41683`, `13cf8965` and `b5cee75f`; `git fsck --full --strict` (dangling objects only);
  `plan validate` (1.1.6 Host) and V3_ifx `Validate` pass for this Plan and the IFX-V4-005 Plan; all 412 paths
  changed since `b5cee75f` are planned. Record `I2B-ci-evidence/a1-9-verification.json` (evrun 063). Receipt
  `v4-adoption/migration/ifx-i2b-a1-0-5-0-a-receipt.json`.
  - Next: A1-10, push the A1 commits (authorization); then 0.5.0-b.
- **A1-10 complete (2026-09-30).** Operator: "授权 A1-10 推送". Fast-forward push `ffe03be5..13502169` (12 commits),
  verified. **Amendment A1 is complete.** Next: amendment A2 (§10).

### 9.5 Out of scope for A1

- the producer relocation (0.5.0-b);
- the workflow installation, the ruleset, 1A, the V3 allowlist, publishing (I2-D) and V3 retirement;
- Guard product changes.

## 10. Amendment A2 — bundle 0.5.1, the producer relocation (0.5.0-b)

Status: `ACTIVE — rulings R6–R11 taken as recommended and A2-0 to A2-7 authorized for local execution (2026-09-30, "全部按推荐，并授权A2-0到A2-7本地执行"); A2-8 and A2-12 need their own authorization`

A2 is the second D-B step chosen at B3. Four of the six evidence producers consumed by 0.5.0-a still run V3 gates
through `docs/guards/V3_ifx/commands/Invoke-IFXGuardrails.ps1`. The accepted proposal therefore says that V4
"re-attests" `v3-quality-solution`, `v3-quality-assembly`, `v3-quality-frontend` and `v3-specialized-database`.
A2 moves that gate logic into `docs/guards/v4-adoption/producers/`, so that no consumed producer reads anything
under `docs/guards/V3_ifx`. The V3 originals stay unchanged while V3 is still required.

The lock consumers pin the producer script hashes and the V3 gate script hashes (`authorityHashes`) in their
policies, so the relocation changes module policies. As §9.2 recorded, A2 therefore issues bundle **0.5.1**
with its own C6 chain and C6d review. What the modules claim does not change; only the producer identity does.

### 10.1 Scope, from the current producers

| Evidence gate | Producer today | V3 logic it runs | Other V3 or host coupling |
| --- | --- | --- | --- |
| solution | `ifx-c5b-controlled-v1` | `Invoke-IFXGuardrails -Mode Quality -QualityTarget Solution` → `Invoke-IFXQuality.ps1` (68 lines), `Invoke-IFXPackageAudit.ps1` (110) | the lock pins the hashes of both V3 scripts |
| assembly | `ifx-c5c-controlled-v1` | `-QualityTarget Assembly` → `Invoke-IFXQuality.ps1`, `Invoke-IFXAssemblyGuard.ps1` (79) | the assembly guard reads the V3 policy `stages/post/policy/layerguard.json` from its own package |
| frontend | `ifx-c5d-controlled-v1` | `-QualityTarget Frontend` → `Invoke-IFXQuality.ps1` | the producer sets a fixed Windows `PATH` |
| database | `ifx-c4b-controlled-v2` | `-Mode Specialized -SpecializedGate Database` → the Database branch of `Invoke-IFXSpecialized.ps1` (88 lines), `Test-MigrationSafetyPolicy.ps1` (88), `Invoke-G02DatabaseInventory.ps1` (24), `Test-DatabasePendingModelChanges.ps1` (44), `New-DatabaseMigrationArtifacts.ps1` (25), `contracts/detector-result.schema.json` | the Profile's `workspaceEvidence` roots include `V3_ifx/stages/post/gates/specialized` |
| type | `ifx-c1-r1b-controlled-v1` (V4-native) | — | reads `V3_ifx/.../rules/ARCH.BINARY.DOMAIN.CONTRACTS.json` and `.../policy/layerguard.json` |
| graph | `ifx-c1-r2b-controlled-v1` (V4-native) | — | none |
| generated | recorded for lineage only; no 0.5.0-a module consumes it | V3 scanner source | pins `docs/guards/V3/.../SourceFiles.cs` |

About 540 lines of gate logic move, plus the two V3 policy files the assembly guard and the type producer read.
Network steps (restore, NuGet and npm audits) stay workflow steps inside the producers, as in 0.5.0-a (F5).

### 10.2 Steps

| Step | Action | Gate |
| --- | --- | --- |
| A2-0 | Operator rulings R6–R11 (§10.3); commit this amendment and the fixed status of A1 | **Operator** |
| A2-1 | **Relocation inventory** `candidates/ifx-i2b-051/relocation-inventory.json`: every V3 file each producer reaches (call graph, dot-sourced and `Join-Path $PSScriptRoot` reads, package-local policies), with its SHA-256 at the certified commit. A generator re-derives it; a control fails on any unlisted V3 read | Local commit |
| A2-2 | **Byte-identical copy.** Copy the listed files into `v4-adoption/producers/<gate>/` unchanged, in their own commit, and record copy-equals-original for every file | Local commit; control |
| A2-3 | **Adaptation**, in a separate commit so every edit is reviewable against the copy: replace `$PSScriptRoot`-relative repository discovery with an explicit `-TargetRoot`; read the copied policies from the producer package; new producer entry scripts with new producer ids (R8); remove the frontend `PATH` override (R10); the type producer reads its embedded rule and policy copies (R9). Static controls: no path under `V3_ifx` or `V3` in any consumed producer, case-insensitive; no read outside the producer package and TargetRoot | Local commit; controls |
| A2-4 | **V3/V4 parity** on the same commit (R11): run each V3 gate and its relocated producer on the certified Target and compare the gate summaries and evidence semantically (paths and timestamps excluded). Negative parity: the existing catalog violation fixtures for the four consumers fail the same way under both. Every difference is listed and must be zero | Evidence; local commit |
| A2-5 | **Module successors 0.5.1**: the lock consumers whose producer identity changes (solution, assembly, frontend, database, and type under R9) get new producer ids, script hashes and `authorityHashes`; versions bump (0.2.0 → 0.2.1, database 0.3.0 → 0.3.1). The Profile replaces the `V3_ifx` `workspaceEvidence` root with `v4-adoption/producers/database`. The staging script successor runs the relocated producers and drops the unconsumed generated producer (R9). Suites rerun for the changed modules | Local commits; suites pass |
| A2-6 | Harness successors (bundle version, identities, change spec 0.5.0 → 0.5.1) and a trial of the C6 chain | Local commits |
| A2-7 | Readiness on the post-A2-6 commit (`-ReadinessOnly`) | Local |
| A2-8 | **Single C6c** for 0.5.1 | **Authorization** |
| A2-9 | C6d review packet: the producer identity change only; **human review** | **Operator acceptance** |
| A2-10 | C6e composition and installed-Host runs; parity against 0.5.0 (outcomes must be equal); P10.3 successor: the specimen and proposal drop `re-attests-v3-producer-until-0.5.0-b` for the four contexts, with a negative control that the attestation cannot return while any consumed producer reads `V3_ifx` | Local |
| A2-11 | Local verification (as A1-9) and receipt | Local |
| A2-12 | Push the A2 commits | **Authorization** |

### 10.3 Operator rulings needed before A2-1

- **R6 — location.** *Recommended:* `docs/guards/v4-adoption/producers/<gate>/`, inside the adoption package that
  the V3 allowlist ruling 2B already admits. *Alternative:* a lab tree under `candidates/` first, moved later.
- **R7 — two copies during coexistence.** V3 stays required until the coexistence window ends, so the V3 gates
  and their V4 copies both exist. *Recommended:* the V4 copy records the hashes of the V3 originals it came from;
  a harness control reports any later change to those originals as drift for review. The V3 originals are not
  edited. *Alternative:* forbid V3 edits to the four gates by policy until V3 retirement.
- **R8 — producer identity.** *Recommended:* new producer ids (`ifx-v4a-solution-v1`, `ifx-v4a-assembly-v1`,
  `ifx-v4a-frontend-v1`, `ifx-v4a-database-v1`), so a lock names which producer made it. *Alternative:* keep the
  ids and change only the script hashes.
- **R9 — type and generated producers.** *Recommended:* the type producer reads embedded copies of its two V3
  policy files (the type consumer embeds them already), and the staging script stops running the generated
  producer, which no module consumes. Then no consumed producer path reaches V3.
- **R10 — frontend toolchain.** *Recommended:* drop the fixed Windows `PATH`; the producer requires `node` and `npm`
  on `PATH` and records their versions in the lock, as it does today. The workflow's `setup-node` provides them.
- **R11 — parity standard.** *Recommended:* semantic equality of the gate summaries and evidence on the certified
  commit, plus the catalog violation fixtures, with zero listed differences. A difference stops A2 for review.

### 10.4 Acceptance for A2

- No consumed producer reads a path under `docs/guards/V3` or `docs/guards/V3_ifx` (static control and the
  relocation inventory).
- V3/V4 parity has zero differences (A2-4).
- The 0.5.1 C6c passes: Windows 191/191 and controls; Linux 191/191 with equal semantic projection.
- The installed-Host outcomes for 0.5.1 equal those for 0.5.0 (A2-10).
- The proposal owns the eleven contexts without `re-attests-v3-producer`, and the rehearsal rejects its return.
- V3, V3_ifx and `.github` stay byte-identical.

### 10.5 Planned paths (A2)

- `docs/guards/v4-adoption/producers/**` (new)
- `docs/guards/candidates/ifx-i2b-051/**` (lab tree: inventory, change spec, module successors, harness successors)
- `artifacts/guards/p10-ifx-i2b/**` (records)
- `docs/guards/v4-adoption/integrations/github/**`, `docs/guards/v4-adoption/plans/14-p10-3-successor-0-5-1.md`,
  `docs/guards/v4-adoption/migration/**`, `docs/guards/v4-adoption/README.md`
- this Plan pair and `docs/guards/TODO.md`

### 10.6 Out of scope for A2

- turning the build, test and inspection parts of the producers into V4 modules (a later phase);
- proving the producers' runtime prerequisites on the hosted runner (for example SQL Server for the database
  matrix); that belongs to installing and negative-testing the specimen;
- the workflow installation, the ruleset, 1A, the V3 allowlist change, publishing (I2-D) and V3 retirement;
- Guard product changes.

### 10.7 Progress

- **A2-0 (2026-09-30).** Rulings R6–R11 taken as recommended: producers under `v4-adoption/producers/<gate>/`;
  the V4 copies record their V3 origins and a control reports drift; new producer ids `ifx-v4a-*`; the type
  producer reads embedded policy copies and the generated producer is no longer staged; no fixed frontend `PATH`;
  parity is semantic equality with zero differences. A2-0 to A2-7 authorized for local execution.
- **A2-1 (`337ccd5c`).** Relocation inventory `candidates/ifx-i2b-051/relocation-inventory.json`: 18 files (11 from
  V3_ifx: 526 lines of gate code, two policies, one contract; the lab producer scripts and the database and type
  contracts). Every file reference of every origin is classified; an unlisted read into `docs/guards` fails (checked
  with a removed-origin negative case).
- **A2-2 (`241cbb41`).** Byte-identical copy into `v4-adoption/producers/`, Git blobs equal to the origins (18/18);
  `producers/origins.json` records the origins for the drift control (R7).
- **A2-3 (`9e2ac1df`).** Adaptation in its own commit: explicit Target root, direct calls to the relocated gate scripts
  with the unchanged output layout, the policy copies in `producers/policy`, the Database-only gate, source inventory
  v3, producer ids `ifx-v4a-*`, run directories `artifacts/guards/v4a-producers/<gate>-runs`, no fixed frontend
  `PATH`. Static controls pass with five negative mutations (`a2-relocation/a2-3-controls.json`).
- **A2-4 (`2fd78fa6`).** V3/V4 producer parity on one clean clone: zero semantic differences for solution, assembly,
  type, frontend and database; identity changes listed apart (producer ids, authority hashes, the V3 facade summary,
  the relocated inventory root). Negative parity 3/3: a lint error, an unsafe migration policy and a failing test
  fail both sides at the same check with the same message (`a2-relocation/a2-4-parity.json`). Two comparator faults
  were fixed on the way (dictionary keys, a variable colliding with a parameter name); the producer runs were reused.
- **A2-5 (`c206cdb9`).** The 0.5.0-a harness copied into `candidates/ifx-i2b-051` at the same depth and substituted
  (evidence root `artifacts/guards/p10-ifx-i2b/a2-051`, version 0.5.1). The five lock consumers pin the relocated
  producers (versions 0.2.1, database 0.3.1); the staging script runs them and passes `-TargetRoot`; the Profile
  `workspaceEvidence` names `producers/database`. Their suites pass on relocated-producer evidence: 60 cases, the 56
  shared with A1-3 identical in kind, expectation, outcome, findings and message, the four A1-4 cases passing
  (`a2-relocation/a2-5-suites/index.json`).
- **A2-6.** Matrix contract and fixture spec regenerated from the 0.5.1 inventory (only the five adapter hashes, the
  inventory projection and one fixture-script hash differ; verifier passes). Merged suite index for the contract
  handshake (`suite-index-051.json`: 20 from A1-3, 5 from A2-5). The focused qualification takes its workspace roots
  from the Profile (`New-IFX051WorkspaceEvidence.ps1`). Trial: the chain in readiness mode passes (bundle manifest
  `c241c2a8…`); parallel certification Windows 191/191, controls 180 + 42, Linux 191/191 semantic equal; harness
  controls 12 Windows, 4 PR-gate and the Linux controls pass. Two trial attempts stopped on harness faults and are
  kept. Records `a2-relocation/a2-6-trial/index.json`.
  - Next: A2-7, readiness on the committed state (`-ReadinessOnly`, evidence root `a2-051`).
