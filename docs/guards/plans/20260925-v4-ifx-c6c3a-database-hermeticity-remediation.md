# V4 P10.1 C6c3a — Database source-inventory hermeticity remediation

Status: `EXECUTION PLAN — REMEDIATION REQUIRED BEFORE C6c3`

C6c2 reproduced one Database evidence lock on native Linux only by copying the
producer's complete Windows-scanned file set. The scan contained 1,692 files,
of which 540 were Git-ignored Frontend `node_modules` metadata, generated
`.bin/*.ps1` shims and cache JSON. That proves byte transport, not clean-commit
reproducibility, and blocks the C6c3 hermeticity gate.

This child changes only the external C4b candidate producer/module contract and
the C6 native runner. It does not change the published 1.1.3 Host, installer,
schema or built-in modules, and therefore does not authorize a release. The
resulting module bytes invalidate every earlier C6 bundle and Database lock.

## Exact remediation

Add a hash-bound `source-inventory.json` authority to
`ifx-database-evidence`. It freezes the four existing roots, the existing
`.cs`, `.csproj`, `.json` and `.ps1` extension set, ordinal path ordering,
UTF-8/LF-normalized content hashing and the excluded generated directory names
`bin`, `obj`, `node_modules`, `dist`, `coverage` and `.vite`.

The controlled producer must enumerate the contract-selected filesystem set,
enumerate the corresponding Git tracked set, and fail unless they are exactly
equal. It emits producer identity `ifx-c4b-controlled-v2`, the contract hash,
the complete sorted path/hash inventory, count and aggregate hash. Thus a
selected untracked file blocks production, while excluded dependency/cache
bytes cannot enter the lock.

The adapter must require the v2 identity and contract hash, independently
recompute the same normalized filesystem inventory without executing Git, and
compare the complete locked projection, count and aggregate hash. A new
selected file, deleted file or content change fails closed; line-ending-only
checkout differences do not create platform drift. The Linux runner consumes
the same contract and stops transporting ignored dependency bytes.

## Required controls

The C4b test must retain clean, real-lock, stale, tampered, missing, zero and
source-drift controls and add:

1. ignored `node_modules` package metadata, `.bin/*.ps1` and `.vite` cache
   injection leaves the source inventory and clean verdict unchanged;
2. an untracked selected `.json` outside excluded directories changes the
   adapter inventory and fails closed;
3. changed inventory contract hash, v1 producer identity, reordered/duplicate
   source entries, wrong normalized file hash and missing selected file fail
   closed; and
4. Windows and native offline Linux compute the same sorted inventory, count
   and aggregate hash from clean tracked bytes without copying `node_modules`.

Module schema/hash checks, published 1.1.3 Package identity, synthetic Host
Post, immutable PackageRoot/TargetRoot checks, isolated `ifx-package-test`,
Formal Pre and exact committed Formal Diff must pass. After the remediation
commit, regenerate C6b0 inventory and all seven short-lived locks and rebuild
the final C6c3 candidate; no C6c2 candidate or lock may be reused.

Only this Plan pair, the source-inventory authority, Database producer,
Database module manifest/adapter/test, C6 Linux runner and remediation decision
note are planned source paths. Evidence under
`artifacts/guards/p10-ifx-c6c3a` is ignored. Any need to change published 1.1.3
bytes, reduce the nine Database checks, add a baseline, or accept an untracked
selected input stops this Plan. C6c, C6d and C6e remain unpassed; P10.2/P10.3
and V3 retirement remain out of scope.
