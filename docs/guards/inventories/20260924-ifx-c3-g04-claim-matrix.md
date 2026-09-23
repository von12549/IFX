# IFX C3 — G04 Phase 12 authority and claim matrix

Status: `C3b/C3c/C3d CANDIDATES VALIDATED — C3e pending`

The current V3_ifx Post entry point is `v3-specialized-g04`.
`Invoke-G04Verification.ps1` runs Phase 12 of the deployment/runtime guard
and the Plan02-C1 inbound check. A fresh local replay passed **70** Phase 12
booleans and **12** inbound booleans; the gate summary passed. This is not
production release approval: the Phase 12 status remains `PRE-READY`, with
`gateClosed=false` and `approvalGranted=false`.

The companion JSON fixes all 82 check IDs, their ordinal and destination,
10 detector-script hashes and 12 current target-authority hashes. All 12
target hashes match the C0 inventory. Its `controls` entries express required
negative, missing, stale and zero-match test families, not a claim that those
fixtures already exist.

| Child tranche | Checks | Required V4 candidate destination |
| --- | ---: | --- |
| C3b | 12 | Fresh deterministic deployment inventory; exact release/runtime manifest, schema and required binding hashes; orchestration, backpressure and failure policy. |
| C3c | 47 | Role-gated runtime and startup composition, worker identity/lease/drain/health/backpressure source claims, plus Plan02-C1 inbound context boundary. |
| C3d | 20 | Current evidence/documentation, bounded test/runbook presence, Phase 12 `PRE-READY` closeout without approval promotion. |
| P10.3-deferred | 3 | Current V3 workflow/source facts recorded by the inventory; required-check/workflow transition needs its own trusted-base Plan. |
| C3e | Aggregate | Compose the C3b–C3d candidates on the published 1.1.3 Host; direct/dependency Post, nonzero coverage, authority locks, four-root invariance and current V3 comparison. |

The C3b–C3d plus explicit P10.3-deferred counts partition the 82 V3 checks; C3e is a separate aggregate
acceptance, not an additional V3 predicate. Target declarations and generated
inventory must be freshly read from the IFX TargetRoot. V3 scripts remain
base-owned comparison authorities, never imported as V4 module runtime.
Every executable child Plan needs exact paths and Formal Pre before edits.

Release bindings include eight projected artifacts: module manifest,
deployment-unit catalog, infrastructure compatibility, schema release
manifest, migration manifest, release orchestration, backpressure policy and
failure matrix. Database migration execution remains C4b rather than being
implicitly authorized by a G04 release binding. CI workflow activation is
P10.3-deferred; C3d may verify the current workflow fact but cannot retire
the V3 required check. C5/C6 must first revalidate the older C1/C2 candidates
against the same 1.1.3 base used by C3/C4.

Evidence: `artifacts/guards/p10-ifx-c3/g04-baseline/guard.json`,
`plan02-c1.json` and `verification-summary.json`. Inventory is not a
production Profile, reviewed final bundle, IFX cutover or P10.2 parity.

## C3b checkpoint

The read-only `ifx-g04-manifests` Post candidate binds 19 TargetRoot
authorities and four blocking rules/claims to the 12 C3b-mapped aggregate
checks. Its independent logic verifies nonzero business/deployment subjects,
module and unit identities, eight exact binding paths and hashes, module
schema, dependency and backpressure policy, consumer-first orchestration and
failure-safety matrix. Sixteen direct clean/negative/missing/stale/zero cases
and a real IFX scan passed, as did synthetic-only composition and Post on
the published 1.1.3 Host. TargetRoot and PackageRoot remained invariant.
This is candidate coverage, not completed-release evidence.

The checked-in G04 runtime manifest's `hostArtifact.digest` is a frozen
release input, not the current `IFX.ApiHost.csproj` hash. V3's generator can
produce a different current-source digest but its Phase 12 gate does not
equate that output to the checked-in release. C3e must compare these semantics
explicitly; neither digest may be silently relabeled as the other.

## C3c checkpoint

The `ifx-g04-runtime` read-only Post candidate maps the **exact 47** C3c
check IDs to seven blocking claim families. Twenty fresh TargetRoot
authorities are locked. Twelve direct clean/negative/missing/stale/zero
fixtures, real IFX scan, synthetic-only published 1.1.3 Host Post,
determinism and immutable-root controls passed. File-presence checks prove
only that the referenced tests/evidence exist, not that they executed now.

One V3 predicate is vacuous against the current source: it tests whether
`Program.cs.IndexOf("builder.Services.AddMessaging()")` is less than the
module-registration index, but the first token is absent (`-1`). V4 checks
the actual `AddReliableMessaging(` token exists and precedes
`AddIamModule`. This is a recorded semantic strengthening, not an inferred
P10.2 parity result; C3e must retain the discrepancy in its comparison.

## C3d checkpoint

The read-only `ifx-g04-closeout` Post candidate locks 43 TargetRoot
authorities and checks the 20 active C3d predicates through four blocking
claim families. It validates all six diagram source/render triples,
bilingual decisions and links, historical evidence presence, seven owned
G04 blockers, production parameter ownership, exact `PRE-READY`/no-approval
state and Plan02-C1 closure without promoting later slices. Eleven direct
clean/negative/missing/stale/zero controls, real IFX, synthetic-only
published 1.1.3 Host Post, deterministic repeats and immutable roots passed.
The three Phase 10 CI/workflow predicates remain explicitly P10.3-deferred:
their historical facts were recorded in C3a, but no V3 required check was
retired by this module.
