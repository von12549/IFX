# Plan: Auto-Provisioning OAuth Improvements

## Overview

Update the SSO auto-provisioning flow to:
1. Fetch user info from OIDC userinfo endpoint instead of relying on JWT claims
2. Assign "Pending" role to new users (incomplete registration)
3. Simplify the query interface by moving user info fetching to the handler

---

## Current Flow (Before)

```
UserRoleClaimsTransformation
    ↓ Extract claims from JWT (email, name, email_verified)
    ↓ Build GetOrProvisionUserQuery with all user data
GetOrProvisionUserQueryHandler
    ↓ Validate email is present
    ↓ Build ProvisionSsoUserCommand
ProvisionSsoUserCommandHandler
    ↓ Assign role based on IdpType (User/SsoUser)
    ↓ Create User with email from JWT
```

**Problem:** JWT access tokens often don't contain email/name claims.

---

## New Flow (After)

```
UserRoleClaimsTransformation
    ↓ Extract only: sub, iss, access_token
    ↓ Build simplified GetOrProvisionUserQuery
GetOrProvisionUserQueryHandler
    ↓ Use IOidcDiscoveryService to get userinfo endpoint
    ↓ Call userinfo endpoint with access token
    ↓ Build ProvisionSsoUserCommand with userinfo OR fallback
ProvisionSsoUserCommandHandler
    ↓ Always assign "Pending" role
    ↓ Create User (may have placeholder email)
```

**Benefit:** Works even when JWT doesn't contain user claims.

---

## Implementation Steps

### Step 1: Add "Pending" Role to Database

**File:** New migration or seed data

**Action:** Add a new role to the UserRoles table:

| RoleName | Description |
|----------|-------------|
| Pending | User with incomplete registration, requires profile completion |

**SQL:**
```sql
INSERT INTO auth.UserRoles (Id, RoleName, Description, CreatedAt, UpdatedAt)
VALUES (NEWID(), 'Pending', 'User with incomplete registration', GETUTCDATE(), GETUTCDATE());
```

**Option:** Add via EF Core migration or update seed data.

---

### Step 2: Update GetOrProvisionUserQuery

**File:** `src/Modules/Auth/AuthSamples.Modules.Auth.Application/Queries/GetOrProvisionUser/GetOrProvisionUserQuery.cs`

**Before:**
```csharp
public record GetOrProvisionUserQuery(
    string Issuer,
    string Subject,
    bool AutoProvisionEnabled,
    Guid? IdpId = null,
    IdpType? IdpType = null,
    string? Email = null,           // REMOVE
    string? FirstName = null,       // REMOVE
    string? LastName = null,        // REMOVE
    bool EmailVerified = false,     // REMOVE
    string? IpAddress = null) : IRequest<Result<UserAuthResult>>;
```

**After:**
```csharp
public record GetOrProvisionUserQuery(
    string Issuer,
    string Subject,
    string AccessToken,              // NEW - for userinfo call
    bool AutoProvisionEnabled,
    Guid? IdpId = null,
    IdpType? IdpType = null,
    string? IpAddress = null) : IRequest<Result<UserAuthResult>>;
```

**Changes:**
- Remove: `Email`, `FirstName`, `LastName`, `EmailVerified`
- Add: `AccessToken` (required for userinfo endpoint)

---

### Step 3: Update GetOrProvisionUserQueryHandler

**File:** `src/Modules/Auth/AuthSamples.Modules.Auth.Application/Queries/GetOrProvisionUser/GetOrProvisionUserQueryHandler.cs`

**Changes:**

#### 3.1 Add Dependencies

```csharp
private readonly IUnitOfWork _unitOfWork;
private readonly IMediator _mediator;
private readonly IOidcDiscoveryService _discoveryService;  // NEW
private readonly IHttpClientFactory _httpClientFactory;     // NEW
private readonly ILogger<GetOrProvisionUserQueryHandler> _logger;
```

#### 3.2 Remove Email Validation

**Remove this block (lines 76-82):**
```csharp
if (string.IsNullOrEmpty(request.Email))
{
    _logger.LogWarning(
        "SSO user from {Issuer}/{Subject} rejected: missing email",
        request.Issuer, request.Subject);
    return Result<UserAuthResult>.Failure("Email is required for auto-provisioning");
}
```

#### 3.3 Add UserInfo Fetching Logic

**New logic after IdpId/IdpType validation:**

