# Plan: DateTimeOffset Migration

**Status:** Implementing

---

## Overview

Replaces all `DateTime` audit and domain fields with `DateTimeOffset` across the entire IFX solution. Currently, all five DbContexts write `DateTime.UtcNow` into `datetime2` SQL Server columns. This silently discards timezone context and makes round-tripping to clients ambiguous — a client in UTC+10 receives a bare `DateTime` with no offset indicator. Switching to `DateTimeOffset` stores the offset in the database (`datetimeoffset` SQL type), removes the need for callers to assume UTC, and aligns with ISO 8601 best practices. The change is purely structural: existing UTC timestamps remain correct — they gain a `+00:00` suffix rather than changing their point-in-time value.

---

## Goals

- Replace `IAuditableEntity.CreatedAt / UpdatedAt` in `BuildingBlocks.Domain` with `DateTimeOffset`
- Replace Auth module's own `IAuditableEntity.CreatedAt / UpdatedAt` with `DateTimeOffset`
- Update all five `SaveChangesAsync` overrides to assign `DateTimeOffset.UtcNow`
- Update all non-audit `DateTime` domain fields (Auth domain: `EmailVerificationToken`, `LoginEvent`, `UserGlobalRole`, `UserActivityLog`; any others found during implementation)
- Update all DTOs that surface `DateTime` properties to use `DateTimeOffset`
- Update all EF configurations that need explicit column type overrides (default EF mapping for `DateTimeOffset` → `datetimeoffset(7)`)
- Add EF migrations for all five modules that alter affected columns from `datetime2` → `datetimeoffset`
- Ensure all 793+ existing tests pass with no test-data changes beyond using `DateTimeOffset` values
- Zero functional change — timestamps are UTC before and after; only the type and SQL column type change

---

## Non-Goals

- Changing any business logic or timestamp semantics
- Adding timezone conversion or user-local-time display (UI concern)
- Migrating data values — existing `datetime2` values are UTC so can be cast directly
- Changing `OpaEnvironmentAttributes.Time` format (already formats to ISO 8601 string `"O"`, no change needed)
- Addressing `ApiResponse.Timestamp` JSON serialization format (existing format remains compatible)

---

## Architecture

### Layers Touched

| Layer | Changes |
|---|---|
| **Domain** | `IAuditableEntity` (BuildingBlocks + Auth copy), Auth non-audit entities (`EmailVerificationToken`, `LoginEvent`, `UserGlobalRole`, `UserActivityLog`) |
| **Application** | DTOs that include `DateTime` properties → `DateTimeOffset`; any `DateTime` comparisons in handlers/validators |
| **Infrastructure** | All 5 `SaveChangesAsync` overrides (`IfxDbContext`, `CrmDbContext`, `RegistryDbContext`, `HoldingsDbContext`, `TransactionDbContext`); EF column type overrides if any; EF migrations per module |
| **Presentation** | `ApiResponse.Timestamp` field type; request/response models that bind `DateTime` parameters |

### Affected Modules (5)

| Module | DbContext | Migration Needed |
|---|---|---|
| Auth | `IfxDbContext` | Yes — all audit columns |
| CRM | `CrmDbContext` | Yes — all audit columns |
| Registry | `RegistryDbContext` | Yes — all audit columns |
| Holdings | `HoldingsDbContext` | Yes — all audit columns |
| Transaction | `TransactionDbContext` | Yes — all audit columns + `ProcessedAt`, `SettlementDate` |

### Key Files

- `src/BuildingBlocks/IFX.BuildingBlocks.Domain/IAuditableEntity.cs` — root interface (all modules)
- `src/Modules/Auth/IFX.Modules.Auth.Domain/Common/IAuditableEntity.cs` — Auth module's own copy
- `src/Modules/Auth/IFX.Modules.Auth.Domain/Entities/EmailVerificationToken.cs` — `ExpiresAt`, `UsedAt`
- `src/Modules/Auth/IFX.Modules.Auth.Domain/Entities/LoginEvent.cs` — `LoginTimestamp`
- `src/Modules/Auth/IFX.Modules.Auth.Domain/Entities/UserGlobalRole.cs` — `AssignedAt`
- `src/Modules/Auth/IFX.Modules.Auth.Domain/Entities/UserActivityLog.cs` — `Timestamp`
- All 5 `*DbContext.cs` SaveChangesAsync overrides
- All `*Dto.cs` files exposing `CreatedAt`/`UpdatedAt`

---

## Implementation Steps

### Phase 1 — BuildingBlocks + Shared Interfaces

- [ ] Update `IAuditableEntity` in `BuildingBlocks.Domain`: `DateTime CreatedAt/UpdatedAt` → `DateTimeOffset`
- [ ] Update `IAuditableEntity` in `Auth.Domain/Common`: same change
- [ ] Scan and fix any `BaseEntity` or `AuditableEntity` abstract classes that implement the interface

### Phase 2 — Auth Domain Non-Audit DateTime Fields

- [ ] `EmailVerificationToken`: `ExpiresAt` → `DateTimeOffset`, `UsedAt` → `DateTimeOffset?`; update `IsValid()` comparison to `DateTimeOffset.UtcNow`
- [ ] `LoginEvent`: `LoginTimestamp` → `DateTimeOffset`
- [ ] `UserGlobalRole`: `AssignedAt` → `DateTimeOffset`
- [ ] `UserActivityLog`: `Timestamp` → `DateTimeOffset`

### Phase 3 — Transaction Domain DateTime Fields

- [ ] `Transaction`: `ProcessedAt` → `DateTimeOffset?`; `SettlementDate` stays `DateOnly` (no change)
- [ ] `Order`: `CreatedAt`/`UpdatedAt` via IAuditableEntity (covered by Phase 1)
- [ ] `ExpectedTradeDate`/`ExpectedSettlementDate` on `Order` — these are `DateOnly` (calendar dates, not instants — no change needed)

