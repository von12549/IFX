# SSO Auto-Provisioning Strategy & Flow

This document describes the current auto-provisioning mechanism for SSO users in AuthSamples.

## Overview

The system implements a **database-driven, dynamic multi-IdP SSO auto-provisioning** mechanism that creates users on-the-fly when they authenticate through configured identity providers. The flow uses CQRS pattern with MediatR.

## Key Principles

| Principle | Description |
|-----------|-------------|
| **User Identity** | Users identified by `(Issuer, Subject)` tuple, NOT email |
| **Trust Model** | System trusts IdP's `email_verified` claim |
| **Role Assignment** | Based on IdpType: Internal → "User", External → "SsoUser" |
| **Activation** | SSO users are active immediately (no email verification required) |

---

## Architecture Components

### 1. Authentication Pipeline

```
┌─────────────────────────────────────────────────────────────────┐
│                    JWT Bearer Authentication                     │
├─────────────────────────────────────────────────────────────────┤
│  DynamicJwtBearerEvents                                         │
│  ├── MessageReceived: Extract issuer, lookup IdP config         │
│  ├── TokenValidated: Log success                                │
│  └── AuthenticationFailed: Log failure                          │
├─────────────────────────────────────────────────────────────────┤
│  UserRoleClaimsTransformation                                   │
│  ├── Extract claims (sub, iss, email, name, email_verified)     │
│  ├── Execute GetOrProvisionUserQuery                            │
│  └── Add role claims to principal                               │
└─────────────────────────────────────────────────────────────────┘
```

### 2. Key Files

| File | Purpose |
|------|---------|
| `DynamicJwtBearerEvents.cs` | JWT validation with dynamic IdP config |
| `UserRoleClaimsTransformation.cs` | Claims transformation & auto-provision trigger |
| `GetOrProvisionUserQueryHandler.cs` | Orchestrates user lookup/provisioning |
| `ProvisionSsoUserCommandHandler.cs` | Creates new SSO users |
| `IdpConfigurationService.cs` | Caches IdP configurations (5-minute TTL) |

---

## Complete Authentication Flow

