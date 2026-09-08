# Plan 00 Phase 0 architecture decision confirmation

Date: 2026-09-08
Decision authority: repository owner (`@von12549`)
Status: M0.2–M0.4 confirmed; M0.5 remains open

## Confirmed decisions

1. **M0.2 — architecture constraints:** M-C01 through M-C12 are approved as the implementation
   constraints for Plans 01–03. Any later deviation requires an explicit reviewed decision record.
2. **M0.3 — Contracts physical naming:** use a staged migration. Introduce `*.Contracts` and, only
   where needed, a minimal compatibility namespace/package or shim; migrate consumers in verifiable
   increments; remove `*.Abstractions` and expired shims in Plan 01 Phase 6. Do not use an atomic
   repository-wide rename as the migration unit.
3. **M0.4 — Integration Adapter organization:** initially keep consumer-owned adapters under
   `Infrastructure/Integrations/<Provider>`. Split an adapter into an independent project only when
   adapter volume, technology isolation, or deployment constraints justify it and the change has an
   approved record. LayerGuard must validate either physical form using the same adapter role.

## Retained control

M0.5 is not complete until Plans 01, 02, and 03 each have a recorded delivery owner, target
milestone, and accepting party, and the existing database/transaction prerequisites have named
accountability. A delivery owner may own multiple plans. Final Gate approval remains multi-role and
cannot be inferred from assignment of a single delivery owner.
