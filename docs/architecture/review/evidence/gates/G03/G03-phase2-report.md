# G03 Phase 2 public-surface classification

All 46 legacy public-surface items are now individually cataloged: 4 Reader types, 15 Reader
methods, 7 DTOs, and 20 integration-event declarations. Each record has one resolvable owner, an
explicit Internalize/Replace/Remove disposition, a downstream plan item, a 2026-12-01 deadline,
and an objective removal condition.

Only the two evidenced synchronous methods and two evidenced events point at Proposed V1
identities. Their containing CRM/Registry Readers are also marked Replace as legacy containers;
this does not admit their other methods. All other methods, DTOs, and events are Internalize or
Remove. `HoldingFrozenEvent` is explicitly Remove because source reconciliation found neither a
producer nor a consumer.

The catalog remains in baseline mode and every old item remains `LegacyPendingMigration`. No old
CLR type is mislabeled Active, and new items cannot use that lifecycle. The target burn-down is
zero legacy Abstractions items after Plans 01/02 perform the real migrations and return source,
snapshot, and consumer evidence.

The Phase 2 guard compares normalized `(project,type,member)` keys from the immutable Phase 0
inventory to the catalog: 46 matched, 0 missing, and 0 unknown. Catalog negative tests, LayerGuard
(179 tests; B0.5 baseline-clean), solution build (0 errors), and all 904 solution tests passed.
