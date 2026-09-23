# IFX C3 — G04 Phase 12 authority and claim matrix

Status: `INVENTORY COMPLETE — implementation pending`

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
| C3d | 23 | Current evidence/documentation and workflow classification, bounded test/runbook presence, Phase 12 `PRE-READY` closeout without approval promotion. |
| C3e | Aggregate | Compose the C3b–C3d candidates on the published 1.1.3 Host; direct/dependency Post, nonzero coverage, authority locks, four-root invariance and current V3 comparison. |

The C3b–C3d counts partition the 82 V3 checks; C3e is a separate aggregate
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
