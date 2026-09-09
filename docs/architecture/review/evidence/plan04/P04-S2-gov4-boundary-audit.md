# Plan 04 P04-S2 — GOV4 module-boundary audit

Date: 2026-09-10

Status: repository audit passed; Architecture and module-owner approvals pending; GOV4 not closed

## Conclusions

| Module | Repository conclusion | Primary evidence | Revisit focus |
| --- | --- | --- | --- |
| Auth | `retain` | cohesive identity/security data, no business protocol edge, independent tests | new non-identity capability or distinct security/runtime ownership |
| CRM | `retain` | owns party/account/compliance facts and publishes one minimal compliance decision | team ownership split, fan-out or distinct compliance SLO |
| Registry | `retain` | owns product/fund/class facts and publishes one sync decision plus one event | materially higher fan-out or product/class ownership split |
| Transaction | `narrow-edge` | consumes two bounded decisions and publishes one processed fact | prevent foreign Contract leakage into Application; new synchronous dependencies require review |
| Holdings | `retain` | owns position/freeze state and consumes two registered facts idempotently | distinct reporting owner or materially higher event fan-in |

No module is marked `revisit-boundary` or `extraction-candidate`, and `split-now` is forbidden. The
Transaction conclusion means its current integration edges stay confined to Infrastructure and
Composition; it does not recommend reducing business validation or introducing a network call.

## Direction and cycle review

The logical protocol graph is acyclic:

```text
CRM --------sync-------> Transaction --------event-------> Holdings
Registry ---sync-------> Transaction
Registry ---event----------------------------------------> Holdings
```

Sync-only, event-only, combined sync/event and physical project-reference graphs all have no cycle.
The physical dependency arrows run from consumer adapters to provider Contracts and therefore point
opposite the business fact/provider arrows. That expected inversion is not recorded as a mixed cycle.

CRM → Transaction, Registry → Transaction, and Transaction/Registry → Holdings all agree with G03
capability and data ownership. G02 reports no cross-schema access. The six physical cross-module
references all terminate at the provider's Contracts project and map to one G03 identity.

## Signals that do not decide a split

Registry has the largest provider fan-in signal and Transaction has the largest combined protocol
degree. All modules share one G04 release, one physical G02 database and one accountable owner. The
frozen change window also contains broad co-change. These are review risks, but the recent history is
dominated by the deliberate architecture migration and supplies neither independent team ownership
nor runtime, scaling, failure-isolation or compliance evidence.

## Closure state

[`module-boundary-decisions.json`](module-boundary-decisions.json) records evidence, risks and revisit
triggers for every module. [`phase2-audit-status.json`](phase2-audit-status.json) is intentionally
`repository-passed-approval-pending`: no named, dated Architecture or module-owner approval artifact
exists for this audit. Consequently ME2.7, the Phase 2 completion box and GOV4 closure stay unchecked.