### Phase 4 — Infrastructure: DbContext SaveChangesAsync

- [ ] `IfxDbContext.SaveChangesAsync` — `DateTime.UtcNow` → `DateTimeOffset.UtcNow`
- [ ] `CrmDbContext.SaveChangesAsync` — same
- [ ] `RegistryDbContext.SaveChangesAsync` — same
- [ ] `HoldingsDbContext.SaveChangesAsync` — same
- [ ] `TransactionDbContext.SaveChangesAsync` — same

### Phase 5 — EF Configurations

- [ ] Review all `*Configuration.cs` files: remove any explicit `.HasColumnType("datetime2")` overrides on audit columns (EF will auto-map `DateTimeOffset` → `datetimeoffset(7)`)
- [ ] Keep explicit column types for `DateOnly` fields (unrelated, no change needed)
- [ ] Verify no `ValueConverter` is registered that would conflict

### Phase 6 — Application DTOs

- [ ] Update all `*Dto` record/class definitions: `DateTime CreatedAt` → `DateTimeOffset`, `DateTime UpdatedAt` → `DateTimeOffset`
- [ ] Check `OrderDto`, `TransactionDto`, `HoldingDto`, `InvestorDto`, `PartyDto`, `FundDto`, `FundClassDto`, `ProductDto`, `UserDto`, etc.
- [ ] Update AutoMapper `MappingProfile`s if any explicit `DateTime`→`DateTimeOffset` projections needed (usually auto-mapped)

### Phase 7 — Presentation

- [ ] `ApiResponse.Timestamp`: `DateTime.UtcNow` → `DateTimeOffset.UtcNow`; update property type if explicitly typed
- [ ] Check any request model binders or `[FromQuery]` `DateTime` parameters in endpoints → `DateTimeOffset`

### Phase 8 — EF Migrations (one per module)

Each migration performs: `ALTER COLUMN [CreatedAt] datetimeoffset(7) NOT NULL` (and `UpdatedAt`, plus any module-specific columns).

- [ ] Auth migration: `AlterAuditColumnsToDateTimeOffset` — `IfxDbContext`
- [ ] CRM migration: `AlterAuditColumnsToDateTimeOffset` — `CrmDbContext`
- [ ] Registry migration: `AlterAuditColumnsToDateTimeOffset` — `RegistryDbContext`
- [ ] Holdings migration: `AlterAuditColumnsToDateTimeOffset` — `HoldingsDbContext`
- [ ] Transaction migration: `AlterAuditColumnsToDateTimeOffset` — `TransactionDbContext`; also `ProcessedAt`

### Phase 9 — Tests

- [ ] Run full test suite: `dotnet test IFX.sln` — expect zero failures
- [ ] Fix any unit tests that construct `DateTime` literals for `CreatedAt`/`UpdatedAt` comparisons (change to `DateTimeOffset`)
- [ ] Verify frontend tests unaffected (they compare ISO 8601 strings, not raw types)

---

## Testing Plan

**Unit tests:**
- `EmailVerificationToken.IsValid()` — test with `DateTimeOffset` expiry past and future
- Auth domain entity construction: verify `CreatedAt`/`UpdatedAt` are `DateTimeOffset`
- Handler tests: no changes expected — mock mappers return DTOs directly

**Integration tests:**
- All 5 DbContext `SaveChangesAsync` paths: insert a record, read it back, verify `CreatedAt` has a non-zero offset (`+00:00`)
- Auth flow smoke test: register → confirm → login — audit timestamps round-trip correctly

**Manual / Swagger:**
- `GET /api/v1/party` — `createdAt` field in response shows `"2026-04-18T12:00:00+00:00"` not `"2026-04-18T12:00:00"`
- `GET /api/v1/transaction` — same
- Confirm no 500 errors on any list endpoint

---

## EF Migration Notes

SQL Server supports `CONVERT(datetimeoffset, [CreatedAt])` for in-place column alteration. EF scaffolds this automatically as:

```csharp
migrationBuilder.AlterColumn<DateTimeOffset>(
    name: "CreatedAt",
    table: "Users",
    schema: "auth",
    type: "datetimeoffset(7)",
    nullable: false,
    oldClrType: typeof(DateTime),
    oldType: "datetime2");
```

Existing UTC data is preserved: SQL Server implicitly appends `+00:00` when casting `datetime2` → `datetimeoffset`.

---

## Open Questions

1. **Auth `IAuditableEntity` duplicate** — Auth module has its own copy in `Auth.Domain/Common/`. After this migration, consider consolidating to the BuildingBlocks version (separate refactor task).
2. **`DateTimeOffset` JSON serialization** — System.Text.Json serializes `DateTimeOffset` as `"2026-04-18T12:00:00+00:00"` by default. Confirm frontend and API consumers can handle the `+00:00` suffix (they should — it is valid ISO 8601 and more correct than bare `DateTime`).
3. **Seed data** — EF seed rows that use `new DateTime(...)` for `CreatedAt`/`UpdatedAt` need to become `new DateTimeOffset(...)`. Verify all `HasData()` calls in migration seeds.

---

## Status History

| Date | Status | Notes |
|------|--------|-------|
| 2026-04-18 | Plan | Plan created — follows DateTimeOffset analysis across 5 modules, ~94 DateTime properties, ~50 UtcNow usages |
| 2026-04-20 | Implementing | All phases complete: interfaces, domain entities, DTOs, DbContexts, ApiResponse, ExceptionHandlingMiddleware, 5 EF migrations. Clean build + 793 tests passing |
