# V4 P10.1 C6c3 — independent detector and confinement certification

Status: `EXECUTION PLAN — C6c NOT YET CERTIFIED`

C6c2 proved that one 0.3.0 synthetic-review bundle built from source commit
`063f77703a53abcea7ca6aa507b4c4bfa9fc537c` passed the real IFX direct Pre,
direct Post and dependency Post on Windows and pinned, network-disabled native
Linux. The decision was committed at `9293545e77106e2abfd5de82fd27e9a5e66a2be0`.
That is a same-byte positive technical parity result only. Its locks are no
longer fresh, its candidate is not bound to the final C6c implementation
commit, and it did not execute the independent detector-family and confinement
matrix below.

This child closes only C6c. It neither supplies Xiaolong Feng's accepted review
nor enters C6e composition. The published 1.1.3 installation, archive, receipt,
Host, built-in modules, V3/V3_ifx authority and the real IFX TargetRoot remain
unchanged. All negative cases use disposable roots outside the repository and
all candidate composition remains `synthetic-test-only`.

## 1. Frozen identities and stop conditions

Before executable work, record the clean branch, exact source commit, published
1.1.3 archive/Package/receipt, Linux image digest, SDK `10.0.303`, 37-module / 83-rule /
79-claim ordinal inventory and the 36 external module byte inventory. Formal
Pre must accept this exact Plan before the new runner or decision record is
written.

The runner implementation and its case specification are committed first. Only
that clean implementation commit may become the candidate source commit. On
that commit, regenerate the C6b0 inventory and produce Frontend, Database,
Solution, Generated, Assembly, Type and Graph locks in this order. No expired,
earlier-commit or earlier-bundle lock may be reused. Later builds may not alter
the Assembly or Type DLL set. Construct one new 0.3.0 bundle from the unchanged
reviewed 36 external modules plus the published 1.1.3 Architecture Conformance
module; freeze its manifest, Profile, authority map, capability ceiling, empty
baseline selection, complete sorted path/hash/size inventory and synthetic
review hash.

Stop without C6c certification if a Host, schema, installer, composition
contract, built-in, module, producer or policy byte must change. Such a change
requires its own exact remediation/compatibility Plan and, where it affects the
published product contract, a new published `1.1.x` base. A timeout increase,
baseline, ignored result, transported transient dependency tree or
documentation-only exception is not a repair.

## 2. Exact independent detector matrix

The new runner consumes the frozen combined bundle, not a reconstructed
single-module bundle. Existing slice tests and fixtures may supply reviewed
input bytes, but their prior results are cross-checks only and cannot satisfy
this matrix. The runner freezes one sorted machine-readable case manifest
containing the case ID, platform applicability, module ID, rule/claim IDs,
fixture hash, lock identities, expected process exit, result status,
exit category, finding identity, evidence kind and minimum coverage.

Each row requires the following quartet on both Windows and pinned offline
Linux:

- **C (clean):** process exit 0, `pass/success`, no findings and every owned
  claim at or above its exact `minimumMatches`.
- **V (violation):** one independent case for every blocking rule owned by the
  module; process exit 0, `fail/findings-blocking`, exact rule/claim/subject/
  detector/evidence identity and nonzero coverage. The three C1h advisory
  companions are asserted in the same inputs and may not weaken their blocking
  owners.
- **M (missing input):** remove one declared prerequisite or required evidence
  object without changing policy; process exit 0, `error/prerequisite-missing`,
  zero findings and explicit missing identity.
- **Z (zero match):** retain syntactically valid input while selecting no
  subject for every owned blocking claim; process exit 0,
  `fail/findings-blocking`, coverage `matched = 0`, the unchanged positive
  minimum and an explicit non-vacuity finding.

