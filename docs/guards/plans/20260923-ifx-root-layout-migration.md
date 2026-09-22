# IFX workspace root migration

Status: authorized for staged execution on 2026-09-23. The existing `D:\IFX` repository and all of
its registered linked worktrees remain in place as rollback sources; deletion, pruning and relocation
of those worktrees are outside this Plan.

Predecessor: `20260923-v4-ifx-profile-validation-program`

## Goal

Create one clean parent workspace at `D:\IFX-Root`, establish a fresh independent IFX repository at
`D:\IFX-Root\IFX`, and install the released V4 Guards 1.1.0 beside it under an isolated runtime tree so
PackageRoot, TargetRoot, StateRoot and EvidenceRoot are explicit non-overlapping siblings.

## Authorized topology

```text
D:\IFX-Root\
├─ IFX\                                           TargetRoot and canonical working repository
└─ guard-runtime\
   ├─ downloads\                                 verified release assets
   ├─ releases\
   │  └─ v4-guards-1.1.0\
   │     ├─ package\                              PackageRoot
   │     ├─ host\
   │     ├─ companion\
   │     └─ distribution-manifest.json
   ├─ receipts\v4-guards-1.1.0.install.json
   ├─ state\                                      StateRoot
   └─ evidence\                                   EvidenceRoot
```

`D:\IFX-Root` is only a container and is never passed as TargetRoot. No junction, symbolic link or
reparse point is used.

## Procedure

1. Confirm `D:\IFX` is clean and `codex/v4-development-base` equals its pushed remote.
2. Commit and push this exact documentation change before creating the new clone.
3. Create `D:\IFX-Root` and clone the GitHub repository into `D:\IFX-Root\IFX` on
   `codex/v4-development-base`, producing a new independent `.git` directory rather than moving or
   copying the old one.
4. Verify the new clone HEAD, remote URL, clean status and annotated `v4-guards-v1.1.0` peeled target.
5. Create the runtime container, download the two GitHub Release assets and verify the archive SHA-256
   is `d7d3b1ef7f70bab3153c4d1253b8a1e6db2bdea13645fe6597d36c29432c9fbd` and the sidecar agrees.
6. Use the released lifecycle installer from the new clone to install into the versioned release root
   and write the receipt outside that root.
7. Create empty StateRoot and EvidenceRoot siblings, then validate package hash, product/API version,
   prerequisites, exact root non-overlap and current V3/V3_ifx baseline from the new clone.
8. Keep `D:\IFX` untouched until later explicit cleanup authorization. Existing linked worktrees remain
   associated with it and are not considered migrated.

## Validation

- New clone HEAD equals the pushed migration documentation commit and is clean.
- `origin` remains `https://github.com/von12549/IFX.git`.
- `v4-guards-v1.1.0` peels to certified candidate
  `a81a12e0d1f476c563497f961fe41fccc53edfb6`.
- Installed archive, receipt and package report version 1.1.0, archive SHA-256
  `d7d3b1ef7f70bab3153c4d1253b8a1e6db2bdea13645fe6597d36c29432c9fbd` and package hash
  `cfea69e151f4edcccb51c16f91ce3c1d2651bcdf89323ea133fdff8f37615802`.
- PackageRoot, TargetRoot, StateRoot and EvidenceRoot all exist, are pairwise non-overlapping where the
  V4 contract requires it, and contain no link/reparse boundary.
- V4 package validation and V3 Validate pass from the new repository.
- The old repository still resolves to its original HEAD and linked-worktree registry.

## Recovery

If any new-root validation fails, stop using `D:\IFX-Root` and continue from unchanged `D:\IFX`.
Removal of a failed new root, removal of the old repository, worktree pruning or saved-project
reconfiguration is a separate action. This Plan never deletes or overwrites existing data.
