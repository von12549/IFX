# G02 Phase 1 schema and connection boundary report

Date: 2026-09-07

## Result

Phase 1 is complete. Each module now owns one schema constant and one required connection-string
name in its Infrastructure assembly. Each DbContext declares that schema as its default, and every
explicit table/join-table mapping uses the module constant.

| Module | Schema | Connection key |
| --- | --- | --- |
| Auth | `auth` | `AuthDatabase` |
| CRM | `crm` | `CrmDatabase` |
| Registry | `registry` | `RegistryDatabase` |
| Holdings | `holdings` | `HoldingsDatabase` |
| Transaction | `transaction` | `TransactionDatabase` |

The shared `RequiredConnectionString` validator rejects missing, blank, malformed, server-less, or
database-less settings. Its errors identify only the configuration key and never include the
connection value or an inner parser exception. The CRM, Registry, Holdings, and Transaction
`DefaultConnection` fallbacks have been removed.

## Enforcement

- `ModuleDatabaseBoundaryTests` verifies all five design-time models, relational entities, owned
  types, join tables, FK principals, and sequences stay in the owning schema.
- Registration tests prove each module fails when only `DefaultConnection` is present and selects
  its own independently changeable connection when supplied.
- The inventory guard now fails on missing default schema, cross-schema models/FKs/migrations,
  non-canonical schema literals, missing base configuration keys, or a reintroduced
  `DefaultConnection` fallback.
- Base and Testing settings declare all five module keys. No secret value was added.

## Verification

- Targeted database-boundary tests: 20 passed, 0 failed.
- EF Core pending-model check: Auth, CRM, Registry, Holdings, and Transaction all report no changes
  since the last migration.
- Solution build: passed, 0 errors (14 existing dependency/obsolete API warnings).
- Solution tests: 831 passed, 0 failed, 0 skipped.
- G02 deterministic inventory guard: passed; inventory SHA-256
  `28ec917be8810912d4fec82ed06be81b1b75f0104330385413b3fc175c35ab76`, manifest SHA-256
  `59ddebdc56462fc5de083ed4e522f5adb07eb373fc4263a2d8f3b6e806377cdb`.
- LayerGuard B0.5: `baseline-clean`; 116 matched, 0 new, 0 stale.
