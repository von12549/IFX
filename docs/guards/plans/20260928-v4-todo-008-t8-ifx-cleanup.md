# V4-TODO-008 T8 — protected removal of `docs/guards/v4` from IFX

Status: `LOCAL COMPLETE 2026-09-28 — S0–S8 done; S9 (IFX push and Guard records PR) needs a separate decision; see §7`

Formal Plan ID: `20260928-v4-todo-008-t8-ifx-cleanup`.

This Plan executes tranche T8, the final tranche of the master Plan
`20260927-v4-todo-008-standalone-repository-extraction` (§7 T8, handoff checklist items 7–10). T7 is
complete: IFX consumes V4 Guards 1.1.5 from `von12549/Guard`, and `docs/guards/v4` is a frozen,
non-canonical duplicate (IFX `fe007b52`, receipt
`docs/guards/v4-adoption/migration/v4-todo-008-ifx-rebinding-receipt.json`).

## 1. Scope (verified read-only 2026-09-28 at IFX `cdb53d18`)

| Item | Finding |
| --- | --- |
| Tracked files under `docs/guards/v4` | 169; exactly the 169 rows classified `obsolete-after-gate` by the T1 disposition (`T1-manifests/20260927T102631Z`). The six `move-after-gate` rows are already in `docs/guards/v4-adoption` |
| Content drift from the T1 source blobs | only `README.md` (T7 non-canonical notice) |
| Ignored files under `docs/guards/v4` | 2: `artifacts/p4c-fixtures/{clean,violating}/Sample.cs` |
| `.gitignore` | lines `/docs/guards/v4/state/`, `/docs/guards/v4/.work/`, `/docs/guards/v4/artifacts/` become stale |
| IFX application, solution, build files, V3/V3_ifx, `.github` | no reference to `docs/guards/v4` |
| Historical references (kept, not rewritten) | 87 formal Plans in `docs/guards/plans`; P10 and T7 evidence under `artifacts/guards`; migration records and TODO text in `docs/guards/v4-adoption` and `docs/guards/TODO.md`; the accepted verifiers `ifx-cutover-p10-3` and `ifx-parity-p10-2`, which already point at the pre-T7 layout |

### Couplings that T8 must resolve or disclose

1. `docs/guards/candidates/ifx-rebind-115/Test-IFX115CutoverRollback.ps1` rejects cleanup while
   `docs/guards/v4/plugin.json` is absent. T8 changes this control to: removal is valid only when the T8
   cleanup receipt exists and binds this Plan; removal without it stays a rejected negative control.
2. The accepted C6c Linux leg (`ifx-gate-coverage-c6c1/Test-IFXC6DualPlatformCandidate.ps1:88`) runs the
   V4 installer from the Target's `docs/guards/v4`. In T7 R3 this installed the 1.1.5 archive on Linux
   with the incubated installer; the script asserted that the resulting receipt (id, version, archive,
   manifest and every file) equals the Windows receipt produced by the release's own installer. After T8
   the next C6c Linux leg would fail. T8 does not edit the accepted script. It records the coupling as
   IFX-V4-003: the next C6c successor (needed anyway for IFX-V4-002) must take the installer from the
   release archive.

## 2. Steps

| Step | Action | Effect |
| --- | --- | --- |
| S0 | Commit this Plan pair after `plan validate` (installed 1.1.5 Host) | Local IFX commit |
| S1 | Pre-cleanup inventories: the 169 deleted paths with blob IDs and SHA-256; the retained V4-related paths (`docs/guards/v4-adoption`, `docs/guards/TODO.md`, `docs/guards/candidates/ifx-rebind-115`, `artifacts/guards/p10-ifx-115`); fingerprints of `src`, `tests`, `tools`, `docs/guards/V3`, `docs/guards/V3_ifx`, `.github` | Evidence |
| S2 | **Cleanup commit** (the single commit to revert for rollback): `git rm -r docs/guards/v4`; remove the three stale `.gitignore` lines; delete the two listed ignored fixture files by exact path and the then-empty directories | Local IFX commit |
| S3 | **Records commit**: cleanup receipt `docs/guards/v4-adoption/migration/v4-todo-008-ifx-cleanup-receipt.json` (deleted and retained inventories, cleanup and rollback commits, reference classification); proposal boundary `ifxCoreSourceRemoved`/`cleanupAuthorized` true with this Plan; the verifier change of §1.1; IFX TODO (V4-TODO-008 IFX side done, new IFX-V4-003); `v4-adoption` README and receipt pointers | Local IFX commit |
| S4 | Reference scan: no path outside the historical classes of §1 names `docs/guards/v4` | Evidence |
| S5 | Unchanged-ness: V3_ifx `Validate`; `src`/`tests`/`tools`/V3/V3_ifx/`.github` fingerprints equal S1; V3_ifx Quality Solution (build and tests of the IFX application) passes | Evidence |
| S6 | **Clean-environment consumer check**: in a new temporary root outside `guard-runtime`, download `v4-guards-1.1.5.zip` from `von12549/Guard`, verify SHA-256 `74c371eb…`, install it with the release's own installer, compose the accepted 0.4.3 bundle with its production review, pass the public composition verifier, and run installed-Host Pre on a detached worktree of the S3 commit: it must pass with non-vacuous coverage. Remove the worktree and the temporary root after copying evidence | Download; evidence |
| S7 | Re-run the P10.3 successor rehearsal on new absent paths after cleanup; all seven negative controls, including the new premature-cleanup form, must reject | Evidence |
| S8 | `git fsck --full --strict`, clean worktree, evidence index | Evidence |
| S9 | **Remote (separate authorization)**: fast-forward push of `codex/v4-development-base`; Guard records PR (checklist T8, receipt `ifxCoreSourceRemoved=true`, V4-TODO-008 complete) merged under `v4-main-autonomy` | IFX push; Guard PR |

