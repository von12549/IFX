# G03 Phase 3 identity and compatibility policy

The catalog now freezes independent sync/event identity patterns, namespace/major-version mapping,
permanent Retired identity reservation, the Compatible/Conditional/Breaking/Internal decision
matrix, DTO construction and unknown-data rules, parallel V+1 migration, and the complete retire
predicate. The validator requires these policy nodes.

Four initial Change Records cover the four Proposed V1 identities. Each records the provider,
affected consumer, compatibility basis, release order, rollback, and current Proposed status.
Reusable Change Record and Breaking migration/ADR templates are checked in and their required
catalog equivalents are validated.

The formal V1 marker remains pending. Legacy Abstractions may be cut over atomically by Plans
01/02, but no identity becomes Active until physical Contracts.V1 source, API/serialization
snapshots, provider/consumer compatibility tests, source reconciliation, and approvals exist.

Verification: Phase 3 catalog/guard passed; LayerGuard ran 179 tests and remained B0.5
`baseline-clean`; solution build passed with 0 errors; all 904 solution tests passed.
