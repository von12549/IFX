# V4 P10.1 C6c5 — certification controls and bounded dual-platform execution

Status: `EXECUTION PLAN — C6c NOT YET CERTIFIED`

C6c4 repaired the independent matrix contract without changing product bytes.
On source commit `ec26441db4289d38f1d866169c3abd32d9af5412`, a fresh
Windows candidate passed direct Pre `10/22`, direct Post `27/57`, dependency
Post `37/79` and the remediated independent matrix at `191/191` with zero
gaps. That result does not complete C6c: the seven-lock negative matrix,
capability broadening, root confinement and attempted immutable-root write
controls still lack one fail-closed execution record.

The same candidate also exposed an orchestration constraint. Pinned,
network-disabled Linux direct Pre passed, but the first direct Post attempt
omitted the read-only offline NuGet cache and correctly failed on the locked
ArchUnitNET closure. The corrected retry validated that closure and then
correctly failed because the one-hour compiled Type lock had expired. No
timeout, lock timestamp, product byte, policy, baseline or waiver may be
changed to hide that result.

## Control matrix

Add one read-only certification-control runner. It consumes the exact fresh
inventory, bundle, synthetic review and seven locks. Every mutation happens
under disposable roots and the original PackageRoot, TargetRoot, bundle and
locks are fingerprinted before and after.

For each lock family — Solution, Assembly, Frontend, Database, Type, Graph and
Generated — prove current success plus missing, altered bytes/hash, stale or
expired time, wrong target commit and post-production source/evidence change.
Each negative must reach the owning frozen adapter and return its exact
fail-closed category and detector identity. A summary row is not sufficient
unless the mutated lock/evidence identity and unchanged original-root hashes
are recorded.

For every one of the 36 external modules, generate schema-valid disposable
bundle variants that independently broaden an additional read root, any write
root, an undeclared process, network access and the reviewed timeout ceiling.
Composition must reject all 180 variants before installation. No variant may
rewrite the reviewed ceiling or synthetic-review authority.

Exercise PackageRoot/TargetRoot overlap, StateRoot or EvidenceRoot inside an
immutable root, lexical traversal and supported link/junction escape cases.
Test-only modules that attempt a PackageRoot write and a TargetRoot write must
fail closed while the complete roots remain byte-identical. Unsupported link
creation is recorded as a platform limitation, never as a pass.

## Bounded dual-platform execution

Add a native Linux entry point that installs the unchanged published 1.1.3
archive, verifies the Linux receipt payload against the Windows receipt, runs
the existing positive candidate checks, then executes the unchanged C6c4
matrix runner with `-Platform linux`. It requires SDK `10.0.303`, the pinned
image digest, `--network none`, the exact read-only offline NuGet cache and the
same inventory, bundle, review, lock and fixture bytes used on Windows.

Add a Windows orchestration entry point that validates the clean source
commit, image digest and candidate identities, then starts the Windows matrix,
Linux positive-plus-matrix and control matrix concurrently. This is scheduling,
not a freshness extension: all owning adapters still enforce their lock times.
The orchestrator fails unless both 191-row manifests pass, their normalized
semantic projections are equal, all controls pass, and PackageRoot,
TargetRoot and original locks remain unchanged.

## Decision boundary

After implementation is committed, regenerate C6b0 inventory, all seven
locks, the 0.3.0 bundle and synthetic review. Run the parallel certification
once from that clean commit. Isolated `ifx-package-test`, Formal Pre and exact
committed Formal Diff remain mandatory.

Stop without C6c certification if any detector, module, producer, policy,
published 1.1.3 byte or reviewed capability ceiling must change, or if native
Linux cannot reproduce the Windows semantic projection. C6d human acceptance,
C6e installed composition, P10.2/P10.3 and V3 retirement remain out of scope;
G04 remains `PRE-READY`.

Only this Plan pair, the three C6c5 runner files and the C6c5 decision record
are planned source paths. Evidence under `artifacts/guards/p10-ifx-c6c5` is
ignored. Formal Pre must pass before executable edits.