| # | Detector family | Exact module | Required cells |
| ---: | --- | --- | --- |
| 1 | project/reference graph | `ifx-domain-reference` | C/V/M/Z |
| 2 | project/reference graph | `ifx-package-reference` | C/V/M/Z |
| 3 | project/reference graph | `ifx-ring-graph` | C/V/M/Z |
| 4 | project/reference graph | `ifx-ownership-graph` | C/V/M/Z |
| 5 | project/reference graph | `ifx-provider-cycle` | C/V/M/Z |
| 6 | source/Roslyn policy | `ifx-embedded-adapter` | C/V/M/Z |
| 7 | source/Roslyn policy | `ifx-source-policy` | C/V/M/Z |
| 8 | project/reference graph | `ifx-project-name` | C/V/M/Z |
| 9 | project/reference graph | `ifx-reference-cycle` | C/V/M/Z |
| 10 | project/reference graph | `ifx-injection` | C/V/M/Z |
| 11 | compiled architecture | `architecture-conformance` (`ARCH.TYPE_DEPENDENCY`) | C/V/M/Z |
| 12 | locked type provenance | `ifx-c1-type-provenance` | C/V/M/Z |
| 13 | evaluated project graph | `ifx-c1-evaluated-reference` | C/V/M/Z |
| 14 | G03 governance | `ifx-g03-governance-core` | C/V/M/Z |
| 15 | G03 governance | `ifx-g03-catalog-semantics` | C/V/M/Z |
| 16 | G03 governance | `ifx-g03-source-reconciliation` | C/V/M/Z |
| 17 | G03 governance | `ifx-g03-snapshots` | C/V/M/Z |
| 18 | G03 governance | `ifx-g03-docs-closeout` | C/V/M/Z |
| 19 | G04 governance | `ifx-g04-manifests` | C/V/M/Z |
| 20 | G04 governance | `ifx-g04-runtime` | C/V/M/Z |
| 21 | G04 governance | `ifx-g04-closeout` | C/V/M/Z |
| 22 | Plan04 policy | `ifx-plan04-extraction` | C/V/M/Z |
| 23 | Plan04 policy | `ifx-plan04-tenant` | C/V/M/Z |
| 24 | Plan04 policy | `ifx-plan04-projection` | C/V/M/Z |
| 25 | Plan04 policy | `ifx-plan04-abstractions` | C/V/M/Z |
| 26 | locked Database evidence | `ifx-database-evidence` | C/V/M/Z |
| 27 | G05 governance | `ifx-g05-inventory` | C/V/M/Z |
| 28 | G05 governance | `ifx-g05-protocol` | C/V/M/Z |
| 29 | G05 governance | `ifx-g05-execution-http` | C/V/M/Z |
| 30 | G05 governance | `ifx-g05-carriers` | C/V/M/Z |
| 31 | G05 governance | `ifx-g05-governance` | C/V/M/Z |
| 32 | G05 governance | `ifx-g05-closeout` | C/V/M/Z |
| 33 | Plan05 security | `ifx-plan05-security` | C/V/M/Z |
| 34 | locked Solution quality | `ifx-solution-evidence` | C/V/M/Z |
| 35 | locked Assembly quality | `ifx-assembly-evidence` | C/V/M/Z |
| 36 | locked Frontend quality | `ifx-frontend-evidence` | C/V/M/Z |
| 37 | history integrity | `ifx-history-integrity` | C/V/M/Z |

The minimum complete core matrix is therefore 37 clean, 37 missing and 37
zero-match cases plus 80 blocking-rule violation cases. The three advisory
rules are separately projected, for at least 191 core case results per
platform. A row cannot be summarized as passed when any owned blocking rule is
unexercised. Windows and Linux must consume the same case-manifest and fixture
bytes; their semantic projections must match even when absolute paths differ.

## 3. Lock, capability and root controls

For each of the seven lock families, independently prove fresh success,
missing lock (`prerequisite-missing`), altered bytes/hash (`integrity-failure`),
expired or stale time (`integrity-failure`), wrong target commit
(`integrity-failure`) and source/evidence change after production
(`integrity-failure`). Preserve the failing result and lock identity. The
candidate matrix must also repeat manifest tamper, baseline injection and
missing Type lock controls already seen in C6c2; their earlier pass is not
substituted.

