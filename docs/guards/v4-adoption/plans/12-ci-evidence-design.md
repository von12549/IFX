# V4 IFX CI evidence design — from snapshot attestation to a PR gate

Status: `DESIGN STUDY — IFX I2-B B2; AWAITS THE OPERATOR DECISION (B3). NO BUNDLE, PROFILE, MODULE, REMOTE, WORKFLOW OR RULESET CHANGE`

Formal Plan: `20260929-v4-ifx-i2b-ci-evidence-and-bundle` (phase I2-B of `20260929-v4-ifx-i2-p10-gate-successor`).

## 1. Question

The inactive specimen (`integrations/github/proposed-v4-ifx-guardrails.yml`) runs, on `windows-latest`, against the
PR checkout:

```text
stage run --stage post --with-dependencies --target-root $GITHUB_WORKSPACE --profile ifx_profile
```

Can bundle 0.4.4 pass that on an ordinary PR? If not, what must the successor bundle change, and who produces
the evidence the Post modules check?

## 2. Findings

### F1 — six Post modules need evidence locks that CI cannot supply (known since the program Plan)

Six consumer modules read a lock whose path and SHA-256 are fixed in the Profile config
(`evidenceLockPath`, `evidenceLockSha256`). Each adapter also requires:

- `lock.targetCommit` equal to the TargetRoot HEAD;
- a fresh lock: 24 h for solution, assembly, frontend and database; 1 h for type and graph;
- a source-tree fingerprint equal to the current tree;
- producer authority hashes equal to the module policy.

The locks live under the git-ignored `artifacts/guards/…` of one checkout. A Profile composed before the PR
cannot name a lock that the PR run creates. The seventh lock (`generated`) is recorded only in
`evidence-lineage.json`; no Post module reads it at run time.

`ifx-c1-type-provenance` and `architecture-conformance` also read the type run's `assembly-manifest.json`
(and the type module its four copied DLLs) from EvidenceRoot. The specimen has no step that stages them there.

### F2 — four producers are V3 gates (found in I2-B)

| Lock | Producer (`docs/guards/candidates/…`) | What it runs | V3 dependence | Network | Freshness | Consumer module |
| --- | --- | --- | --- | --- | --- | --- |
| solution | `c5b/Invoke-IFXSolutionEvidenceProducer.ps1` | V3 `Invoke-IFXGuardrails -Mode Quality -QualityTarget Solution`: restore, Release build, all tests (TRX), NuGet vulnerability audit of 81 projects | **runs V3**; pins V3 `Invoke-IFXQuality.ps1`, `Invoke-IFXPackageAudit.ps1` | restore, audit | 24 h | `ifx-solution-evidence` |
| assembly | `c5c/Invoke-IFXAssemblyEvidenceProducer.ps1` | V3 `-QualityTarget Assembly` on the built Domain DLLs | **runs V3**; pins V3 `Invoke-IFXAssemblyGuard.ps1`, `layerguard.json` | no | 24 h | `ifx-assembly-evidence` |
| frontend | `c5d/Invoke-IFXFrontendEvidenceProducer.ps1` | V3 `-QualityTarget Frontend`: `npm ci`, lint, tests, build, `npm audit` | **runs V3**; pins V3 `Invoke-IFXQuality.ps1` | `npm ci`, audit | 24 h | `ifx-frontend-evidence` |
| database | `c4b/Invoke-IFXDatabaseEvidenceProducer.ps1` | V3 `-Mode Specialized -SpecializedGate Database`: restore, build, publish the migrator, migration artifacts, safety policy, pending-model check, boundary tests, SQL Server matrix tests | **runs V3**; its source inventory includes `V3_ifx/stages/post/gates/specialized` | restore | 24 h | `ifx-database-evidence` |
| type | `c1r1b/Invoke-IFXCompiledTypeEvidenceProducer.ps1` | copies four Release DLLs and binds them to the solution and assembly locks | reads V3 `ARCH.BINARY.DOMAIN.CONTRACTS.json` and `layerguard.json` | no | 1 h | `ifx-c1-type-provenance` |
| graph | `c1r2b/Invoke-IFXEvaluatedGraphProducer.ps1` | `dotnet msbuild -getItem:ProjectReference` over the 58 `src` projects | none (V4-native); policy sources are in `docs/guards/candidates` | no | 1 h | `ifx-c1-evaluated-reference` |
| generated | `c1r2c/Test-IFXGeneratedInputDisposition.ps1` | full Release `Rebuild` with `EmitCompilerGeneratedFiles`, then analyzer and generated-input disposition | pins and reads the V3 scanner source `V3/…/Guards.ArchitectureConformance/SourceFiles.cs` | no | lineage only | none at run time |

