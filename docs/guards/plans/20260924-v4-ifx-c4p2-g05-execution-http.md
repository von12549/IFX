# V4 P10.1 C4p2 — G05 execution and HTTP boundaries on 1.1.3

Status: `PLAN READY — Formal Pre passed; executable candidate pending`

Implement the exact 19 G05 Phase 2–3 checks in a read-only V4 Post module.
Cover the application execution-context port, bounded AsyncLocal lifetime,
composition and identity/tenant split, five fail-closed sources, middleware
ordering, public correlation/trusted gateway, W3C trace restart, tenant
rejection, route metadata, safe HTTP errors, integration tests and phase
evidence. Use current TargetRoot source/policy hashes and at least two
blocking claims with no baseline. Exercise clean, violating, missing, stale
and zero-subject controls, real IFX, synthetic-only 1.1.3 Host Post and
immutable roots.

The remaining G05 phases, Plan05 security, Plan04 and Database still require
separate implementation. This Plan does not approve a production Profile,
declare G05 closure or establish P10.2 parity. Formal Pre precedes
executable edits; exact Diff, isolated IFX package regression and published
1.1.3 identity close this tranche.

Formal Pre passed at `artifacts/guards/p10-ifx-c4p2/formal-pre` before any
executable edit. No C4p2 module, Profile or Host verdict is claimed yet.
