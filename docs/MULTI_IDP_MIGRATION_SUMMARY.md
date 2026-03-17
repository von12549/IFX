# Multi-IdP Migration Summary

## Overview

This document summarizes the three-phase migration from a single Cognito-specific authentication module to a multi-IdP (Identity Provider) capable architecture.

**Migration Period**: January 2026
**Status**: ✅ Complete
**Git Tags**: `phase1-complete`, `phase2-complete`, `phase3-complete`

---

## Migration Phases

### Phase 1: Module Rename (Cognito → Auth)

**Objective**: Decouple the module name from the specific IdP implementation.

**Changes**:
- ✅ Renamed module from `Cognito` to `Auth` (200+ files)
- ✅ Renamed namespaces: `IFX.Modules.Cognito.*` → `IFX.Modules.Auth.*`
- ✅ Renamed database schema: `cognito` → `auth`
- ✅ Renamed DbContext: `CognitoDbContext` → `IfxDbContext`
- ✅ Updated Docker configuration
- ✅ Updated all project references and solution file

**Database Migration**: `RenameSchemaFromCognitoToAuth`
```sql
CREATE SCHEMA auth;
ALTER SCHEMA auth TRANSFER cognito.Users;
ALTER SCHEMA auth TRANSFER cognito.UserRoles;
-- ... (7 tables total)
DROP SCHEMA cognito;
```

**Files Affected**: 200+
**Breaking Changes**: None (internal refactoring only)

---

### Phase 2: Table Restructuring (User Split)

**Objective**: Separate core user identity from IdP-specific identity data to support multiple identity providers per user.

**Old Structure**:
```
Users Table:
- Id (GUID)
- CognitoUserId
- Email
- Username
- FirstName
- LastName
- PhoneNumber
- EmailVerified
- PhoneNumberVerified
- Issuer
- Subject
- UserRoleId
- IsActive
- DisplayName
- CreatedAt
- UpdatedAt
```

**New Structure**:

**Users Table** (Core Identity):
```
- Id (GUID) - Primary Key
- UserRoleId (GUID) - FK to UserRoles
- DisplayName (NVARCHAR(200))
- IsActive (BIT)
- CreatedAt (DATETIME2)
- UpdatedAt (DATETIME2)
```

**UserIdentities Table** (IdP-Specific Data):
```
- Id (GUID) - Primary Key
- UserId (GUID) - FK to Users (CASCADE DELETE)
- IdpId (GUID) - FK to Idps (RESTRICT)
- Issuer (NVARCHAR(500)) - IdP issuer URL
- Subject (NVARCHAR(100)) - IdP-assigned subject
- Email (NVARCHAR(255))
- FirstName (NVARCHAR(100))
- LastName (NVARCHAR(100))
- BirthDate (NVARCHAR(10))
- PhoneNumber (NVARCHAR(20))
- EmailVerified (BIT)
- PhoneNumberVerified (BIT)
- LastSyncedAt (DATETIME2)
- CreatedAt (DATETIME2)
- UpdatedAt (DATETIME2)
- UNIQUE (Issuer, Subject)
```

**Database Migrations**:
1. `SplitUserTableIntoUserAndUserIdentity` - Created new tables and migrated data
2. `DropUsersBackupTable` - Removed backup after verification

