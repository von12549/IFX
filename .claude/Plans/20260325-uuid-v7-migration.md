# UUID v7 Migration Plan

**Date:** 2026-03-25
**Branch:** `feature/uuid-v7`
**Status:** Implemented — PR #15

## Problem

`BaseEntity.Id` is initialized with `Guid.NewGuid()` (UUID v4 — fully random). Because the primary key is also the clustered index key in SQL Server, every insert causes a random index insertion point, leading to page splits and index fragmentation over time. Performance degrades as tables grow.

## Solution

Replace `Guid.NewGuid()` with UUID v7 (`Uuid.NewSequential()` via the `UUIDNext` NuGet package). UUID v7 embeds a millisecond-precision Unix timestamp in the high 48 bits, so new IDs are always greater than older ones — inserts always append to the end of the B-tree, eliminating page splits.

Side benefit: `ORDER BY Id` yields insertion order, equivalent to `ORDER BY CreatedAt`.

## Scope

### Change required (1 file, 1 line)

| File | Location | Change |
|------|----------|--------|
| `src/Modules/Auth/IFX.Modules.Auth.Domain/Common/BaseEntity.cs` | Line 5 | `Guid.NewGuid()` → `Uuid.NewSequential()` |

### Explicitly out of scope

| File | Reason |
|------|--------|
| `src/Modules/Auth/IFX.Modules.Auth.Infrastructure/Services/EmailVerificationService.cs` | Uses `Guid.NewGuid().ToString("N")` as an opaque string token — not a PK, not stored in a clustered index. Random is fine and intentional here. |
| All test files | Test data uses `Guid.NewGuid()` for random IDs — intentional. No test changes needed. |
| Seed / migration files | Fixed GUIDs are hard-coded strings, not generated via `Guid.NewGuid()`. No change. |

## Implementation Steps

### 1. Create branch
```bash
git checkout -b feature/uuid-v7
```

### 2. Add NuGet package to Domain project

`UUIDNext` is a .NET 8-compatible UUID v7 library (MIT licensed). It must be added to the **Domain** project because `BaseEntity` lives there. Domain has no external dependencies today — this is the only exception, and it is a thin utility with no framework coupling.

```bash
cd src/Modules/Auth/IFX.Modules.Auth.Domain
dotnet add package UUIDNext
```

This adds to `IFX.Modules.Auth.Domain.csproj`:
```xml
<PackageReference Include="UUIDNext" Version="x.x.x" />
```

### 3. Update BaseEntity.cs

```csharp
// Before
using System;

public Guid Id { get; protected set; } = Guid.NewGuid();

// After
using UUIDNext;

public Guid Id { get; protected set; } = Uuid.NewSequential();
```

Full diff is a 1-line change in the property initializer plus adding the `using UUIDNext;` directive.

### 4. Build and test
```bash
dotnet build IFX.sln
dotnet test IFX.sln
```

All 507 tests should pass without modification. Tests use `Guid.NewGuid()` for random test IDs — those do not go through `BaseEntity` and are unaffected.

### 5. No EF migration needed

The column type remains `uniqueidentifier`. UUID v7 values are valid GUIDs — SQL Server cannot and does not distinguish v4 from v7. Existing rows keep their v4 GUIDs; new inserts get v7 GUIDs. No schema change, no migration.

### 6. Commit and PR
```bash
git add .
git commit -m "feat: use UUID v7 for sequential, index-friendly primary keys"
git push -u origin feature/uuid-v7
# open PR → main
```

## Database Impact

| Concern | Impact |
|---------|--------|
| Existing rows | None — v4 GUIDs stay as-is |
| New inserts | Always greater than existing v7 GUIDs created after cutover, eliminating page splits |
| Mixed v4/v7 rows | Harmless. v4 rows will sit at various positions; only new inserts benefit from sequentiality. Over time (as old rows are deleted or tables grow) the benefit increases. |
| Index rebuild | Optional: run `ALTER INDEX ALL ON <table> REBUILD` on large tables after cutover to reclaim fragmentation from existing v4 rows. Not required for correctness. |

## Rollback

Revert the one-line change in `BaseEntity.cs` and remove the NuGet reference. No DB migration to roll back — GUID column type unchanged.

## Future: .NET 10 Upgrade Path

**Do NOT upgrade to .NET 9.** It is Short-Term Support (STS) and reaches end-of-life May 2026 — almost immediately. Upgrading now would land the project on an unsupported runtime within weeks.

Recommended upgrade path: **.NET 8 LTS → .NET 10 LTS** (expected November 2026).

When the project upgrades to .NET 10, `Guid.CreateVersion7()` is available natively. At that point, replace `UUIDNext` with the built-in runtime method and drop the package:

```csharp
// .NET 10+: drop UUIDNext, use built-in
public Guid Id { get; protected set; } = Guid.CreateVersion7();
```

Remove `<PackageReference Include="UUIDNext" ... />` from the `.csproj`.

## Files to Touch

```
src/Modules/Auth/IFX.Modules.Auth.Domain/
  IFX.Modules.Auth.Domain.csproj          ← add UUIDNext reference
  Common/BaseEntity.cs                    ← Guid.NewGuid() → Uuid.NewSequential()
```

That is the complete change.