## 3. Acceptance

- Exactly the 169 classified files, the two ignored fixture files and the three `.gitignore` lines are
  removed; nothing else is deleted.
- No live reference to `docs/guards/v4` remains outside the historical classes of §1.
- V3, V3_ifx, `.github` and the IFX application are byte-identical, and the application builds and its
  tests pass.
- IFX consumes the exact 1.1.5 release from a clean environment, and the post-cleanup Pre passes.
- The P10.3 successor rollback rehearsal passes after cleanup.
- The receipt sets `ifxCoreSourceRemoved=true`; `v4Activated`, `p10GatePassed` and `v3Retired` stay false.

## 4. Rollback

`git revert <S2 cleanup commit>` restores `docs/guards/v4` byte-for-byte (the receipt records the tree and
every blob). The records commit may be reverted with it. After S9 the revert is a reviewed commit on the
development branch; Guard is unaffected.

## 5. Stop conditions

Stop on any tracked file outside the 169 classified paths, blob drift other than `README.md`, an
unexpected live reference, any change to V3/V3_ifx/`.github`/application source, a failed Quality
Solution, a release identity mismatch, a failed clean-environment composition or Pre, a failed rehearsal
or negative control, or any need for a remote write before S9.

## 6. Authorizations requested

- **A-IFX-DELETE (local):** S0–S8, including the protected deletion and the S6 release download.
- **S9:** IFX push and the Guard records PR, requested after S8.

## 7. Outcome (2026-09-28, local)

| Step | Result |
| --- | --- |
| S0 | Plan committed `896bca24` |
| S1 | 169 tracked files (tree `5282001c`), 2 ignored fixtures; unchanged-root fingerprints recorded |
| S2 | Cleanup commit `ae42e11d`: 169 files and the three `.gitignore` lines removed (170 files changed); the two ignored fixtures deleted by exact path; `docs/guards/v4` no longer exists |
| S3 | Records commit `020af534`: cleanup receipt `fe371eda…`, proposal boundary, successor verifier premature-cleanup amendment, TODO (V4-TODO-008 IFX side done, new IFX-V4-003) |
| S4 | 109 files still name `docs/guards/v4`; all fall in historical classes (91 Plans, 5 evidence, 6 migration records, TODO, 1 historical inventory that names the old `artifacts/guards/v4` directory, 2 accepted pre-T7 verifiers, 2 T7 successor files asserting absence, the disclosed C6c Linux leg IFX-V4-003); zero unclassified |
| S5 | `src`, `tests`, `tools`, V3, V3_ifx, `.github` and `IFX.sln` byte-identical to S1; V3_ifx `Validate` pass; V3_ifx Quality Solution pass (81 projects, 1277/1277 tests) |
| S6 | Clean environment `D:4t	8-clean-…`: release archive `74c371eb…` downloaded and verified, installed with its own installer (package `e8cd3269…`), 0.4.3 composed with the production review (package `25fd95fa…`, identical to T7 R5), post-cleanup Pre on `020af534` passed (10/10 modules, 22 non-vacuous claims, 0 findings, Target unchanged); temporary root removed after evidence copy |
| S7 | P10.3 successor rehearsal after cleanup passed; all seven negative controls rejected, including premature cleanup without the T8 receipt; decision records `ifxCoreSourceRemoved=true` |
| S8 | See the evidence index |

The cleanup receipt's list of historical reference classes omits `docs/guards/inventories`; S4 evidence
classifies that one file. The receipt is not edited because the S7 decision binds its hash.

Evidence: `D:\IFX-Root4-todo-008-evidence\T8-cleanup60928T070603Z`. Rollback: `git revert ae42e11d`.