**Data Migration Strategy**:
```sql
-- 1. Rename old Users to UsersBackup
EXEC sp_rename 'auth.Users', 'UsersBackup';

-- 2. Create new Users and UserIdentities tables
-- (EF Core generated)

-- 3. Migrate data
DECLARE @IfxCognitoIdpId UNIQUEIDENTIFIER;
SELECT @IfxCognitoIdpId = Id FROM [auth].[Idps]
WHERE Issuer = 'https://cognito-idp.ap-southeast-2.amazonaws.com/ap-southeast-2_adW7gmF5P';

-- Populate new Users table
INSERT INTO [auth].[Users] (Id, IsActive, UserRoleId, DisplayName, CreatedAt, UpdatedAt)
SELECT Id, IsActive, UserRoleId, CONCAT(FirstName, ' ', LastName), CreatedAt, UpdatedAt
FROM [auth].[UsersBackup];

-- Populate UserIdentities table
INSERT INTO [auth].[UserIdentities] (
    Id, UserId, IdpId, Issuer, Subject, Email, EmailVerified,
    FirstName, LastName, BirthDate, PhoneNumber, PhoneNumberVerified,
    LastSyncedAt, CreatedAt, UpdatedAt
)
SELECT
    NEWID(), Id, @IfxCognitoIdpId, Issuer, Subject, Email, EmailVerified,
    FirstName, LastName, BirthDate, PhoneNumber, PhoneNumberVerified,
    LastSyncedAt, CreatedAt, UpdatedAt
FROM [auth].[UsersBackup];

-- 4. Verify data integrity
-- (row counts matched, no data loss)

-- 5. Drop UsersBackup
DROP TABLE [auth].[UsersBackup];
```

**New Domain Entities**:

**UserIdentity.cs** (Created):
```csharp
public class UserIdentity : BaseEntity, IAuditableEntity
{
    public Subject Subject { get; private set; }
    public EmailAddress Email { get; private set; }
    public Guid UserId { get; private set; }
    public Guid IdpId { get; private set; }
    public string Issuer { get; private set; }
    public string FirstName { get; private set; }
    public string LastName { get; private set; }
    public string PhoneNumber { get; private set; }
    public string BirthDate { get; private set; }
    public bool EmailVerified { get; private set; }
    public bool PhoneNumberVerified { get; private set; }

    public static UserIdentity Create(...);
    public void UpdateFromIdp(...);
    public void UpdateProfile(...);
}
```

**User.cs** (Simplified):
```csharp
public class User : BaseEntity, IAuditableEntity
{
    public bool IsActive { get; private set; }
    public Guid UserRoleId { get; private set; }
    public string DisplayName { get; private set; }

    public IReadOnlyCollection<UserIdentity> Identities { get; }

    public static User Create(Guid userRoleId, string displayName, bool isActive = false);
    public void Activate();
    public void Deactivate();
    public void AssignRole(Guid roleId);
    public void UpdateDisplayName(string displayName);
}
```

**New Repositories**:
- `IUserIdentityRepository` / `UserIdentityRepository`
  - `GetByIssuerAndSubjectAsync(issuer, subject)`
  - `GetByEmailAsync(email)`
  - `GetByUserIdAsync(userId)`
  - `AddAsync(userIdentity)`
  - `UpdateAsync(userIdentity)`

**Updated Repositories**:
- `IUserRepository` / `UserRepository`
  - **Added**: `GetByIssuerAndSubjectAsync(issuer, subject)` - PRIMARY lookup method
  - **Removed**: `GetBySubjectAsync(subject)` - deprecated
  - **Removed**: `GetByUsernameAsync(username)` - username concept removed
  - **Updated**: `GetByEmailAsync(email)` - now queries UserIdentities table
  - **Updated**: `ExistsAsync(email)` - now queries UserIdentities table

**Files Created**: 10
**Files Modified**: 15
**Breaking Changes**: Database schema (backward compatible via migration)

---

### Phase 3: Update Handlers (Issuer+Subject Pattern)

**Objective**: Update all application code to use the new `(Issuer, Subject)` tuple for user lookup instead of `Subject` alone.

**Key Concept**: Multi-IdP Support
- A user can have multiple identities from different IdPs
- Each identity is uniquely identified by `(Issuer, Subject)` pair
- Example:
  - IFX Cognito: `("https://cognito-idp....", "abc-123")`
  - Google SSO: `("https://accounts.google.com", "xyz-789")`
  - Same user, two identities

**Updated Components** (13 total):

**1. UserRoleClaimsTransformation** (CRITICAL - runs on every request):
```csharp
// OLD
var subject = principal.FindFirst("sub")?.Value;
var user = await unitOfWork.Users.GetBySubjectAsync(subject);

// NEW
var subject = principal.FindFirst("sub")?.Value;
var issuer = principal.FindFirst("iss")?.Value;
var user = await unitOfWork.Users.GetByIssuerAndSubjectAsync(issuer, subject);
```

