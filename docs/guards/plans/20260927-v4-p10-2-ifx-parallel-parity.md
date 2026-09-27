# V4 P10.2 IFX parallel parity

Status: authorized execution

## Authorization and entry gate

The user explicitly authorized P10.2 planning followed by execution on
2026-09-27. Entry depends on the accepted C6e-R1 decision at
`artifacts/guards/p10-ifx-114/c6e-r1-042/c6e-r1-decision.json`, SHA-256
`94a7c01bd991a7b4371f6d3406b43f58830bdb29740c477db7abdaf2bb0ece22`.
That decision closes P10.1 practice without starting P10.2 or P10.3.

## Goal

Run the previously trusted V3/V3_ifx reference and the exact receipted
V4 1.1.4 plus `ifx_profile` 0.4.2 installation against one frozen IFX
parity corpus. Produce an independent, fail-closed comparison of verdict,
failure category, finding identity, subject semantics, evidence kind,
detector ownership, non-vacuity, authority hashes, prerequisites and report
provenance. Stop before P10.3 regardless of outcome.

## Frozen identities

- IFX Target commit:
  `40b4c0f85e5d8a63ac5af5c1da80d4d46ba32b82`
- detached reference checkout:
  `D:/IFX-Root/guard-runtime/fixtures/ifx-c6e-r1-clean-042`
- V3 plus V3_ifx inventory: 562 files, SHA-256
  `087a85f86561294cbc36223de40a6821aaa1de458164f715e06fa2404b807102`
- V3_ifx LayerGuard policy SHA-256:
  `b89172e667a3e5c51b4d065cc325a99ea293aa2696a548980c8125d9c0323fb5`
- V3_ifx trusted-components SHA-256:
  `2213db9f5d217bca12144b667d1af5fcfabf1ca707186dedadefaa75d62202be`
- V4 composed installation:
  `D:/IFX-Root/guard-runtime/releases/v4-guards-1.1.4-ifx-0.4.2-c6e-r1`
- V4 package hash:
  `739e2035b24f42a0d09719bd78d010de9320452086109fbdd95c064f67e5a6c1`
- composition receipt SHA-256:
  `51f5fc11b7fa36e14d83eade699979e31de2d06d3134af9caad9a329fd043345`
- Bundle manifest SHA-256:
  `82eb0c5db8ec3779bc10a43b89f0a9235e38d02819745e8f42bffa7fd9635ee5`
- Profile version/SHA-256: `0.4.2` /
  `b7aac25f5cefbaf4d99023a71e29130da283debbe7446e160b42d7f1cb385023`
- certified Windows case manifest SHA-256:
  `22d3b8b4ed018bfcfa1456402c6fefc2e53ce730795ed573f77022fb1e247eae`
- certified Windows summary SHA-256:
  `858b69949c0febc386557f8bb70287d2abe3a7c2af56e6f5aa20b2fbc7de9ff8`
- toolchain: PowerShell `7.6.6`, .NET SDK `10.0.303`, Git
  `2.49.0.windows.1`.

## Fixed corpus

The production Bundle contains ten modules and 22 blocking claims. Project
the exact certified C6c Windows cases for those modules into a P10.2 corpus:

- 10 clean cases;
- 10 missing-input cases;
- 10 zero-match cases; and
- 22 deliberate violation cases, one for every blocking claim.

Each projected case binds its C6c case ID, module, claim set, rule, fixture
SHA-256, captured TargetRoot fingerprint, V4 input hash and V4 result. The
clean real-IFX case additionally binds the detached checkout and exact commit.
The corpus projection is immutable after execution starts.

## Execution design

1. Verify every frozen hash, the detached clean checkout, the accepted C6e-R1
   decision and the public composition receipt before creating evidence.
2. Build the 52-case corpus only from the frozen C6c case manifest and its
   raw captures. Reject duplicate/missing cases, absent targets, fingerprint
   drift or any case outside the ten production modules.
3. Execute V3/V3_ifx from the detached certified checkout. Execute V4 only
   through the receipted installation. Give each engine separate mutable
   build/state/evidence roots; neither receives the other engine's output.
4. Capture process exit, structured verdict, rule/finding identity, subject,
   evidence kind, detector, coverage, prerequisite outcome, authority hashes
   and report hashes for each side.
5. Run a third independent comparison process after both result sets close.
   Clean and deliberate violations require semantic agreement. Missing-input
   acceptance, weakened severity, absent claims, stale evidence, zero-match
   success in V4 or any unexplained verdict difference is a blocking gap.
   An explicitly mapped V4 fail-closed strengthening over a V3 coverage gap
   remains visible and may pass only when it is not weaker than V3.
6. Recompute the V3/V3_ifx, V4 installation, Bundle/corpus and Target
   inventories. Authority and Target inputs must remain byte-invariant.
7. Record a final pass or stopped decision. A stopped decision preserves all
   gaps and does not authorize a repair or rerun.

## Acceptance criteria

- all frozen identities and the public composition verifier pass;
- the exact 52-case corpus and real clean Target are complete and immutable;
- both engines execute independently with complete provenance;
- all 22 blocking claims have deliberate violation evidence;
- every detector family has clean, missing and zero-match evidence;
- the independent matrix has no unresolved weakening, missing claim,
  prerequisite acceptance, stale evidence or unexplained verdict gap;
- protected roots are unchanged; and
- P10.3, activation, publication, V3 retirement and IFX cutover remain false.

## Planned repository paths

- `docs/guards/plans/20260927-v4-p10-2-ifx-parallel-parity.md`
- `docs/guards/plans/20260927-v4-p10-2-ifx-parallel-parity.plan.json`
- `docs/guards/candidates/ifx-parity-p10-2/`
- `artifacts/guards/p10-ifx-114/p10-2-parity-042/`

## Stop conditions

Stop and preserve evidence on identity drift, corpus incompleteness, a failed
engine launch, input mutation, accepted missing evidence, V4 zero-match
success, missing blocking-claim coverage, weakened severity, stale authority
or build evidence, or any comparison gap that is not explicitly and safely
explained. Do not modify a frozen engine, fixture, installation, prior
evidence or receipt. A correction requires a separate repair Plan and new
absent paths.