The 0.4.3/0.4.4 cutover proposal maps the V3 contexts `v3-quality-solution`, `-assembly`, `-frontend` and
`v3-specialized-database` to the four consumer modules. Those modules only re-attest what the V3 gates
produced. Retiring the V3 contexts as proposed would remove the evidence producer; the ownership is circular.

The frontend producer also fixes a Windows `PATH` (`C:\Program Files\nodejs`, …), so it cannot run on Linux as
written.

### F3 — twenty Post modules pin the target snapshot (new, the larger blocker; IFX-V4-007)

Apart from the locks, 20 of the 27 Post modules bind the exact content of target files:

- The Profile carries **230 hash bindings** for those modules: authority lists and snapshot, fixture, tree and
  policy-source hashes.
- The bound files include about 83 product source files (for example `Program.cs` `f280698b…`, bound by G04,
  G05 and Plan05), 13 test files, 15 deployment files and both compose files (path classification of the module
  policies).
- Four modules pin a fingerprint of a whole source tree:
  - `ifx-g05-inventory` over every `src/**/*.cs`;
  - `ifx-plan04-tenant`, `ifx-plan04-projection` and `ifx-plan05-security` over their source sets.
- On any mismatch the adapter stops with `integrity-failure` ("Stale authority", "Current source tree lock drift").

Consequence: **any PR that edits C# under `src`** — and many that edit tests, deployment or architecture docs —
fails V4 Post, whether or not it breaks an architecture rule. The 0.4.4 Post is a **snapshot attestation of commit
`44536a6a`**, which is what P10 designed and certified. It is not a PR gate. The V3 specialized gates evaluate the
current content instead. The G03/G04/G05/Plan04 families were counted as "lock-free" in the program Plan; they are
not lock-free in CI.

Of the 27 Post modules only `ifx-history-integrity` needs no lock, no staged evidence and no target pin.
`architecture-conformance` pins nothing but needs the staged `assembly-manifest.json` (F1). All ten Pre modules
evaluate the current source and are PR-ready (I2-A proved a clean pass and a deliberate block).

### F4 — remaining V3 and lab-tree couplings in the bundle

I2-A found three:

- `ifx-c1-type-provenance` reads V3_ifx rule and policy files at run time;
- `ifx-c1-evaluated-reference` reads `docs/guards/candidates` policies;
- G03/G05 bind the V3-generated `layerguard-governance-input.json`.

I2-B adds three more:

- the generated producer pins and reads the V3 scanner source `docs/guards/V3/…/SourceFiles.cs`;
- the Profile's `workspaceEvidence.relativeRoots` includes `docs/guards/V3_ifx/stages/post/gates/specialized`;
- G05 and Plan05 bind LayerGuard baselines under `mcp/LayerGuard/baselines` (`b0.5`…`b4`, `plan05`, `plan06`,
  `plan07`), which is V3 LayerGuard data.

### F5 — V4 product constraints that shape any design

- The Host refuses a module whose manifest declares `network: true` (`capability-denied`, exit 13).
  - Package restore, NuGet vulnerability audit, `npm ci` and `npm audit` therefore cannot run inside a V4 module.
  - They have to be workflow steps before `stage run`.
- Modules in a stage run in Profile order. `--with-dependencies` runs the earlier stages first.
- Module timeouts are at most 3600 s.
- A module receives `runId`, `stateRoot` and `evidenceRoot`, and may write to the roots it declares.
  - The built-in `build-evidence-provider` → `architecture-conformance` pair already shows same-run evidence:
    the provider writes a manifest under EvidenceRoot, and the consumer reads it.
- A Profile is fixed for a bundle, so anything it pins by hash is fixed for the bundle's lifetime.

### F6 — measured cost

- **V3 on GitHub** (green run 35590883598, all on `ubuntu-latest`), in minutes:

  | Context | Minutes |
  | --- | --- |
  | architecture | 7.9 |
  | cross-platform-ubuntu | 6.2 |
  | quality-solution | 4.0 |
  | specialized-database | 3.4 |
  | cross-platform-windows | 2.2 |
  | pre-diff, frontend, g03 | 0.8 each |
  | g05 | 0.6 |
  | g04, plan04 | 0.5 each |
  | assembly | 0.4 |
  | historical-integrity | 0.2 |

