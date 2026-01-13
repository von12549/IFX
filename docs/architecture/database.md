# Database Schema

Schema: `auth`

## Core Tables

### Users
Core user identity (aggregate root).

| Column | Type | Description |
|--------|------|-------------|
| Id | GUID | Primary key |
| UserRoleId | GUID | FK to UserRoles |
| DisplayName | string | User display name |
| IsActive | bool | Account status |
| CreatedAt | datetime | Creation timestamp |
| UpdatedAt | datetime | Last update |

### UserIdentities
IdP-specific user attributes. One user can have multiple identities.

| Column | Type | Description |
|--------|------|-------------|
| Id | GUID | Primary key |
| UserId | GUID | FK to Users (CASCADE) |
| IdpId | GUID | FK to Idps |
| Issuer | string | IdP issuer URL |
| Subject | string | IdP-assigned subject |
| Email | string | User email |
| EmailVerified | bool | Email verification status |
| FirstName | string | First name |
| LastName | string | Last name |
| BirthDate | date | Birth date |
| PhoneNumber | string | Phone number |
| PhoneNumberVerified | bool | Phone verification |
| LastSyncedAt | datetime | Last sync from IdP |

**Unique Constraint**: `(Issuer, Subject)`

### UserRoles
Role definitions.

| Column | Type | Description |
|--------|------|-------------|
| Id | GUID | Primary key |
| RoleName | string | Role name (unique) |
| Description | string | Role description |

**Seeded Roles**: Admin, User, SsoUser

### Idps
Identity Provider configurations.

| Column | Type | Description |
|--------|------|-------------|
| Id | GUID | Primary key |
| Name | string | Provider name |
| Issuer | string | Issuer URL (unique) |
| Authority | string | Authority URL |
| Enabled | bool | Provider status |
| AutoProvisionEnabled | bool | Auto-create users |

## Audit Tables

### LoginEvents
All login attempts with tokens and device info.

### LogoutEvents
Logout events with session duration.

### RegistrationFlowEvents
Registration lifecycle tracking.

### UserActivityLogs
General activity tracking.

## Migrations

```bash
cd src/Modules/Auth/AuthSamples.Modules.Auth.Infrastructure

# Create migration
dotnet ef migrations add MigrationName --startup-project ../../../ApiHost/AuthSamples.ApiHost

# Apply migrations
dotnet ef database update --startup-project ../../../ApiHost/AuthSamples.ApiHost
```
