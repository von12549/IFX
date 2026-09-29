# IFX I2-B — CI evidence design and successor bundle (starts with IFX-V4-006)

Status: `ACTIVE — B0–B2 authorized 2026-09-29 ("授权 B0–B2"); B3 is an operator decision; implementation needs a separate authorization`

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