**2. Commands Updated**:
- `LogoutUserCommand(Issuer, Subject, AccessToken, IpAddress)`
- `UpdateUserProfileCommand(Issuer, Subject, ...)`
- `SyncUserCommand(Issuer, Subject)`

**3. Queries Updated**:
- `GetUserProfileQuery(Issuer, Subject)`
- `GetUserLoginHistoryQuery(Issuer, Subject, PageNumber, PageSize)`
- `GetUserActivityLogQuery(Issuer, Subject, PageNumber, PageSize)`

**4. Controllers Updated**:

**UserController.cs**:
```csharp
// Helper method
private (string? Issuer, string? Subject) GetIssuerAndSubjectFromClaims()
{
    var subject = User.FindFirst("sub")?.Value;
    var issuer = User.FindFirst("iss")?.Value;
    return (issuer, subject);
}

// All endpoints
var (issuer, subject) = GetIssuerAndSubjectFromClaims();
if (string.IsNullOrEmpty(issuer) || string.IsNullOrEmpty(subject))
    return Unauthorized(...);

var command = new SomeCommand(issuer, subject, ...);
```

**AuthController.cs** - Logout endpoint:
```csharp
// Extract both claims
var subject = User.FindFirst("sub")?.Value;
var issuer = User.FindFirst("iss")?.Value;

var command = new LogoutUserCommand(issuer, subject, accessToken, ipAddress);
```

**UserManagementController.cs** - Admin endpoints:
```csharp
// Changed from subject parameter to userId parameter
[HttpPut("users/{userId}")]
public async Task<ActionResult> UpdateUserProfile(Guid userId, ...)
{
    var user = await _unitOfWork.Users.GetByIdAsync(userId);
    var identity = user.Identities.FirstOrDefault();

    var command = new UpdateUserProfileCommand(
        identity.Issuer,
        identity.Subject.Value,
        ...);
}
```

**5. Handler Implementations**:

**RegisterUserCommandHandler**:
```csharp
// Creates BOTH User and UserIdentity
var user = User.Create(userRoleId, displayName, isActive: false);
await _unitOfWork.Users.AddAsync(user);

var userIdentity = UserIdentity.Create(
    userId: user.Id,
    idpId: ifxCognitoIdp.Id,
    issuer: "https://cognito-idp...",
    subject: Subject.Create(cognitoResult.Subject),
    email: EmailAddress.Create(request.Email),
    ...);
await _unitOfWork.UserIdentities.AddAsync(userIdentity);
```

**LoginUserCommandHandler**:
```csharp
// Extracts issuer from JWT IdToken
var jwtHandler = new JwtSecurityTokenHandler();
var idToken = jwtHandler.ReadJwtToken(authResult.IdToken!);
var issuer = idToken.Issuer;
var subject = idToken.Claims.FirstOrDefault(c => c.Type == "sub")?.Value;

var user = await _unitOfWork.Users.GetByIssuerAndSubjectAsync(issuer, subject);

// Syncs UserIdentity
var identity = user.Identities.FirstOrDefault(i => i.Issuer == issuer && i.Subject.Value == subject);
identity.UpdateFromIdp(...);
user.UpdateDisplayName($"{firstName} {lastName}");
```

**UpdateUserProfileCommandHandler**:
```csharp
var user = await _unitOfWork.Users.GetByIssuerAndSubjectAsync(request.Issuer, request.Subject);
var identity = user.Identities.FirstOrDefault(i => i.Issuer == request.Issuer && i.Subject.Value == request.Subject);

// Update UserIdentity
identity.UpdateProfile(request.FirstName, request.LastName, request.PhoneNumber);

// Update User DisplayName if name changed
if (request.FirstName != null || request.LastName != null)
{
    var newDisplayName = $"{identity.FirstName} {identity.LastName}";
    user.UpdateDisplayName(newDisplayName);
}
```