- **Producers on a fresh local clone** of `64b23dde` (warm NuGet and npm caches; run next to the B1 per-file
  benchmark; B2 record `artifacts/guards/p10-ifx-i2b/b2-producers/producer-timing.json`), in seconds:

  | Producer | Seconds |
  | --- | --- |
  | solution | 960.7 |
  | database | 935.9 |
  | generated | 918.3 |
  | frontend | 48.5 |
  | graph | 23.9 |
  | assembly | 2.6 |
  | type | 1.3 |
  | **total, sequential** | **about 48 min** |

  Solution, database and generated each build the solution again. A CI design should build once and share the
  output (the V3 jobs share it through an artifact), which puts the V4 evidence job near the V3 critical path
  (about 12 min: architecture 7.9, then database after solution).
- **Attempt 1 of the same measurement failed** on IFX-V4-005: `RuntimeDrainCoordinatorTests.BeginDrain_*` missed
  its 1 s wait under load after 989.5 s, and no lock was issued
  (`b2-producers/attempt1-flaky-drain-test/`). Under D-A or D-B this would fail CI runs.
- **C6c Linux copy-back, per file vs archive** (B1 record `artifacts/guards/p10-ifx-i2b/b1-copyback/benchmark.json`):
  - The tree is a replica of the I1 Linux results: 69,945 files, 817 MB, copied from container-native overlayfs
    to the 9p Windows bind mount.
  - **Per-file copy: 5,696.5 s (95 min). Archive copy-back: 27.5 s, 207 times faster.**
    - The archive is 166 MB.
    - Its phases: list and hash 6.4 s, pack 9.1 s, verify 4.2 s, copy 6.4 s, reports 0.7 s.
  - The archive listing equals the replica source byte for byte. The Windows `-Deep` re-check of all 69,945
    files passes in 175 s; that re-check is optional and runs after the certification.

## 3. Context ownership — today and under each option

| V3 context | Proposal owner (0.4.4) | Evidence today | D-A | D-B | D-C |
| --- | --- | --- | --- | --- | --- |
| v3-pre-diff | v4-ifx-contract | V4-native | V4 | V4 | V4 |
| v3-architecture | V4 Pre + Post | Pre V4-native; Post C1 needs the type/graph locks | V4 (locks from trusted-base producers) | V4 | V4 Pre; C1 Post stays V3 |
| v3-quality-solution | ifx-solution-evidence | **V3 gate** | V4 re-attests V3 output | V4 | V3 |
| v3-quality-assembly | ifx-assembly-evidence | **V3 gate** | V4 re-attests V3 output | V4 | V3 |
| v3-quality-frontend | ifx-frontend-evidence | **V3 gate** | V4 re-attests V3 output | V4 | V3 |
| v3-specialized-g03 | ifx-g03 modules | snapshot pins + V3-generated projection | V4 after F3 rework | V4 after F3 rework | V4 after F3 rework, else V3 |
| v3-specialized-g04 | ifx-g04 modules | snapshot pins | same | same | same |
| v3-specialized-g05 | ifx-g05 modules | snapshot pins + LayerGuard baselines | same | same | same |
| v3-specialized-plan04 | ifx-plan04 modules | snapshot pins | same | same | same |
| v3-specialized-database | ifx-database-evidence | **V3 gate** | V4 re-attests V3 output | V4 | V3 |
| v3-historical-integrity | ifx-history-integrity | V4-native | V4 | V4 | V4 |
| v3-cross-platform-ubuntu-latest | v3-compatibility-bridge | V3 | bridge | bridge | bridge |
| v3-cross-platform-windows-latest | v4-ifx-windows | V4 Windows job | V4 | V4 | V4 |

## 4. Work common to every option

1. **Lock binding (F1).** 0.5.0 consumer modules stop reading `evidenceLockPath`/`evidenceLockSha256` from the
   Profile. They take the lock for the current run from EvidenceRoot (`locks/<gate>.json`), and verify:
   - the producer identity, and the producer source hashes pinned in the module policy;
   - `targetCommit` equal to HEAD;
   - freshness;
   - the source-tree fingerprint;
   - every evidence file hash listed in the lock.

   The trust anchor becomes the producer that the trusted-base workflow runs, as for V3 today. The workflow also
   stages the type run's `assembly-manifest.json` and DLLs into EvidenceRoot.
2. **Snapshot pins (F3).** For each of the 20 pinning modules, choose per authority:
   - **(i) keep the pin** when the file is a governance authority that should change only through a bundle update:
     ADRs, phase evidence, closeout records, the G04 release template;
   - **(ii) replace the pin by a check on current content** for product, test and deployment sources and whole
     trees. This is the V3 approach: evaluate the predicate on the file, or compare a regenerated inventory with
     the committed one.

   This is the largest design item. It touches 17–20 modules and needs a new C6 chain run.
