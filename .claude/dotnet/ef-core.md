# Entity Framework Core

## Purpose
Database schema, migrations, and EF Core patterns for this project.

---

## Database Schema

**Schema name:** `auth`

### Tables

| Table | Purpose | Key Relationships |
|-------|---------|-------------------|
| Tenants | Tenant entity (top-level org unit) | ← Roles, RoleGroups, Idps, Departments |
| Departments | Department within a tenant | → Tenants (FK) |
| Users | Core identity (aggregate root) | → Tenants (many-to-many), → PrimaryTenant (FK) |
| UserIdentities | IdP-specific data | → Users (FK), → Idps (FK) |
| Roles | Role scoped to a tenant | → Tenants (FK) |
| RoleGroups | Group of roles scoped to a tenant | → Tenants (FK) |
| RoleGroupRoles | Many-to-many: RoleGroup ↔ Role | join table |
| Permissions | System-wide permissions | ← Roles (many-to-many via RolePermissions) |
| Idps | Identity Provider config | → Tenants (FK), ← UserIdentities |
| LoginEvents | Login audit trail | → Users (FK) |
| LogoutEvents | Logout audit trail | → Users (FK) |
| RegistrationFlowEvents | Registration lifecycle | → Users (FK) |
| UserActivityLogs | General activity log | → Users (FK) |

### Idps Table Columns

| Column | Type | Description |
|--------|------|-------------|
| Id | uniqueidentifier | Primary key |
| Name | nvarchar(100) | Display name |
| Issuer | nvarchar(500) | OIDC issuer URL (unique) |
| Authority | nvarchar(500) | OIDC authority URL |
| IdpType | nvarchar(20) | `Internal` or `External` |
| IsPrimary | bit | Primary IdP for local auth (unique filtered index) |
| Enabled | bit | Whether IdP accepts tokens |
| AutoProvisionEnabled | bit | Auto-create users on first login |
| ExpectedAudiences | nvarchar(2000) | JSON array of valid audiences |
| AllowedAlgs | nvarchar(500) | JSON array of allowed algorithms |
| ClockSkewSeconds | int | Token expiry tolerance (default: 300) |

**IdpType Role Assignment:**
- `Internal` → Auto-provisioned users get `User` role
- `External` → Auto-provisioned users get `SsoUser` role

### Key Constraints

- **UserIdentities**: Unique on `(Issuer, Subject)` - ensures IdP identity uniqueness
- **Roles**: Unique on `(TenantId, Name)` - same name allowed in different tenants
- **RoleGroups**: Unique on `(TenantId, Name)`
- **Idps**: Unique on `Issuer`
- **Idps**: Unique filtered index on `IsPrimary` where `IsPrimary = 1` (only one primary)

### Tenant Filtering Rule

All list queries (Roles, RoleGroups, Idps, Users, Departments) require a `TenantId`. Passing `null` returns an empty result — this is intentional. The handler short-circuits before hitting the database:

```csharp
if (!request.TenantId.HasValue)
    return Result<List<RoleDto>>.Success([]);
```

---

## Migration Commands

**IMPORTANT:** Always run from Infrastructure directory with startup project flag. Always pass `--context` when multiple DbContexts exist in the solution.

```bash
# Auth module
dotnet ef migrations add MigrationName --context IfxDbContext \
  --project src/Modules/Auth/IFX.Modules.Auth.Infrastructure \
  --startup-project src/ApiHost/IFX.ApiHost

# CRM module
dotnet ef migrations add MigrationName --context CrmDbContext \
  --project src/Modules/CRM/IFX.Modules.CRM.Infrastructure \
  --startup-project src/ApiHost/IFX.ApiHost

# Registry module
dotnet ef migrations add MigrationName --context RegistryDbContext \
  --project src/Modules/Registry/IFX.Modules.Registry.Infrastructure \
  --startup-project src/ApiHost/IFX.ApiHost

# Holdings module
dotnet ef migrations add MigrationName --context HoldingsDbContext \
  --project src/Modules/Holdings/IFX.Modules.Holdings.Infrastructure \
  --startup-project src/ApiHost/IFX.ApiHost

# Transaction module
dotnet ef migrations add MigrationName --context TransactionDbContext \
  --project src/Modules/Transaction/IFX.Modules.Transaction.Infrastructure \
  --startup-project src/ApiHost/IFX.ApiHost
```

**Rule:** Always include `--startup-project` flag — DbContext is in Infrastructure but config is in ApiHost.

**Rule:** Always include `--context` — the solution has 5 DbContexts (IfxDbContext, CrmDbContext, RegistryDbContext, HoldingsDbContext, TransactionDbContext). Omitting it causes ambiguity errors.

---

## Seed Reference Data

When adding reference data that must exist before app runs:

```csharp
// In migration Up() method
var roleId = Guid.NewGuid();
var now = new DateTimeOffset(2026, 1, 1, 0, 0, 0, TimeSpan.Zero); // fixed seed date

migrationBuilder.InsertData(
    schema: "auth",
    table: "UserRoles",
    columns: new[] { "Id", "RoleName", "Description", "CreatedAt", "UpdatedAt" },
    values: new object[] { roleId, "Admin", "Administrator role", now, now });

// In Down() method
migrationBuilder.DeleteData(
    schema: "auth",
    table: "UserRoles",
    keyColumn: "RoleName",
    keyValue: "Admin");
```

---

## Patterns

### Repository Pattern
- Interfaces in Domain: `IUserRepository`
- Implementations in Infrastructure: `UserRepository`
- Registered via DI in Composition layer

### Unit of Work
- `IUnitOfWork` coordinates transactions
- `SaveChangesAsync()` commits all changes atomically

### Value Object Conversions
- Subject ↔ string
- EmailAddress ↔ string
- Configured in entity configurations

### Owned Entities
- DeviceInfo owned by LoginEvent (stored in same table)

### Auto-timestamps
- `IAuditableEntity` interface defines `DateTimeOffset CreatedAt` and `DateTimeOffset UpdatedAt`
- `SaveChangesAsync` in all 5 DbContexts sets these via `DateTimeOffset.UtcNow` automatically
- SQL Server column type: `datetimeoffset(7)` (EF default mapping for `DateTimeOffset`)
- **Rule:** Never use `DateTime` for any timestamp field — always `DateTimeOffset`

---

## Query Patterns

```csharp
// Read-only queries - use AsNoTracking()
var users = await _context.Users
    .AsNoTracking()
    .Include(u => u.Identities)
    .ToListAsync();

// Primary lookup - by Issuer + Subject
var user = await _context.Users
    .Include(u => u.Identities)
    .Include(u => u.UserRole)
    .FirstOrDefaultAsync(u =>
        u.Identities.Any(i => i.Issuer == issuer && i.Subject == subject));

// Email lookup - scoped to IdP
var user = await _context.Users
    .Include(u => u.Identities)
    .FirstOrDefaultAsync(u =>
        u.Identities.Any(i => i.Email == email && i.IdpId == idpId));
```
