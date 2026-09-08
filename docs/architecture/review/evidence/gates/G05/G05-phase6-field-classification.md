# G05 Phase 6 — field classification and minimization

Date: 2026-09-08

## Outcome

Phase 6 extends the existing G03 catalog and validator instead of creating a second field authority.
The catalog now resolves classification, purpose, consumer, requiredness, retention, logging policy
and C3 exception reference for 167 fields across 32 surfaces. These comprise all 27 legacy public
DTO/Event types (134 source-reconciled fields), all four target protocols and Event Envelope V1.

The validator checks every legacy field name against its positional-record source, rejects missing
surface inventories, rejects C4, requires every C3 field to reference a governed exception, validates
sensitive-use references and self-tests the new failure paths. The Phase 6 catalog report records 12
passing mutation self-tests and zero errors.

## Decisions

- C4 is always denied by both name and semantic capability. Passwords, tokens, authorization data,
  cookies, OTP, API/client secrets, private keys and connection strings cannot enter a public
  Contract/Event; renaming, truncating, serializer-ignore or ordinary hashing cannot lower class.
- The broad Investor summary is split into identity, display, compliance-decision and tax-residency
  recommendations. No external consumer is evidenced for Name or tax residency; those stay internal.
- Event Name, AccountNumber, business Code, free-text RejectionReason and duplicate payload TenantId
  have explicit removal/replacement decisions.
- Financial Amount/Units/NAV and compliance data have purpose, consumer, encryption, access,
  retention, deletion and replay rules in the same catalog.

## Approval truth

The 11 C3 fields map to 8 exception records. Every record has an owner, required Security approver
role, expiry, compensating controls and revocation condition. None is recorded as approved: statuses
are `Pending` or `PendingRemoval`. This Phase proves the governance and enforcement shape, not
Security approval, and those pending records remain a G05 closure blocker.

## Verification

- G03 catalog validation: 32 surfaces, 167 fields, 11 C3 fields, 8 exception records, 0 errors.
- Catalog mutation self-tests: 12/12 passed, including missing inventory, incomplete C4 semantics and
  missing C3 exception.
- Generated LayerGuard governance hash matches the sole catalog.
- Full solution: 1007/1007 tests passed.
- Full build: 0 errors and the unchanged 20 package, nullability and obsolete-endpoint warnings.
- LayerGuard: 179/179 tests passed and the 03-A0 baseline check reported no new/stale violation.
- G05 Phase 6 guard: passed with all cumulative Phase 0–6 checks true.
