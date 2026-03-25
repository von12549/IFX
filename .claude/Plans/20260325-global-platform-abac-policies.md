# Plan: Global / Platform-Level ABAC Policies

**Date:** 2026-03-25
**Status:** Implemented (2026-03-25)
**Depends on:** `20260325-seed-user-policies-ifx-tenant.md` (implemented)

---

## Goal

Add a platform-level policy tier so that one DB row covers all tenants that have no
tenant-specific override. Once implemented, the static fallback in
`DependencyInjection.cs` can be removed, and `UserPolicies.cs` deleted entirely.

### New resolution order

```
Request for (tenantId, "user", "read")
  1. Tenant DB row   — auth.PolicyDefinitions WHERE TenantId = @tenantId AND ...
  2. Platform DB row — auth.PolicyDefinitions WHERE TenantId IS NULL AND ...
  3. Static fallback — StaticAbacPolicyResolver (removed in final step)
  4. null            — deny (ForbiddenException)
```

---

## Design Decisions

### TenantId nullable on PolicyDefinition
`PolicyDefinition.TenantId` changes from `Guid` to `Guid?`.
`null` = platform/global row; a non-null value must still not be `Guid.Empty`.

### Unique index behaviour
SQL Server treats NULLs as equal in unique indexes — `(NULL, 'user', 'read')` can only
appear once. The existing index `UX_PolicyDefinitions_Tenant_Resource_Action` already
enforces this correctly. **No index changes are needed.**

### Cache keys
| Scope | Key |
|-------|-----|
| Tenant row | `abac:{tenantId}:{resource}:{action}` (unchanged) |
| Platform row | `abac:platform:{resource}:{action}` (new) |

### Authorization
Platform policy endpoints require a new `Platform.Policy.Read` / `Platform.Policy.Write`
permission pair. These are NOT tenant-scoped — there is no `X-Tenant-Id` header on
platform admin calls.

---

## Tasks

### 1. Domain — make TenantId nullable

File: `src/Modules/Auth/IFX.Modules.Auth.Domain/Authorization/PolicyDefinition.cs`

- Change `public Guid TenantId { get; private set; }` → `public Guid? TenantId { get; private set; }`
- Update `Create` factory: accept `Guid? tenantId`; guard becomes
  `if (tenantId.HasValue && tenantId.Value == Guid.Empty) throw ...`
  (null is allowed — it means platform scope)

---

### 2. Domain — extend IPolicyDefinitionRepository

File: `src/Modules/Auth/IFX.Modules.Auth.Domain/Authorization/IPolicyDefinitionRepository.cs`

Add:
```csharp
Task<PolicyDefinition?> GetPlatformAsync(string resourceType, string action, CancellationToken ct = default);
Task<List<PolicyDefinition>> GetPlatformPoliciesAsync(CancellationToken ct = default);
Task<bool> ExistsPlatformAsync(string resourceType, string action, CancellationToken ct = default);
```

---

### 3. Domain — extend IAbacPolicyCache

File: `src/BuildingBlocks/IFX.BuildingBlocks.Security/Authorization/Abac/Resolver/IAbacPolicyCache.cs`

Add:
```csharp
void InvalidatePlatform(string resourceType, string action);
```

---

### 4. Infrastructure — EF config

File: `src/Modules/Auth/IFX.Modules.Auth.Infrastructure/Authorization/Configurations/PolicyDefinitionConfiguration.cs`

```csharp
builder.Property(p => p.TenantId);  // nullable — remove .IsRequired()
```

---

### 5. Infrastructure — implement new repository methods

File: `src/Modules/Auth/IFX.Modules.Auth.Infrastructure/Authorization/Repositories/PolicyDefinitionRepository.cs`

```csharp
public Task<PolicyDefinition?> GetPlatformAsync(string resourceType, string action, CancellationToken ct)
    => _db.PolicyDefinitions
          .Where(p => p.TenantId == null
                   && p.ResourceType == resourceType.ToLowerInvariant()
                   && p.Action == action.ToLowerInvariant()
                   && p.IsActive)
          .FirstOrDefaultAsync(ct);

public Task<List<PolicyDefinition>> GetPlatformPoliciesAsync(CancellationToken ct)
    => _db.PolicyDefinitions
          .Where(p => p.TenantId == null && p.IsActive)
          .ToListAsync(ct);

public Task<bool> ExistsPlatformAsync(string resourceType, string action, CancellationToken ct)
    => _db.PolicyDefinitions
          .AnyAsync(p => p.TenantId == null
                      && p.ResourceType == resourceType.ToLowerInvariant()
                      && p.Action == action.ToLowerInvariant(), ct);
```

---

### 6. Infrastructure — update DbAbacPolicyResolver

File: `src/Modules/Auth/IFX.Modules.Auth.Infrastructure/Authorization/DbAbacPolicyResolver.cs`

New `ResolveAsync` algorithm:
```
if tenantId provided:
  key = "abac:{tenantId}:{resource}:{action}"
  cache hit? → return
  DB hit (tenant row)? → deserialize, cache, return

// fall through to platform level
platformKey = "abac:platform:{resource}:{action}"
cache hit? → return
DB hit (platform row)? → deserialize, cache, return

// final fallback
return await _staticResolver.ResolveAsync(...)
```

Add `InvalidatePlatform`:
```csharp
public void InvalidatePlatform(string resourceType, string action)
{
    var key = $"abac:platform:{resourceType.ToLowerInvariant()}:{action.ToLowerInvariant()}";
    _cache.Remove(key);
}
```

---

### 7. Application — update CreatePolicyCommand + validator

File: `src/Modules/Auth/IFX.Modules.Auth.Application/Authorization/Policies/Commands/CreatePolicy/`