Composition must reject every external module capability broadening: an
additional read root, any write root, an undeclared process, network access or
a timeout above its reviewed ceiling. Root-overlap cases must reject
PackageRoot=TargetRoot, StateRoot or EvidenceRoot inside PackageRoot/TargetRoot,
and any path traversal or symlink/junction escape. A test-only attempted
PackageRoot write and attempted TargetRoot write must fail closed. Hash the
entire PackageRoot, disposable TargetRoot, seven lock files and lock-listed
evidence before and after every case group; only the designated external State
and Evidence roots may change. No case may discover `guard/**` as an IFX
subject.

## 4. Database hermeticity gate

At C6c2 the Database producer selected 1,692 source files: 1,152 tracked files
and 540 Git-ignored files under the Frontend `node_modules` tree, including
package metadata, generated `.bin/*.ps1` shims and cache output. Copying those
Windows bytes into the Linux checkout proved transport parity only; it did not
prove a clean commit can reproduce the lock.

Before final lock production, a clean native Windows checkout and a clean
native Linux checkout must independently materialize dependencies offline from
the exact committed lockfile and pinned toolchain/cache, without copying a
working tree or `node_modules` between platforms. Record the sorted selected
path/hash inventory and its tracked/ignored classification. Both inventories
must equal each other and a second same-platform materialization. If the 540
transient inputs cannot be deterministically reproduced, C6c stops. Narrowing
or otherwise changing the Database producer scan is out of scope here and
requires a separate exact producer-remediation Plan followed by a new final
candidate.

## 5. Final execution and decision

After the implementation commit and hermeticity gate pass, run Windows-full
and offline Linux-complete, refresh all seven locks, freeze the candidate, then
run on both platforms:

1. direct Pre `10 modules / 22 claims`, direct Post `27 / 57`, and dependency
   Post `37 / 79`, with nonzero coverage, zero findings and exact stage order;
2. the complete independent core matrix and all lock/capability/root controls;
3. platform-native public 1.1.3 install and synthetic composition receipt
   verification, comparing archive, distribution manifest and complete
   path/hash/size payload identities; and
4. final PackageRoot, TargetRoot, lock and evidence invariance plus the exact
   version-ledger tuple.

Any correction to runner, fixture, case manifest, module or producer bytes
invalidates the candidate: commit the correction, refresh every short-lived
lock, rebuild the bundle and rerun both platforms. The decision record must
name every report/hash and distinguish technical C6c certification from C6d
human acceptance. G04 remains `PRE-READY` with seven blockers; G05 Phase 9 and
Diff/CI remain P10.3-deferred. P10.2 V3/V4 parity and P10.3 workflow/remote
changes remain out of scope.

Only this Plan pair, the deterministic C6c3 runner and its final decision note
are planned source paths. Evidence under `artifacts/guards/p10-ifx-c6c3` is
ignored. Formal Pre must pass before executable edits; isolated
`ifx-package-test` and exact committed Formal Diff are required for closure.
C6d begins only after this Plan has a passing decision on final bytes, and
C6e begins only after Xiaolong Feng explicitly accepts those exact bytes.

## 6. Preparation record

The Plan was prepared on clean local HEAD
`9293545e77106e2abfd5de82fd27e9a5e66a2be0`. After refreshing `origin`, the
branch remained 65 commits ahead of `origin/codex/v4-development-base` with no
remote-only commit. Published 1.1.3 Package Check passed with Package SHA-256
`9dd609291c80f2e66aa44302e31bdc9bfc114b4f52f00e631f7c256c96766494`;
the 137-file receipt and archive both bind archive SHA-256
`28307116aca1361e9eed5fdcd284a58cdfdb8fd3728869f09dd13f4c9a49b02e`.

Formal Pre passed at
`artifacts/guards/p10-ifx-c6c3/formal-pre/summary-pre.json`. The isolated IFX
Package positive and six negative/read-only controls passed at
`artifacts/guards/v3-ifx-package-test-89a0d10e5b3547b4b22225d10fe4f9d1`.
The recorded C6c2 ordinal inventory, Windows summary and Linux summary still
match their decision-note SHA-256 values, and its committed Formal Diff still
reports `pass`. These checks establish the starting point only; the C6c3
runner, fresh locks, final candidate and independent matrix have not run.
