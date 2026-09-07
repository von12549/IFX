# G03 Phase 6 PRE-READY: compatibility automation

Implemented:

- current-source/catalog reconciliation for declarations, Reader methods, publishers/handlers,
  and the four current consumer call sites;
- baseline-mode prevention of new unregistered public debt;
- deterministic source-backed sync API and catalog-backed serialization golden snapshots;
- Active admission validation requiring physical source, snapshot, provider/consumer contract
  tests, and both sides' approvals;
- negative tests for duplicate identity, missing owner/consumer, broken references, C4, orphan
  Active admission, and illegal lifecycle.

The checked-in snapshots are explicitly `proposed-pre-active-baseline`; they are not evidence that
`Contracts.V1` source exists. G03-6.5 and G03-6.6 remain open until Plan 01 supplies real Provider
contract and Consumer adapter compatibility tests covering tenant, authorization, NotFound,
Denied, Unavailable, cancellation, optional/unknown fields and values, and supported old versions.
Plan 02 must supply the equivalent event adapter/schema tests before event Active promotion.

Revisit when either downstream plan requests Proposed -> Active. Owner: contract/event provider and
named consumer; acceptance requires the catalog `admissionEvidence` object to resolve every
required artifact and approval.

Technical verification passes: Phase 6 guard and reconciliation, LayerGuard (179 tests, B0.5
baseline-clean), solution build (0 errors), and all 904 solution tests.