- `CreatePolicyCommand.TenantId` → `Guid?`
- `CreatePolicyCommandValidator`: remove `NotEmpty()` on TenantId; add
  `.Must(id => id == null || id != Guid.Empty).WithMessage("TenantId must not be empty Guid.")`
- Handler: call `ExistsPlatformAsync` when `TenantId` is null; call `ExistsAsync` otherwise

---

### 8. Application — add GetPlatformPoliciesQuery

New files under `src/.../Authorization/Policies/Queries/GetPlatformPolicies/`:
- `GetPlatformPoliciesQuery` — `record GetPlatformPoliciesQuery : IRequest<Result<List<PolicyDefinitionDto>>>`
- `GetPlatformPoliciesQueryHandler` — queries `_unitOfWork.PolicyDefinitions.GetPlatformPoliciesAsync()`
  and maps rows with `IsPlatformDefault = true`

---

### 9. Application — update DeletePolicyCommandHandler to invalidate platform cache

File: `src/.../Commands/DeletePolicy/DeletePolicyCommandHandler.cs`

When the deleted policy has `TenantId == null`, call `_policyCache.InvalidatePlatform(...)` instead of `_policyCache.Invalidate(...)`.
Same for `UpdatePolicyCommandHandler`.

---

### 10. Presentation — new Platform Policy endpoint group

New files under `src/Modules/Auth/IFX.Modules.Auth.Presentation/Authorization/Endpoints/`:
- `PlatformPolicyEndpoints.cs` — 4 methods: `GetPlatformPolicies`, `CreatePlatformPolicy`, `UpdatePlatformPolicy`, `DeletePlatformPolicy`
- `PlatformPolicyEndpointExtensions.cs` — maps `/api/v1/platform/policy`; requires `Platform.Policy.Read` / `Platform.Policy.Write`

`CreatePlatformPolicy` sends `CreatePolicyCommand(TenantId: null, ...)` — no `X-Tenant-Id` header.

---

### 11. Migrations

Two migrations in order:

**`MakePolicyTenantIdNullable`**
```sql
-- Up
ALTER TABLE auth.PolicyDefinitions ALTER COLUMN TenantId UNIQUEIDENTIFIER NULL

-- Down
-- (requires all NULL rows removed first)
ALTER TABLE auth.PolicyDefinitions ALTER COLUMN TenantId UNIQUEIDENTIFIER NOT NULL
```

**`SeedPlatformUserReadPolicy`**
```sql
-- Up
DECLARE @UserId UNIQUEIDENTIFIER = (
    SELECT TOP 1 Id FROM auth.Users WHERE DisplayName = 'Xiaolong Feng')
DECLARE @PolicyId UNIQUEIDENTIFIER = NEWID()
DECLARE @Now DATETIME2 = GETUTCDATE()

IF @UserId IS NOT NULL
   AND NOT EXISTS (
       SELECT 1 FROM auth.PolicyDefinitions
       WHERE TenantId IS NULL AND ResourceType = 'user' AND Action = 'read')
BEGIN
    INSERT INTO auth.PolicyDefinitions
        (Id, TenantId, Name, Description, ResourceType, Action,
         ConditionsJson, IsActive, CreatedById, UpdatedById, CreatedAt, UpdatedAt)
    VALUES (
        @PolicyId, NULL,
        'Read Own Profile (Platform Default)',
        'Platform-wide default: allows any user to read their own profile within the same tenant.',
        'user', 'read',
        '[{"TemplateName":"SameTenant","Parameters":null},{"TemplateName":"CreatedByMe","Parameters":null}]',
        1, @UserId, @UserId, @Now, @Now)
END

-- Down
DELETE FROM auth.PolicyDefinitions WHERE TenantId IS NULL AND ResourceType = 'user' AND Action = 'read'
```

---

### 12. Remove static fallback + delete UserPolicies.cs

Once both migrations above are applied and verified in production:

**`DependencyInjection.cs`** — remove the `RegisterDefault(...)` block:
```csharp
// DELETE these lines:
services.AddSingleton<StaticAbacPolicyResolver>(sp =>
{
    var resolver = new StaticAbacPolicyResolver();
    resolver.RegisterDefault("user", "read", UserPolicies.ReadOwnProfile);
    return resolver;
});
```
Replace with:
```csharp
services.AddSingleton<StaticAbacPolicyResolver>();
```

**`UserPolicies.cs`** — 0 references remain → delete the file.

---

### 13. Tests

- `DbAbacPolicyResolverTests` — add cases:
  - Tenant row absent → falls through to platform DB row
  - Platform row absent → falls through to static
  - Both absent → returns null
  - `InvalidatePlatform` causes re-fetch on next platform resolve

- `CreatePolicyCommandHandlerTests` — add case: `TenantId = null` creates platform policy

- `GetPlatformPoliciesQueryHandlerTests` — returns only `TenantId == null` rows with `IsPlatformDefault = true`

- `DeletePolicyCommandHandlerTests` — platform row deletion calls `InvalidatePlatform`

---

## Acceptance Criteria

- [ ] `PolicyDefinition.TenantId` is `Guid?`; platform rows have `TenantId = null`
- [ ] Resolution order: tenant DB → platform DB → static → null
- [ ] Platform cache key `abac:platform:{resource}:{action}` is independent of tenant cache
- [ ] `/api/v1/platform/policy` endpoints exist, require `Platform.Policy.Write/Read`
- [ ] Migration `SeedPlatformUserReadPolicy` seeds `user/read` platform row (Xiaolong Feng as author)
- [ ] After migrations, static fallback removed from `DependencyInjection.cs`
- [ ] `UserPolicies.cs` deleted (0 references)
- [ ] All existing tests pass; new resolver and handler tests added