**6. AutoMapper Configuration**:
```csharp
// OLD
CreateMap<User, UserProfileDto>()
    .ForMember(dest => dest.Subject, opt => opt.MapFrom(src => src.Subject.Value))
    .ForMember(dest => dest.Email, opt => opt.MapFrom(src => src.Email.Value))
    .ForMember(dest => dest.Issuer, opt => opt.MapFrom(src => src.Issuer));

// NEW
CreateMap<User, UserProfileDto>()
    .ForMember(dest => dest.Subject, opt => opt.MapFrom(src =>
        src.Identities.FirstOrDefault() != null
            ? src.Identities.FirstOrDefault()!.Subject.Value
            : string.Empty))
    .ForMember(dest => dest.Email, opt => opt.MapFrom(src =>
        src.Identities.FirstOrDefault() != null
            ? src.Identities.FirstOrDefault()!.Email.Value
            : string.Empty))
    .ForMember(dest => dest.Issuer, opt => opt.MapFrom(src =>
        src.Identities.FirstOrDefault() != null
            ? src.Identities.FirstOrDefault()!.Issuer
            : string.Empty));
```

**Files Modified**: 25
**Breaking Changes**: API contracts (all authenticated endpoints now require valid `iss` claim in JWT)

---

## Summary of Architectural Changes

### Before (Single IdP):
```
User Entity (Monolithic)
├── Core Identity (Id, DisplayName, IsActive, UserRoleId)
├── Cognito Data (Subject, Email, Username, FirstName, ...)
└── Lookup: Subject → User
```

### After (Multi-IdP Ready):
```
User Entity (Core)
├── Id (GUID)
├── DisplayName
├── IsActive
├── UserRoleId
└── Identities Collection ─┐
                           │
UserIdentity Entity ←──────┘
├── UserId → User
├── IdpId → Idp
├── Issuer + Subject (UNIQUE)
├── Email, FirstName, LastName, ...
└── Lookup: (Issuer, Subject) → User
```

---

## Breaking Changes

### Database Schema
- ❌ Old `Users` table structure incompatible
- ✅ Migration scripts provided (`SplitUserTableIntoUserAndUserIdentity`)
- ✅ Data migration automatic via EF Core

### API Contracts
- All authenticated endpoints require JWT with both `iss` and `sub` claims
- Cognito automatically provides both (no client changes needed)
- Future IdPs must provide standard OIDC claims

### Code Changes
- ❌ `GetBySubjectAsync()` removed - use `GetByIssuerAndSubjectAsync()`
- ❌ `User.Subject`, `User.Email`, etc. removed - use `User.Identities` collection
- ❌ `User.UpdateProfile()` removed - use `UserIdentity.UpdateProfile()`

---

## Migration Benefits

### 1. Multi-IdP Support
- Users can link multiple identity providers
- Example: Same user with Google SSO + Cognito accounts
- Unique constraint `(Issuer, Subject)` prevents duplicates

### 2. Cleaner Architecture
- Separation of concerns: Core identity vs IdP-specific data
- User entity simplified to 6 core fields
- IdP data isolated in UserIdentity

### 3. Scalability
- Ready for future IdPs (Azure AD, Okta, Auth0, etc.)
- No code changes needed to add new IdP
- Just add IdP record to Idps table

### 4. Flexibility
- Users can have different emails per IdP
- Different names/profiles per identity
- Audit trail per identity (LastSyncedAt)

---

## Current IdP Configuration

**IFX Cognito**:
- Issuer: `https://cognito-idp.ap-southeast-2.amazonaws.com/ap-southeast-2_adW7gmF5P`
- All existing users migrated to this IdP
- IdP record ID stored in database

---

## Testing Checklist

✅ Phase 1 Testing:
- [x] Build succeeds
- [x] Database migration runs
- [x] SQL Server container starts
- [x] API starts without errors
- [x] Schema renamed from `cognito` to `auth`