```csharp
// Fetch OIDC discovery document
var discoveryDoc = await _discoveryService.GetDiscoveryDocumentAsync(request.Issuer, cancellationToken);

// Try to get user info from userinfo endpoint
string? email = null;
string? firstName = null;
string? lastName = null;
bool emailVerified = false;

if (!string.IsNullOrEmpty(discoveryDoc.UserInfoEndpoint))
{
    try
    {
        var httpClient = _httpClientFactory.CreateClient("OidcDiscovery");
        httpClient.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue("Bearer", request.AccessToken);

        var response = await httpClient.GetAsync(discoveryDoc.UserInfoEndpoint, cancellationToken);

        if (response.IsSuccessStatusCode)
        {
            var content = await response.Content.ReadAsStringAsync(cancellationToken);
            var userInfo = JsonSerializer.Deserialize<UserInfoResponse>(content);

            email = userInfo?.Email;
            firstName = userInfo?.GivenName;
            lastName = userInfo?.FamilyName;
            emailVerified = string.Equals(userInfo?.EmailVerified, "true", StringComparison.OrdinalIgnoreCase);

            _logger.LogInformation("Retrieved user info for {Subject}: email={Email}",
                request.Subject, email);
        }
        else
        {
            _logger.LogWarning("UserInfo request failed: {StatusCode}", response.StatusCode);
        }
    }
    catch (Exception ex)
    {
        _logger.LogWarning(ex, "Failed to fetch user info from {Endpoint}", discoveryDoc.UserInfoEndpoint);
    }
}

// Fallback if userinfo failed
if (string.IsNullOrEmpty(email))
{
    _logger.LogWarning("Using placeholder email for {Issuer}/{Subject} - userinfo unavailable",
        request.Issuer, request.Subject);
    email = $"{request.Subject}@pending.local";
    emailVerified = false;
}

// Build provision command with fetched or fallback data
var provisionCommand = new ProvisionSsoUserCommand(
    IdpId: request.IdpId.Value,
    Issuer: request.Issuer,
    Subject: request.Subject,
    IdpType: request.IdpType.Value,
    Email: email,
    FirstName: firstName,
    LastName: lastName,
    EmailVerified: emailVerified,
    IpAddress: request.IpAddress);
```

#### 3.4 Add UserInfoResponse Model

Add private class for deserializing userinfo response:

```csharp
private class UserInfoResponse
{
    [JsonPropertyName("sub")]
    public string? Sub { get; set; }

    [JsonPropertyName("email")]
    public string? Email { get; set; }

    [JsonPropertyName("email_verified")]
    public string? EmailVerified { get; set; }

    [JsonPropertyName("given_name")]
    public string? GivenName { get; set; }

    [JsonPropertyName("family_name")]
    public string? FamilyName { get; set; }

    [JsonPropertyName("name")]
    public string? Name { get; set; }
}
```

---

### Step 4: Update ProvisionSsoUserCommandHandler

**File:** `src/Modules/Auth/AuthSamples.Modules.Auth.Application/Commands/ProvisionSsoUser/ProvisionSsoUserCommandHandler.cs`

**Change:** Always assign "Pending" role instead of User/SsoUser.

**Before (lines 48-58):**
```csharp
// Determine role based on IdP type:
// - Internal IdP → "User" role
// - External IdP → "SsoUser" role
var roleName = request.IdpType == IdpType.Internal ? "User" : "SsoUser";
var userRole = await _unitOfWork.UserRoles.GetByRoleNameAsync(roleName, cancellationToken);
```

**After:**
```csharp
// Always assign "Pending" role for auto-provisioned users
// User must complete profile to get full role
const string roleName = "Pending";
var userRole = await _unitOfWork.UserRoles.GetByRoleNameAsync(roleName, cancellationToken);
```

**Update activity log message:**
```csharp
var activityLog = UserActivityLog.Create(
    user.Id,
    ActivityType.Registration,
    $"User auto-provisioned via SSO from {request.Issuer} (IdpType: {request.IdpType}) - Pending profile completion",
    request.IpAddress ?? "Unknown");
```

---

### Step 5: Update UserRoleClaimsTransformation

**File:** `src/ApiHost/AuthSamples.ApiHost/Authorization/UserRoleClaimsTransformation.cs`

**Change:** Pass access token instead of extracting claims.

**Before:**
```csharp
var query = new GetOrProvisionUserQuery(
    Issuer: issuer,
    Subject: subject,
    AutoProvisionEnabled: idpConfig.AutoProvisionEnabled,
    IdpId: idpConfig.IdpId,
    IdpType: idpConfig.IdpType,
    Email: email,
    FirstName: firstName,
    LastName: lastName,
    EmailVerified: emailVerified,
    IpAddress: ipAddress);
```

**After:**
```csharp
// Get access token from the authentication result
var accessToken = httpContext.Items["AccessToken"]?.ToString()
    ?? principal.FindFirst("access_token")?.Value
    ?? string.Empty;

var query = new GetOrProvisionUserQuery(
    Issuer: issuer,
    Subject: subject,
    AccessToken: accessToken,
    AutoProvisionEnabled: idpConfig.AutoProvisionEnabled,
    IdpId: idpConfig.IdpId,
    IdpType: idpConfig.IdpType,
    IpAddress: ipAddress);
```

**Also update DynamicJwtBearerEvents to store access token:**