```
┌──────────────────────────────────────────────────────────────────────────┐
│ 1. Client Request                                                        │
│    Authorization: Bearer <JWT>                                           │
└────────────────────────────────────┬─────────────────────────────────────┘
                                     ▼
┌──────────────────────────────────────────────────────────────────────────┐
│ 2. DynamicJwtBearerEvents.MessageReceived                                │
│    • Extract issuer from unvalidated JWT                                 │
│    • Lookup IdP by issuer in IdpConfigurationService                     │
│    • Validate IdP is enabled                                             │
│    • Store IdpConfiguration in HttpContext.Items                         │
└────────────────────────────────────┬─────────────────────────────────────┘
                                     ▼
┌──────────────────────────────────────────────────────────────────────────┐
│ 3. JWT Token Validation                                                  │
│    • Validate signature using IdP's JWKS                                 │
│    • Validate issuer, audience, algorithms                               │
│    • Validate token lifetime                                             │
└────────────────────────────────────┬─────────────────────────────────────┘
                                     ▼
┌──────────────────────────────────────────────────────────────────────────┐
│ 4. UserRoleClaimsTransformation.TransformAsync                           │
│    • Extract claims: sub, iss, email, given_name, family_name            │
│    • Extract email_verified (string "true" → bool)                       │
│    • Build GetOrProvisionUserQuery                                       │
│    • Send query via MediatR                                              │
└────────────────────────────────────┬─────────────────────────────────────┘
                                     ▼
┌──────────────────────────────────────────────────────────────────────────┐
│ 5. GetOrProvisionUserQueryHandler                                        │
│    ┌─────────────────────────────────────────────────────────────────┐   │
│    │ Step 1: Lookup user by (Issuer, Subject)                        │   │
│    │         → If found with role: Return existing user              │   │
│    │         → If found without role: Return error                   │   │
│    └─────────────────────────────────────────────────────────────────┘   │
│    ┌─────────────────────────────────────────────────────────────────┐   │
│    │ Step 2: Check AutoProvisionEnabled                              │   │
│    │         → If disabled: Return "User not found" error            │   │
│    └─────────────────────────────────────────────────────────────────┘   │
│    ┌─────────────────────────────────────────────────────────────────┐   │
│    │ Step 3: Validate required fields                                │   │
│    │         → IdpId, IdpType, Email must be present                 │   │
│    └─────────────────────────────────────────────────────────────────┘   │
│    ┌─────────────────────────────────────────────────────────────────┐   │
│    │ Step 4: Send ProvisionSsoUserCommand                            │   │
│    └─────────────────────────────────────────────────────────────────┘   │
└────────────────────────────────────┬─────────────────────────────────────┘
                                     ▼
┌──────────────────────────────────────────────────────────────────────────┐
│ 6. ProvisionSsoUserCommandHandler                                        │
│    • Double-check user doesn't exist (race condition safety)             │
│    • Determine role: Internal IdP → "User", External IdP → "SsoUser"     │
│    • Create User entity (isActive = true)                                │
│    • Create UserIdentity with IdP data                                   │
│    • Create UserActivityLog (audit trail)                                │
│    • Persist via UnitOfWork                                              │
└────────────────────────────────────┬─────────────────────────────────────┘
                                     ▼
┌──────────────────────────────────────────────────────────────────────────┐
│ 7. Return to Claims Transformation                                       │
│    • Add ClaimTypes.Role → RoleName                                      │
│    • Add "user_id" → UserId                                              │
│    • Return enriched ClaimsPrincipal                                     │
└────────────────────────────────────┬─────────────────────────────────────┘
                                     ▼
┌──────────────────────────────────────────────────────────────────────────┐
│ 8. Request proceeds with authenticated & authorized principal            │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## Data Flow

### Claims Extracted from JWT

| Claim | Source | Required | Usage |
|-------|--------|----------|-------|
| `sub` | JWT standard | Yes | User identity (Subject) |
| `iss` | JWT standard | Yes | IdP identification (Issuer) |
| `email` | OIDC | Yes* | User email (required for provisioning) |
| `email_verified` | OIDC | No | Trust flag from IdP |
| `given_name` | OIDC | No | User's first name |
| `family_name` | OIDC | No | User's last name |

*Email is required only when auto-provisioning a new user.

### GetOrProvisionUserQuery

```csharp
public record GetOrProvisionUserQuery(
    string Issuer,           // From JWT "iss" claim
    string Subject,          // From JWT "sub" claim
    bool AutoProvisionEnabled, // From IdP configuration
    Guid? IdpId,             // From IdP configuration
    IdpType? IdpType,        // Internal or External
    string? Email,           // From JWT "email" claim
    string? FirstName,       // From JWT "given_name" claim
    string? LastName,        // From JWT "family_name" claim
    bool EmailVerified,      // From JWT "email_verified" claim
    string? IpAddress        // From HttpContext
);
```

### ProvisionSsoUserCommand

```csharp
public record ProvisionSsoUserCommand(
    Guid IdpId,
    string Issuer,
    string Subject,
    IdpType IdpType,
    string? Email,
    string? FirstName,
    string? LastName,
    bool EmailVerified,
    string? IpAddress
);
```

---

## Entity Relationships

```
┌─────────────┐       ┌──────────────────┐       ┌─────────────┐
│    User     │ 1───* │   UserIdentity   │ *───1 │     Idp     │
├─────────────┤       ├──────────────────┤       ├─────────────┤
│ Id          │       │ Id               │       │ Id          │
│ UserRoleId  │       │ UserId           │       │ Name        │
│ DisplayName │       │ IdpId            │       │ Issuer      │
│ IsActive    │       │ Issuer           │       │ Authority   │
│ CreatedAt   │       │ Subject          │       │ IdpType     │
│ UpdatedAt   │       │ Email            │       │ IsPrimary   │
└─────────────┘       │ EmailVerified    │       │ Enabled     │
       │              │ FirstName        │       │ AutoProvision│
       │              │ LastName         │       │ ClaimMapping│
       ▼              │ LastSyncedAt     │       └─────────────┘