3. **Couplings (F4).**
   - Package the V3_ifx rule and policy content into `ifx-c1-type-provenance`.
   - Embed the evaluated-reference source policies.
   - Define a non-V3 source for the G03 projection and the LayerGuard baselines, or keep them as pinned governance
     inputs owned by the adoption package.
   - Drop `V3_ifx/…/specialized` from `workspaceEvidence`.
4. **IFX-V4-005.** Any option that builds and tests the solution in CI will hit the timing-sensitive drain test
   (4 of 126 local runs). Fix it under an IFX product Plan before V4 becomes required.
5. **IFX-V4-006.** Every bundle change needs a C6c run. The archive copy-back (B1) replaces the per-file copy in
   the next C6c harness.

## 5. Options

### D-A — trusted-base V3 producers, V4 re-attests

The V4 workflow job runs the seven existing producers from the trusted base on the PR head (network steps
included), writes the locks into EvidenceRoot, then runs Pre and Post.

- **Cost:** the smallest.
  - Items 1–5 above.
  - The producers keep calling `V3_ifx/commands/Invoke-IFXGuardrails.ps1`.
  - The frontend producer needs its Windows `PATH` removed, or the V4 job stays on Windows.
- **What P10.GATE would mean:** V4 enforces, but four of its families are V3 gates wrapped by V4 checks. V3_ifx
  cannot be retired while they are, so I3 inherits the porting.
- **Risk:** the circular ownership stays; the proposal must say "re-attests" instead of "replaces".

### D-B — V4-owned producers in the adoption package

As D-A, but the producers and the gate logic they need move into `docs/guards/v4-adoption/producers/`, with no
path into `V3_ifx`:

- the V3 `Invoke-IFXQuality.ps1` (68 lines), `Invoke-IFXPackageAudit.ps1` (110), `Invoke-IFXAssemblyGuard.ps1` (79);
- the Database branch of `Invoke-IFXSpecialized.ps1` and its four scripts (about 180 lines).

About 500 lines of IFX-owned gate logic are relocated, re-identified and re-tested. Network steps stay workflow
steps (F5). The build, test and inspection parts may later become V4 modules.

- **Cost:** D-A plus the relocation, its controls and a parity run against V3 on the same commit (the P10.2
  corpus method).
- **What P10.GATE would mean:** all eleven owned contexts have a V4 producer; V3 contexts can be retired after
  coexistence; I3 shrinks to removing V3.
- **Risk:** two copies of the gate logic during coexistence. The parity run and a byte-identity check against the
  V3 originals at relocation time cover drift.

### D-C — narrow V4 ownership during coexistence

The V4 aggregate owns only what passes on a PR without producers:

- Pre;
- `ifx-history-integrity`;
- the F3 families after their snapshot rework.

The six lock consumers and `architecture-conformance` (which needs the staged type manifest) are disabled in the
CI Profile or stage configuration. Their V3 contexts stay required
and owned by V3; the proposal ownership is rewritten.

- **Cost:** items 2–3 above (F3 still applies); no producer work.
- **What P10.GATE would mean:** a smaller V4 claim than P10.3 designed — solution, assembly, frontend, database
  and C1 type/graph stay V3. A later phase would still need D-A or D-B.
- **Risk:** the least work now, the most work deferred.

## 6. Recommendation

**D-B, delivered in two steps inside one 0.5.0 bundle line:**

1. **0.5.0-a — the PR-gate rework**, which every option needs: lock binding by producer contract, the F3 pin
   split, and the F4 couplings. The Profile stops pinning live product, test and deployment files. At this step
   the producers are still the existing V3-wrapping scripts (D-A), so the bundle can be certified early. The
   C6c uses the B1 archive copy-back.
2. **0.5.0-b — relocate the four V3-wrapping producers** into `v4-adoption/producers/`, with a V3/V4 parity run.
   The proposal then owns the eleven contexts without a V3 producer.

Why not D-A alone: it leaves the circular ownership that I2-B was opened to resolve, and I3 would have to do
the same relocation later under more pressure.

Why not D-C: F3 applies to D-C too, so D-C saves only the producer relocation. That is about 500 lines of
IFX-owned logic, while D-C leaves the V4 claim smaller than P10.3 designed.

The first operator decision (B3) is therefore:

- whether to accept the F3 finding and the pin split rule (keep governance authorities, re-evaluate live
  sources), which changes what the certified modules claim;
- whether D-B in two steps is the target.

The amendment then lists the concrete module changes and the C6 chain re-run.

## 7. Not decided here

Workflow installation, the ruleset, 1A, the V3 allowlist change, publishing and V3 retirement keep their own
phases and authorizations.