In `MessageReceived` or `TokenValidated`:
```csharp
context.HttpContext.Items["AccessToken"] = token;
```

---

## File Changes Summary

| File | Change Type | Description |
|------|-------------|-------------|
| `UserRoles` table | Add data | Add "Pending" role |
| `GetOrProvisionUserQuery.cs` | Modify | Remove email/name, add AccessToken |
| `GetOrProvisionUserQueryHandler.cs` | Modify | Add OIDC discovery + userinfo fetch |
| `ProvisionSsoUserCommandHandler.cs` | Modify | Always assign "Pending" role |
| `UserRoleClaimsTransformation.cs` | Modify | Pass AccessToken, remove claim extraction |
| `DynamicJwtBearerEvents.cs` | Modify | Store AccessToken in HttpContext |

---

## New Flow Diagram

```
┌──────────────────────────────────────────────────────────────────────────┐
│ 1. Client Request: Authorization: Bearer <JWT>                           │
└────────────────────────────────────┬─────────────────────────────────────┘
                                     ▼
┌──────────────────────────────────────────────────────────────────────────┐
│ 2. DynamicJwtBearerEvents                                                │
│    • Validate JWT                                                        │
│    • Store AccessToken in HttpContext.Items["AccessToken"]      [NEW]    │
└────────────────────────────────────┬─────────────────────────────────────┘
                                     ▼
┌──────────────────────────────────────────────────────────────────────────┐
│ 3. UserRoleClaimsTransformation                                          │
│    • Extract: sub, iss (from JWT)                                        │
│    • Get: AccessToken (from HttpContext)                        [CHANGED]│
│    • Build simplified GetOrProvisionUserQuery                   [CHANGED]│
└────────────────────────────────────┬─────────────────────────────────────┘
                                     ▼
┌──────────────────────────────────────────────────────────────────────────┐
│ 4. GetOrProvisionUserQueryHandler                                        │
│    ┌─────────────────────────────────────────────────────────────────┐   │
│    │ Step 1: Lookup user by (Issuer, Subject)                        │   │
│    │         → If found: Return existing user                        │   │
│    └─────────────────────────────────────────────────────────────────┘   │
│    ┌─────────────────────────────────────────────────────────────────┐   │
│    │ Step 2: Check AutoProvisionEnabled                              │   │
│    └─────────────────────────────────────────────────────────────────┘   │
│    ┌─────────────────────────────────────────────────────────────────┐   │
│    │ Step 3: Fetch OIDC Discovery Document                   [NEW]   │   │
│    │         → IOidcDiscoveryService.GetDiscoveryDocumentAsync()     │   │
│    └─────────────────────────────────────────────────────────────────┘   │
│    ┌─────────────────────────────────────────────────────────────────┐   │
│    │ Step 4: Call UserInfo Endpoint                          [NEW]   │   │
│    │         → GET {userinfo_endpoint} with Bearer token             │   │
│    │         → Parse email, given_name, family_name, email_verified  │   │
│    └─────────────────────────────────────────────────────────────────┘   │
│    ┌─────────────────────────────────────────────────────────────────┐   │
│    │ Step 5: Fallback if UserInfo fails                      [NEW]   │   │
│    │         → email = "{subject}@pending.local"                     │   │
│    │         → emailVerified = false                                 │   │
│    └─────────────────────────────────────────────────────────────────┘   │
│    ┌─────────────────────────────────────────────────────────────────┐   │
│    │ Step 6: Send ProvisionSsoUserCommand                            │   │
│    └─────────────────────────────────────────────────────────────────┘   │
└────────────────────────────────────┬─────────────────────────────────────┘
                                     ▼
┌──────────────────────────────────────────────────────────────────────────┐
│ 5. ProvisionSsoUserCommandHandler                                        │
│    • Create User with "Pending" role                          [CHANGED] │
│    • Create UserIdentity (may have placeholder email)                    │
│    • Create UserActivityLog                                              │
└────────────────────────────────────┬─────────────────────────────────────┘
                                     ▼
┌──────────────────────────────────────────────────────────────────────────┐
│ 6. Return to Claims Transformation                                       │
│    • Add role claim: "Pending"                                [CHANGED] │
│    • Add user_id claim                                                   │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## Testing Checklist

- [ ] "Pending" role exists in database
- [ ] Existing users still work (no role change)
- [ ] New SSO users get "Pending" role
- [ ] UserInfo endpoint called when provisioning
- [ ] Fallback email works when userinfo fails
- [ ] Access token passed correctly through pipeline
- [ ] Audit log captures provisioning with correct message

---

## Future Considerations

1. **Profile Completion Flow** - Create endpoint for Pending users to complete profile
2. **Role Upgrade** - Logic to upgrade Pending → User/SsoUser after profile completion
3. **Email Verification** - Send verification email for placeholder emails
4. **Periodic Sync** - Background job to refresh user info from IdP