┌─────────────┐       └──────────────────┘
│  UserRole   │
├─────────────┤
│ Id          │
│ Name        │   Unique Constraint: (Issuer, Subject)
│ Description │   → Prevents email takeover across IdPs
└─────────────┘
```

---

## Role Assignment Strategy

| IdpType | Default Role | Description |
|---------|--------------|-------------|
| `Internal` | User | Full application access |
| `External` | SsoUser | Restricted SSO-only access |

The IdpType is configured per IdP in the database and determines what role is assigned to auto-provisioned users.

---

## Email Verification Handling

### Current Behavior

1. **Trusts IdP's `email_verified` claim** - If IdP says email is verified, system accepts it
2. **No additional verification** - SSO users don't receive verification emails
3. **Immediate activation** - Users are active upon provisioning (`isActive = true`)
4. **Stored in UserIdentity** - `EmailVerified` flag preserved for audit

### Rationale

- Enterprise IdPs (Cognito, Azure AD, Google) have already verified emails
- SSO implies trust in the identity provider
- Adding verification would create friction in enterprise scenarios

---

## Audit Trail

Every auto-provisioned user creates a `UserActivityLog` entry:

```csharp
UserActivityLog.Create(
    userId: newUser.Id,
    activityType: ActivityType.Registration,
    description: $"User auto-provisioned via SSO from {command.Issuer} (IdpType: {command.IdpType})",
    ipAddress: command.IpAddress
);
```

---

## Configuration Caching

`IdpConfigurationService` caches IdP configurations:

| Setting | Value |
|---------|-------|
| Cache Duration | 5 minutes (sliding) |
| Cache Key | IdP Issuer |
| Invalidation | Manual via `IIdpCacheInvalidator` |

---

## Current Limitations

### 1. Email Claim Availability

**Problem:** Access tokens from SDK-based Cognito authentication (`InitiateAuthAsync`) don't include email/email_verified claims in the JWT.

**Impact:** Auto-provisioning may fail if email is not present in the token.

**Solution:** Use OAuth 2.0 Authorization Code flow with Cognito Managed Login, which provides access to `/oauth2/userInfo` endpoint.

### 2. No UserInfo Endpoint Integration

**Problem:** Current implementation only extracts claims from the JWT token itself.

**Impact:** If claims are missing from JWT, provisioning fails even though they may be available via OIDC userinfo endpoint.

**Solution:** Integrate `IOidcAuthService.GetUserInfoAsync()` to fetch additional claims when needed.

### 3. No Claim Refresh

**Problem:** User claims (email, name) captured at first login are not updated on subsequent logins.

**Impact:** If user updates profile at IdP, local copy becomes stale.

**Solution:** Implement claim sync on each authentication or periodic sync.

---

## Recommended Improvements

1. **Integrate OIDC UserInfo endpoint** - Fetch claims via `/oauth2/userInfo` when JWT claims are insufficient
2. **Add claim sync on login** - Update UserIdentity with latest claims from IdP
3. **Use OIDC Discovery** - Leverage `IOidcDiscoveryService` to dynamically configure IdP endpoints
4. **Fallback chain** - Try JWT claims first, then userinfo endpoint if needed

---

## Related Documentation

- [Cognito Managed Login](../Plans/cognito-managed-login.md) - OAuth 2.0 implementation
- [SSO Multi-IdP Authentication](../sso-multi-idp.md) - Multi-IdP configuration guide
- [Database Schema](./database.md) - Entity relationships