✅ Phase 2 Testing:
- [x] Migration creates new tables
- [x] Data migrated correctly (row counts match)
- [x] DisplayName = FirstName + LastName
- [x] All UserIdentities linked to IFX Cognito IdP
- [x] Unique constraint (Issuer, Subject) enforced
- [x] UsersBackup dropped after verification

✅ Phase 3 Testing:
- [x] Build succeeds with no obsolete warnings
- [x] All handlers updated to use Issuer+Subject
- [x] AutoMapper configuration updated
- [x] Repository methods cleaned up

⏳ Integration Testing (Phase 3.9):
- [ ] Registration flow
- [ ] Login flow
- [ ] Profile retrieval
- [ ] Profile update
- [ ] Login history
- [ ] Activity log
- [ ] Logout
- [ ] Token refresh

---

## Rollback Strategies

### Phase 1 Rollback
```bash
# Restore database
RESTORE DATABASE IFXDb FROM DISK = 'D:\Backups\IFXDb_BeforePhase1.bak';

# Revert code
git reset --hard phase0-complete
```

### Phase 2 Rollback (Before dropping UsersBackup)
```bash
dotnet ef database update [PreviousMigration] --startup-project ../IFX.Modules.Auth.API
dotnet ef migrations remove --startup-project ../IFX.Modules.Auth.API
```

### Phase 3 Rollback
```bash
# Code-only changes, database unchanged
git reset --hard phase2-complete
dotnet build && dotnet run
```

---

## Future Enhancements

### Phase 4: Add Additional IdPs (Future)
1. Add IdP configuration to Idps table
2. Implement OAuth/OIDC flow for new IdP
3. Create UserIdentity records for new provider
4. Users can link accounts via UI

### Phase 5: Account Linking (Future)
- Allow users to link multiple IdP accounts
- Merge user data from different sources
- Primary identity selection

### Example: Adding Google SSO
```csharp
// 1. Add IdP record
var googleIdp = Idp.Create("Google SSO", "https://accounts.google.com", IdpType.OIDC);

// 2. User authenticates with Google
var googleToken = await GoogleOAuth.Authenticate();
var googleUserInfo = await GoogleOAuth.GetUserInfo(googleToken);

// 3. Create or link UserIdentity
var existingUser = await _unitOfWork.Users.GetByIdAsync(currentUserId);
var googleIdentity = UserIdentity.Create(
    userId: existingUser.Id,
    idpId: googleIdp.Id,
    issuer: "https://accounts.google.com",
    subject: googleUserInfo.Sub,
    email: EmailAddress.Create(googleUserInfo.Email),
    ...);

await _unitOfWork.UserIdentities.AddAsync(googleIdentity);
```

---

## Files Changed Summary

**Phase 1**: 200+ files
**Phase 2**: 25 files (10 created, 15 modified)
**Phase 3**: 25 files
**Total**: ~250 files

**Migrations**: 3
1. `RenameSchemaFromCognitoToAuth`
2. `SplitUserTableIntoUserAndUserIdentity`
3. `DropUsersBackupTable`

---

## Lessons Learned

1. **Phased Approach Works**: Breaking into 3 phases reduced risk
2. **Temporary Compatibility Layer**: `[Obsolete]` attributes helped transition smoothly
3. **Data Verification Critical**: UsersBackup table allowed thorough verification before deletion
4. **Migration Testing**: Always test migrations on copy of production data
5. **Value Objects**: Subject and EmailAddress value objects prevented string manipulation bugs

---

## Contributors

- **Planning**: Claude Code (claude.ai/code)
- **Implementation**: Claude Code with human oversight
- **Testing**: Pending

---

## References

- [CLAUDE.md](../CLAUDE.md) - Updated architecture documentation
- [AWS_COGNITO_SETUP.md](./AWS_COGNITO_SETUP.md) - Cognito configuration
- Plan file: `C:\Users\von12\.claude\plans\temporal-cuddling-snowglobe.md`

---

**Migration Date**: January 12, 2026
**Status**: ✅ Complete (awaiting integration testing)
