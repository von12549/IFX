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

## Email Verification

### EmailVerificationTokens
Tracks email verification tokens for SSO users.

| Column | Type | Description |
|--------|------|-------------|
| Id | GUID | Primary key |
| UserIdentityId | GUID | FK to UserIdentities |
| Email | string | Email being verified |
| TokenHash | string | SHA256 hash of token |
| Code | string | 6-digit verification code |
| ExpiresAt | datetime | Token expiration |
| IsUsed | bool | Whether token was used |
| UsedAt | datetime | When token was used |
| CreatedAt | datetime | Creation timestamp |
| UpdatedAt | datetime | Last update |

## Audit Tables

### LoginEvents
All login attempts with tokens and device info.

| Column | Type | Description |
|--------|------|-------------|
| Id | GUID | Primary key |
| UserIdentityId | GUID | FK to UserIdentities |
| Success | bool | Login success status |
| IpAddress | string | Client IP address |
| UserAgent | string | Browser/client info |
| DeviceInfo | string | Parsed device details |
| FailureReason | string | Reason if failed |
| CreatedAt | datetime | Event timestamp |

### LogoutEvents
Logout events with session duration.

| Column | Type | Description |
|--------|------|-------------|
| Id | GUID | Primary key |
| UserIdentityId | GUID | FK to UserIdentities |
| SessionDurationSeconds | long | Time since login |
| LogoutType | string | User/Admin/System |
| CreatedAt | datetime | Event timestamp |

### RegistrationFlowEvents
Registration lifecycle tracking.

### UserActivityLogs
General activity tracking.

| Column | Type | Description |
|--------|------|-------------|
| Id | GUID | Primary key |
| UserIdentityId | GUID | FK to UserIdentities |
| ActivityType | string | Action type |
| Description | string | Activity description |
| IpAddress | string | Client IP address |
| CreatedAt | datetime | Event timestamp |

## Migrations

```bash
cd src/Modules/Auth/IFX.Modules.Auth.Infrastructure

# Create migration
dotnet ef migrations add MigrationName --startup-project ../../../ApiHost/IFX.ApiHost

# Apply migrations
dotnet ef database update --startup-project ../../../ApiHost/IFX.ApiHost
```
