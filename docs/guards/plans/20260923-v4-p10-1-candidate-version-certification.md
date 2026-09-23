# V4 P10.1 — 1.1.1 local composition candidate and certification Plan

Status: `LOCAL 1.1.1 CANDIDATE SMOKE PASS — clean-commit/full certification pending; publication not authorized`

Predecessor: `20260923-v4-p10-extension-composition-compatibility` and the synthetic evidence in
`docs/guards/v4/plans/08-p10-1-extension-composition-compatibility.md`.

## Goal and boundary

Prepare the next unique V4 Guards `1.1.x` **candidate** so the local composition contract is
packaged, installed and certified rather than exercised only from canonical source. Use `1.1.1`
provisionally: the local tag inventory contains `v4-guards-v1.1.0` and no `v4-guards-v1.1.1`.
The read-only `git ls-remote --tags origin 'refs/tags/v4-guards-v1.1.*'` check on 2026-09-23
also returned only `v4-guards-v1.1.0`. Recheck before publication; if `1.1.1` becomes occupied,
stop and revise this Plan. Product and assembly versions change
together; the stable API remains `1.0`, and unchanged built-in module/Profile component versions
remain `1.0.0`.

This Plan permits local source, tests, documentation, build, install and certification evidence
only. It does not authorize a tag, push, GitHub Release, external bundle approval, `ifx_profile`
composition, IFX practice, workflow/ruleset change or cutover. The published 1.1.0 archive,
installation and receipt stay immutable. The H1–H4 `A` decisions and governance authority
`xiaolong-feng` are carried forward; this is not an approval record for any concrete bundle.

## Exact candidate work

1. Change `plugin.json`, Host and Web Companion project/assembly versions to the same unique
   `1.1.1` candidate version. Retain API `1.0`. Update the fixed-version assertions in P7
   distribution and P8 stable CLI tests. Add 1.1.1 candidate notes while retaining historical
   1.1.0 documentation as historical evidence. Refresh the root product/readiness documentation.
2. Refresh `compatibility-baseline.json` only from reviewed candidate bytes: update the plugin
   entry and add the four new public extension/composition schemas under configuration/report
   roles. Preserve the existing CLI and prior schema entries unless an exact compatibility
   decision requires otherwise. Test that drift in each new bound schema is rejected.
3. Make `tests/p10/Test-V4ExtensionComposition.ps1` runnable with **no external arguments** in
   platform certification. In that mode, it must create its own local candidate archive using
   the current package plus built Host/Companion, install it into a private artifact root,
   verify the base release receipt, and then run the same synthetic composition/negative matrix
   against that exact installation. The existing explicit-base mode remains available for the
   immutable 1.1.0 regression. No pre-existing sibling release, downloaded package or mutable
   test cache may be silently substituted. Its outputs must distinguish the 1.1.0 regression
   from the 1.1.1 candidate.
4. Add the P10 test and its final SHA-256 to `integrations/github/ci-contract.json` for
   Linux-complete and Windows-full certification. Refresh the prior prototype's changed P0
   contract test hash and hashes of changed P7/P8 tests only
   after their bytes are final. The certification runner's exact-discovered-test-set check must
   pass; registering P10 with both platform flags false is not acceptance.
5. Prove the 1.1.1 deterministic archive contains the composer, verifier, receipted Web
   Companion launcher and four schemas exactly once in its manifest; install to a new sibling
   with an external release receipt. Launch the **installed** receipted Companion against a
   synthetic composed sibling and verify Host session/readiness, Stage, query and receipt gates.
   A source-tree launcher does not satisfy this checkpoint.

## Validation and stop conditions

- Pass Formal Plan schema and Formal Pre on this exact path set before source edits. Keep the
  preceding prototype's uncommitted changes distinguishable from this candidate checkpoint;
  do not claim exact Diff or clean-commit certification until a reviewed candidate commit exists.
- Pass P0 contracts, Package Check, P7 distribution/lifecycle, P8 stable CLI/compatibility/
  supply-chain, P9 offline Web, and the self-contained P10 matrix. Include tamper, missing
  receipt, wrong base, interrupted stage, unreceipted output and root-immutability controls.
- Pass native Windows-full and pinned, `--network none` Linux-complete reports against one clean
  source commit, one package hash and the exact approved test hashes. Verify deterministic
  archive bytes and 1.1.1 product/Host/Companion/archive/receipt identity on both platforms.
- Record a candidate certification/recovery artifact and an exact Formal Diff. Keep
  `releaseAuthorized=false`, `activeIfxCutover=false` and `ifxProfileIncluded=false`.
- Stop on any unplanned path, unequal platform hashes, test-set mismatch, unsigned/unreviewed
  real bundle, missing installed-launcher proof, version collision or need to alter 1.1.0.
  Amend this Plan and rerun Formal Pre before expanding the path set.

The candidate is ready for a *separate* publication decision only after these gates pass.
Publication, real `ifx_profile` review/composition, detector-family zero-match controls and
installed Web UI hands-on practice remain later gates. No synthetic test result substitutes
for Xiaolong Feng's exact bundle-review decision.

## Local candidate checkpoint (2026-09-23)

Product, Host and Companion source now report `1.1.1`; API remains `1.0`. The compatibility
baseline binds the four new public schemas and P0/P7/P8/P9/P10 test hashes are listed in the
33-test CI contract. P0, Package Check, P6 workflow contract, P7 distribution/lifecycle, P8
compatibility/stable CLI/supply-chain/V1 acceptance, P9 offline Web and the P10 synthetic
matrix passed locally. Supply-chain and complete P8 Stage acceptance needed read-only access
to the pre-existing NuGet global cache outside the workspace sandbox.

The no-argument Windows P10 run built and installed a local 1.1.1 archive, used its installed
receipted launcher and passed the complete synthetic matrix:
`artifacts/guards/p10-composition/20260923T082426Z-d31eff9e53b84e1caa384636c6127019/summary.json`.
The same Windows-built archive (SHA-256
`2f996f170116a865ab021a969c9d20b428d8a39a0b577921a1b9732f0bd66c74`) was installed
and tested with `--network none` on Linux:
`artifacts/guards/p10-composition/linux-same-candidate-archive/20260923T082645Z-795fb3863b404f079a3ded1360e3d90f/summary.json`.
The resulting compositions had identical Package hash
`8e25435518a59238c97bcf97b09910629f005bf95d2ef841eb39073edbf59830`
and identical ordered 142-file inventories. Linux verified symlink refusal; this Windows
environment could not create the symlink fixture.

An additional network-disabled Linux smoke built its own archive and passed the no-external-
base-input test using an explicit source-commit parameter because that cached image lacks Git:
`artifacts/guards/p10-composition/linux-candidate-final/20260923T082149Z-eaf1dd2e22a14cb08b70862e6288b65c/summary.json`.
Its Package hash matched the corresponding Windows source build, but its native Host/Companion
artifacts and thus full installation inventory differed. This is a **different base archive**;
equal-input composition determinism is asserted only when both platforms install the same
archive. Per-platform archive reproducibility and the clean-commit certification gate are
still required. The cached Linux smoke image is not the pinned full-certification environment,
and no remote release or real bundle approval is claimed.

The current checkout also contains uncommitted predecessor P10.0 and prototype paths. Formal
Pre is `advisory` with zero unmapped candidate paths, but exact Diff and the platform
certification runner require a reviewed, clean candidate commit. Those gates have **not** been
run or inferred from local smoke results; predecessor changes must be separated and reviewed
before a certification checkpoint is recorded.
