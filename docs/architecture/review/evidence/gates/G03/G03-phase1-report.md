# G03 Phase 1 catalog and ownership report

The repository now has one machine-readable governance source at
`docs/architecture/review/gates/G03/contract-event-catalog.yaml`. It is JSON-compatible YAML so
the checked-in PowerShell validator can parse it without a machine-specific YAML dependency; the
companion JSON Schema documents the interchange contract.

The catalog resolves Auth, CRM, Registry, Transaction, Holdings, and Platform Messaging ownership
to the repository's actual maintainer identity evidenced by Git history. It records two internal
consumers and four Proposed V1 protocols. There are no evidenced external consumers; the schema
requires system evidence, owner/contact, supported version, and last confirmation before one can
be admitted.

The Phase 1 validator-generated graph contains four edges:

- CRM -> Transaction (sync account compliance)
- Registry -> Transaction (sync class subscription availability)
- Transaction -> Holdings (transaction-processed event)
- Registry -> Holdings (class-status-changed event)

The graph has zero synchronous and zero mixed cycles. Each Proposed protocol records tenant scope,
authorization, freshness, failure semantics, field-level C0-C4 classification, purpose, retention,
log policy, and test locations. No C4 field is admitted.

Negative validator self-tests prove failures for duplicate identity, missing owner, missing
consumer, broken module reference, and C4 exposure. The generated catalog report is the authority
for edge data; this prose is an evidence summary, not a second hand-maintained graph input.

Verification: G03 Phase 1 guard passed; LayerGuard ran 179 tests and remained B0.5
`baseline-clean` (116 matched, 0 new, 0 stale); solution build passed with 0 errors; all 904
solution tests passed.
