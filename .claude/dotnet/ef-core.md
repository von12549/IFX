# Entity Framework Core

## Purpose
Database schema, migrations, and EF Core patterns for this project.

---

## Database Schema

**Schema name:** `auth`

### Tables

| Table | Purpose | Key Relationships |
|-------|---------|-------------------|
| Users | Core identity (aggregate root) | → UserRoles (FK) |
| UserIdentities | IdP-specific data | → Users (FK), → Idps (FK) |
| UserRoles | Role reference data | ← Users |
| Idps | Identity Provider config | ← UserIdentities |
| LoginEvents | Login audit trail | → Users (FK) |
| LogoutEvents | Logout audit trail | → Users (FK) |
| RegistrationFlowEvents | Registration lifecycle | → Users (FK) |
| UserActivityLogs | General activity log | → Users (FK) |

### Key Constraints

- **UserIdentities**: Unique on `(Issuer, Subject)` - ensures IdP identity uniqueness
- **UserRoles**: Unique on `RoleName`
- **Idps**: Unique on `Issuer`

---

## Migration Commands

**IMPORTANT:** Always run from Infrastructure directory with startup project flag.

```bash
cd src/Modules/Auth/AuthSamples.Modules.Auth.Infrastructure

# Create migration
dotnet ef migrations add MigrationName --startup-project ../../../ApiHost/AuthSamples.ApiHost

# Apply migrations
dotnet ef database update --startup-project ../../../ApiHost/AuthSamples.ApiHost

# Remove last migration (if not applied)
dotnet ef migrations remove --startup-project ../../../ApiHost/AuthSamples.ApiHost
```

**Rule:** Always include `--startup-project` flag - DbContext is in Infrastructure but config is in ApiHost.

---

## Seed Reference Data

When adding reference data that must exist before app runs:

```csharp
// In migration Up() method
var roleId = Guid.NewGuid();
var now = DateTime.UtcNow;

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
- `IAuditableEntity` interface
- `SaveChangesAsync` sets `CreatedAt`/`UpdatedAt` automatically

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
