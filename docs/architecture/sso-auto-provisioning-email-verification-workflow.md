# SSO Login - Auto-Provisioning - Email Verification Workflow

This document describes the end-to-end workflow when a user authenticates via SSO, gets auto-provisioned, and completes email verification. It covers the complete journey from initial OAuth redirect to a fully verified user account.

## Overview

The system implements a three-phase workflow:

1. **SSO Login** - OAuth 2.0 Authorization Code flow with PKCE via Cognito Managed Login
2. **Auto-Provisioning** - On-the-fly user creation from OIDC userinfo when the user doesn't exist locally
3. **Email Verification** - Token/code-based verification for users whose email is not confirmed by the IdP

```
Phase 1: SSO Login              Phase 2: Auto-Provisioning       Phase 3: Email Verification
┌──────────────────────┐       ┌──────────────────────────┐     ┌───────────────────────────┐
│ OAuth Authorize       │       │ Claims Transformation     │     │ Send Verification Email    │
│ → Cognito Hosted UI   │  ──▶  │ → UserInfo Fetch          │ ──▶ │ → User Clicks Link/Code   │
│ → Callback + Tokens   │       │ → Create User (Pending)   │     │ → Email Marked Verified    │
└──────────────────────┘       └──────────────────────────┘     └───────────────────────────┘
```

---

## Phase 1: SSO Login (OAuth 2.0 Authorization Code + PKCE)

### Step 1.1 - Client Initiates OAuth Flow

**Endpoint:** `GET /api/v1/auth/oauth/authorize`
**File:** `Presentation/Endpoints/OAuth/OAuthEndpoints.cs`

The client (SPA or server) calls the authorize endpoint to begin the OAuth flow.

```
Client                          Backend                            Cognito
  │                                │                                  │
  │  GET /oauth/authorize          │                                  │
  │ ─────────────────────────────▶ │                                  │
  │                                │  Generate PKCE:                  │
  │                                │  • code_verifier (random)        │
  │                                │  • code_challenge (SHA256)       │
  │                                │  Generate state (CSRF token)     │
  │                                │  Cache state + code_verifier     │
  │                                │  (5-minute TTL)                  │
  │                                │                                  │
  │  ◀─ Return authorization URL   │                                  │
  │                                │                                  │
  │  Redirect to Cognito ─────────────────────────────────────────▶  │
  │                                │                  Hosted UI login │
  │  ◀──────────────────────────────────── Redirect with ?code&state │
```

### Step 1.2 - Callback: Exchange Code for Tokens

**Endpoint:** `GET /api/v1/auth/oauth/callback?code=xxx&state=yyy`
**File:** `Presentation/Endpoints/OAuth/OAuthEndpoints.cs`
**Service:** `Infrastructure/Services/CognitoOidcService.cs`

```
Client                          Backend                            Cognito
  │                                │                                  │
  │  GET /oauth/callback           │                                  │
  │  ?code=xxx&state=yyy           │                                  │
  │ ─────────────────────────────▶ │                                  │
  │                                │  Validate state parameter        │
  │                                │  Retrieve code_verifier from     │
  │                                │  cache (by state)                │
  │                                │                                  │
  │                                │  POST /oauth2/token ───────────▶ │
  │                                │  (code + code_verifier)          │
  │                                │                                  │
  │                                │  ◀── access_token, id_token,     │
  │                                │       refresh_token              │
  │                                │                                  │
  │  ◀─ Return tokens (JSON or    │                                  │
  │     redirect with fragment)    │                                  │
```

**Output:** Client stores `access_token` for authenticated API calls.

### Step 1.3 - Authenticated Request with Access Token

The client includes the access token in subsequent API requests:

```
Authorization: Bearer <access_token>
```

---

## Phase 2: Auto-Provisioning

When a user makes their first authenticated request, the system detects they don't exist locally and provisions them automatically.

### Step 2.1 - Dynamic JWT Validation

**File:** `ApiHost/Authentication/DynamicJwtBearerEvents.cs`
**File:** `ApiHost/Authentication/IdpConfigurationService.cs`

```
                    Incoming JWT
                         │
                         ▼
        ┌────────────────────────────────┐
        │  DynamicJwtBearerEvents        │
        │  MessageReceived               │
        │                                │
        │  1. Extract unvalidated JWT    │
        │  2. Read "iss" claim           │
        │  3. Lookup IdP by issuer       │
        │     (cached 5-min TTL)         │
        │  4. Validate IdP is enabled    │
        │  5. Store in HttpContext:       │
        │     • IdpConfiguration         │
        │     • AccessToken              │
        │  6. Fetch OIDC discovery       │
        │     (.well-known/openid-conf)  │
        └────────────────────────────────┘
                         │
                         ▼
        ┌────────────────────────────────┐
        │  JWT Token Validation          │
        │                                │
        │  • Signature (IdP's JWKS)      │
        │  • Issuer                      │
        │  • Audience                    │
        │  • Algorithms (if configured)  │
        │  • Lifetime (+ clock skew)     │
        └────────────────────────────────┘
```

### Step 2.2 - Claims Transformation Triggers Provisioning

**File:** `ApiHost/Authorization/UserRoleClaimsTransformation.cs`

After JWT validation succeeds, ASP.NET Core runs claims transformation. This is where auto-provisioning is triggered transparently.

```csharp
// Simplified flow in TransformAsync()
1. Extract sub (subject) and iss (issuer) from JWT
2. Get IdpConfiguration from HttpContext.Items  (set by DynamicJwtBearerEvents)
3. Get AccessToken from HttpContext.Items        (set by DynamicJwtBearerEvents)
4. Send GetOrProvisionUserQuery via MediatR
5. Add role + user_id claims to principal
```

### Step 2.3 - User Lookup or Provision

**File:** `Application/Queries/GetOrProvisionUser/GetOrProvisionUserQueryHandler.cs`

```
        GetOrProvisionUserQuery
        (Issuer, Subject, AccessToken,
         AutoProvisionEnabled, IdpId, IdpType)
                    │
                    ▼
        ┌──────────────────────────┐
        │  Lookup by (Issuer,      │
        │  Subject) in database    │ ◀── Unique constraint prevents
        └──────────────────────────┘     email takeover across IdPs
                    │
            ┌───────┴───────┐
            │               │
        Found           Not Found
            │               │
            ▼               ▼
        Return          Check AutoProvisionEnabled
        existing            │
        user            ┌───┴───┐
                        │       │
                    Disabled  Enabled
                        │       │
                        ▼       ▼
                    Return  Fetch OIDC Discovery
                    error   (cached 1-hour TTL)
                                │
                                ▼
                        ┌──────────────────────┐
                        │  Call UserInfo        │
                        │  Endpoint             │
                        │                       │
                        │  GET {userinfo_url}   │
                        │  Authorization:       │
                        │  Bearer {access_token}│
                        │                       │
                        │  Parse:               │
                        │  • email              │
                        │  • email_verified     │
                        │  • given_name         │
                        │  • family_name        │
                        └──────────────────────┘
                                │
                        ┌───────┴───────┐
                        │               │
                    Success          Failed
                        │               │
                        ▼               ▼
                    Use real        Fallback email:
                    user data       {subject}@pending.local
                                    emailVerified = false
                        │               │
                        └───────┬───────┘
                                │
                                ▼
                    Send ProvisionSsoUserCommand
```

### Step 2.4 - Create User Entities

**File:** `Application/Commands/ProvisionSsoUser/ProvisionSsoUserCommandHandler.cs`

```
        ProvisionSsoUserCommand
                    │
                    ▼
        ┌──────────────────────────────────┐
        │  Double-check user doesn't       │ ◀── Race condition safety
        │  exist by (Issuer, Subject)      │
        └──────────────────────────────────┘
                    │
                    ▼
        ┌──────────────────────────────────┐
        │  Assign "Pending" role           │ ◀── Always Pending for new
        │                                  │     SSO users. Must complete
        │  NOTE: NOT User/SsoUser yet.     │     profile to upgrade.
        │  User stays Pending until        │
        │  profile completion.             │
        └──────────────────────────────────┘
                    │
                    ▼
        ┌──────────────────────────────────┐
        │  Create entities:                │
        │                                  │
        │  User                            │
        │  ├── UserRoleId = Pending        │
        │  ├── DisplayName = name or email │
        │  ├── IsActive = true             │
        │  └── CreatedAt = now             │
        │                                  │
        │  UserIdentity                    │
        │  ├── UserId = user.Id            │
        │  ├── IdpId = idp.Id              │
        │  ├── Issuer = jwt.iss            │
        │  ├── Subject = jwt.sub           │
        │  ├── Email = from userinfo       │
        │  ├── EmailVerified = from IdP    │
        │  └── FirstName, LastName         │
        │                                  │
        │  UserActivityLog                 │
        │  ├── ActivityType: Registration  │
        │  └── "Auto-provisioned via SSO   │
        │       from {issuer} - Pending    │
        │       profile completion"        │
        └──────────────────────────────────┘
                    │
                    ▼
        ┌──────────────────────────────────┐
        │  Return ProvisionSsoUserResponse │
        │                                  │
        │  UserId                          │
        │  UserIdentityId                  │
        │  RoleName: "Pending"             │
        │  WasProvisioned: true            │
        │  RequiresEmailVerification: ?    │ ◀── true if emailVerified=false
        │  Email: user@example.com         │     AND email is not empty
        └──────────────────────────────────┘
```

### Step 2.5 - Claims Added to Principal

Back in `UserRoleClaimsTransformation`, the role and user_id claims are added:

```csharp
identity.AddClaim(new Claim(ClaimTypes.Role, "Pending"));
identity.AddClaim(new Claim("user_id", userId.ToString()));
```

The request then continues with the authenticated and authorized principal.

---

## Phase 3: Email Verification

Email verification is triggered when `RequiresEmailVerification = true` in the provisioning response. This happens when:
- The IdP does not return `email_verified = true` in the userinfo response
- The userinfo endpoint call failed and a placeholder email was assigned
- The user later changes their email via profile update

### Step 3.1 - User Requests Verification Email

**Endpoint:** `POST /api/v1/user/email/send-verification` (authenticated)
**File:** `Presentation/Endpoints/EmailVerification/EmailVerificationEndpoints.cs`

The frontend detects the user needs email verification (Pending role, unverified email) and prompts them to verify. The user triggers the send.

```
Client (authenticated)              Backend
  │                                    │
  │  POST /user/email/                 │
  │  send-verification                 │
  │ ──────────────────────────────────▶│
  │                                    │
  │                                    │  1. Extract issuer/subject from JWT
  │                                    │  2. Find UserIdentity by (issuer, subject)
  │                                    │  3. Send SendEmailVerificationCommand
  │                                    │
  │                                    ▼
  │                           ┌────────────────────────────┐
  │                           │  SendEmailVerification     │
  │                           │  CommandHandler             │
  │                           │                             │
  │                           │  • Validate UserIdentity    │
  │                           │  • Check not already        │
  │                           │    verified                 │
  │                           │  • Invalidate all existing  │
  │                           │    tokens for this user     │
  │                           │  • Generate credentials:    │
  │                           │    - Token: GUID (32 hex)   │
  │                           │    - TokenHash: SHA256(tok) │
  │                           │    - Code: 6-digit random   │
  │                           │  • Create EmailVerification │
  │                           │    Token entity (60-min     │
  │                           │    expiry)                  │
  │                           │  • Log: EmailVerification   │
  │                           │    Sent                     │
  │                           └────────────────────────────┘
  │                                    │
  │                                    ▼
  │                           ┌────────────────────────────┐
  │                           │  Build email content:       │
  │                           │  • HTML template            │
  │                           │    (responsive, inline CSS) │
  │                           │  • 6-digit code displayed   │
  │                           │    prominently              │
  │                           │  • Clickable verify button  │
  │                           │  • Expiry warning           │
  │                           │  • Plain text fallback      │
  │                           │                             │
  │                           │  Build verification link:   │
  │                           │  {baseUrl}?token=xxx        │
  │                           │  &uid={userIdentityId}      │
  │                           └────────────────────────────┘
  │                                    │
  │                                    ▼
  │                           ┌────────────────────────────┐
  │                           │  Enqueue background job     │
  │                           │  via Hangfire ("email"      │
  │                           │  queue)                     │
  │                           │                             │
  │                           │  IEmailService.SendEmailAsync│
  │                           │  (SendGrid)                 │
  │                           └────────────────────────────┘
  │                                    │
  │  ◀─ 200 OK                        │
  │  { message, expiresAt }            │
```

### Step 3.2 - User Receives Email

The background job sends the email via SendGrid. The email contains two verification methods:

```
┌─────────────────────────────────────────────┐
│                                             │
│  Verify your email address                  │
│                                             │
│  Hi John Doe,                               │
│                                             │
│  Your verification code is:                 │
│                                             │
│  ┌───────────────────────────┐              │
│  │    1  2  3  4  5  6       │ ◀── Option A │
│  └───────────────────────────┘    (code)    │
│                                             │
│  Or click the button below:                 │
│                                             │
│  ┌───────────────────────────┐              │
│  │    Verify Email Address   │ ◀── Option B │
│  └───────────────────────────┘    (link)    │
│                                             │
│  This link expires in 60 minutes.           │
│                                             │
└─────────────────────────────────────────────┘
```

### Step 3.3 - User Verifies Email

Two verification paths are available:

#### Option A: Code-Based Verification

**Endpoint:** `POST /api/v1/auth/email/verify` (public, no auth required)

```json
{
  "userIdentityId": "550e8400-e29b-41d4-a716-446655440000",
  "code": "123456"
}
```

#### Option B: Link-Based Verification

**Endpoint:** `GET /api/v1/auth/email/verify?token=xxx&uid=yyy` (public, no auth required)

```
User clicks link in email
    │
    ▼
GET /api/v1/auth/email/verify
  ?token=a1b2c3d4e5f6789012345678abcdef01
  &uid=550e8400-e29b-41d4-a716-446655440000
```

### Step 3.4 - Verification Processing

**File:** `Application/Commands/VerifyEmail/VerifyEmailCommandHandler.cs`

```
        VerifyEmailCommand
        (UserIdentityId, Token?, Code?)
                    │
                    ▼
        ┌──────────────────────────────┐
        │  Validate: token OR code     │
        │  provided (not both empty)   │
        └──────────────────────────────┘
                    │
                    ▼
        ┌──────────────────────────────┐
        │  Get UserIdentity by Id      │
        │  Check if already verified   │
        │  → return success early      │
        └──────────────────────────────┘
                    │
                    ▼
        ┌──────────────────────────────┐
        │  Find token:                 │
        │                              │
        │  If token provided:          │
        │  • Hash with SHA256          │
        │  • Lookup by TokenHash       │
        │  • Validate belongs to user  │
        │                              │
        │  If code provided:           │
        │  • Lookup by (UserIdentityId,│
        │    Code)                     │
        └──────────────────────────────┘
                    │
                    ▼
        ┌──────────────────────────────┐
        │  Validate token:             │
        │  • IsValid() = not used AND  │
        │    not expired               │
        │  • If invalid → log failure  │
        │    activity, return error    │
        └──────────────────────────────┘
                    │
                    ▼
        ┌──────────────────────────────┐
        │  Mark token as used:         │
        │  • IsUsed = true             │
        │  • UsedAt = DateTime.UtcNow  │
        └──────────────────────────────┘
                    │
                    ▼
        ┌──────────────────────────────┐
        │  Update UserIdentity:        │
        │  • EmailVerified = true      │
        │                              │
        │  Create activity log:        │
        │  • ActivityType: EmailVerified│
        │  • "Email verified: {email}" │
        └──────────────────────────────┘
                    │
                    ▼
        ┌──────────────────────────────┐
        │  Return success:             │
        │  {                           │
        │    success: true,            │
        │    message: "Email verified  │
        │              successfully"   │
        │  }                           │
        └──────────────────────────────┘
```

### Step 3.5 - Resending Verification

**Endpoint:** `POST /api/v1/user/email/resend-verification` (authenticated)

If the user didn't receive the email or the token expired, they can request a resend. Rate limiting applies.

```
Request resend
      │
      ▼
┌──────────────────────────────┐
│  Rate limit check:           │
│  Count EmailVerificationSent │
│  activities in last 1 hour   │
│                              │
│  If count >= 3 → reject      │
│  "Too many verification      │
│   emails sent"               │
└──────────────────────────────┘
      │ (under limit)
      ▼
┌──────────────────────────────┐
│  Invalidate existing tokens  │
│  Generate new token + code   │
│  Enqueue new email job       │
└──────────────────────────────┘
```

---

## Complete End-to-End Sequence Diagram

```
Client          Backend            Cognito       IdP Discovery    Hangfire     SendGrid
  │                │                  │               │              │            │
  │  1. GET /oauth/authorize         │               │              │            │
  │ ──────────────▶│                  │               │              │            │
  │  ◀── auth URL  │                  │               │              │            │
  │                │                  │               │              │            │
  │  2. Redirect ─────────────────▶  │               │              │            │
  │  ◀── Redirect with code ──────  │               │              │            │
  │                │                  │               │              │            │
  │  3. GET /oauth/callback          │               │              │            │
  │ ──────────────▶│                  │               │              │            │
  │                │  Exchange code ─▶│               │              │            │
  │                │  ◀── tokens ────│               │              │            │
  │  ◀── tokens    │                  │               │              │            │
  │                │                  │               │              │            │
  │  4. GET /api/user/profile         │               │              │            │
  │  (Bearer token)                   │               │              │            │
  │ ──────────────▶│                  │               │              │            │
  │                │                  │               │              │            │
  │                │── Validate JWT ─▶│               │              │            │
  │                │  (JWKS)         ◀│               │              │            │
  │                │                  │               │              │            │
  │                │── Claims Transformation          │              │            │
  │                │   Lookup user (not found)         │              │            │
  │                │                  │               │              │            │
  │                │── Fetch OIDC discovery ─────────▶│              │            │
  │                │  ◀── userinfo_endpoint ──────────│              │            │
  │                │                  │               │              │            │
  │                │── GET userinfo ─▶│               │              │            │
  │                │  ◀── email, name, verified ──────│              │            │
  │                │                  │               │              │            │
  │                │── Create User (Pending role)      │              │            │
  │                │── Create UserIdentity              │              │            │
  │                │── Create ActivityLog (Registration)│              │            │
  │                │                  │               │              │            │
  │                │── Add claims (role=Pending, user_id)              │            │
  │                │                  │               │              │            │
  │  ◀── profile   │                  │               │              │            │
  │  (role=Pending) │                 │               │              │            │
  │                │                  │               │              │            │
  │  5. POST /user/email/send-verification            │              │            │
  │ ──────────────▶│                  │               │              │            │
  │                │── Create token   │               │              │            │
  │                │── Build email    │               │              │            │
  │                │── Enqueue job ─────────────────────────────────▶│            │
  │  ◀── 200 OK   │                  │               │              │            │
  │                │                  │               │   Send email ─────────▶  │
  │                │                  │               │              │            │
  │  6. User reads email              │               │              │            │
  │     enters code or clicks link    │               │              │            │
  │                │                  │               │              │            │
  │  7. POST /auth/email/verify       │               │              │            │
  │  (code: "123456")                 │               │              │            │
  │ ──────────────▶│                  │               │              │            │
  │                │── Validate token │               │              │            │
  │                │── Mark used      │               │              │            │
  │                │── Set EmailVerified=true          │              │            │
  │                │── Log: EmailVerified              │              │            │
  │  ◀── success   │                  │               │              │            │
```

---

## Entity Relationships

```
┌──────────────┐       ┌───────────────────┐       ┌──────────────┐
│    User      │ 1──*  │   UserIdentity    │ *──1  │     Idp      │
├──────────────┤       ├───────────────────┤       ├──────────────┤
│ Id           │       │ Id                │       │ Id           │
│ UserRoleId   │       │ UserId            │       │ Name         │
│ DisplayName  │       │ IdpId             │       │ Issuer       │
│ IsActive     │       │ Issuer            │       │ Authority    │
│ CreatedAt    │       │ Subject           │       │ IdpType      │
│ UpdatedAt    │       │ Email             │       │ Enabled      │
└──────┬───────┘       │ EmailVerified  ◀──────── Verification target
       │               │ FirstName        │       │ AutoProvision│
       │               │ LastName         │       └──────────────┘
       ▼               │ LastSyncedAt     │
┌──────────────┐       └────────┬──────────┘
│  UserRole    │                │
├──────────────┤                │ 1
│ Id           │                │
│ RoleName     │                *
│ Description  │       ┌────────────────────────┐
└──────────────┘       │ EmailVerificationToken │
                       ├────────────────────────┤
 Roles:                │ Id                     │
 • Pending             │ UserIdentityId         │
 • User                │ Email                  │
 • SsoUser             │ TokenHash (SHA256)     │
 • Admin               │ Code (6-digit)         │
                       │ ExpiresAt              │
                       │ IsUsed                 │
                       │ UsedAt                 │
                       └────────────────────────┘
```

**Key constraint:** `(Issuer, Subject)` is unique on `UserIdentity`, preventing email takeover across identity providers.

---

## Security Measures

### OAuth / PKCE

| Measure | Detail |
|---------|--------|
| PKCE | code_verifier + code_challenge (S256) prevents authorization code interception |
| State parameter | Random value cached server-side prevents CSRF |
| State cache TTL | 5 minutes, auto-expires |

### JWT Validation

| Measure | Detail |
|---------|--------|
| Dynamic JWKS | Each IdP's signing keys fetched from OIDC discovery |
| Issuer validation | JWT issuer must match a configured, enabled IdP |
| Audience validation | Configurable per-IdP expected audiences |
| Algorithm restriction | Configurable allowed algorithms per-IdP |
| Clock skew | Default 5 minutes, configurable per-IdP |

### User Identity

| Measure | Detail |
|---------|--------|
| (Issuer, Subject) tuple | Users identified by this pair, not email alone |
| No email-based lookup | Prevents one IdP's user from claiming another's account |
| Pending role | Auto-provisioned users get restricted access until profile completion |

### Email Verification Tokens

| Measure | Detail |
|---------|--------|
| SHA256 hashing | Only hash stored in database; plaintext sent in email |
| Cryptographic code | 6-digit code via `RandomNumberGenerator.GetInt32()` |
| Single use | Marked as used immediately upon verification |
| 60-minute expiry | Configurable via `EmailVerification:TokenValidityMinutes` |
| Invalidation | All prior tokens invalidated when a new one is generated |
| Rate limiting | Max 3 verification emails per user per hour |
| Daily cleanup | Hangfire job removes expired tokens at 2:00 AM |

---

## Audit Trail

Every step is recorded in `UserActivityLog`:

| Step | ActivityType | Description |
|------|-------------|-------------|
| User provisioned | `Registration` | "User auto-provisioned via SSO from {issuer} (IdpType: {type}) - Pending profile completion" |
| Verification sent | `EmailVerificationSent` | "Email verification sent to {email}" |
| Verification success | `EmailVerified` | "Email verified: {email}" |
| Verification failed | `EmailVerificationFailed` | "Invalid verification attempt for {email}" |
| Email changed | `EmailChanged` | "Email changed from {old} to {new}" |

---

## Configuration

### appsettings.json

```json
{
  "CognitoOidcSettings": {
    "Domain": "myapp.auth.ap-southeast-2.amazoncognito.com",
    "ClientId": "<client-id>",
    "ClientSecret": "<client-secret>",
    "CallbackUrl": "https://api.example.com/api/v1/auth/oauth/callback",
    "FrontendCallbackUrl": "https://app.example.com/auth/callback",
    "Scopes": ["openid", "email", "profile"],
    "StateCacheDurationSeconds": 300
  },
  "EmailVerification": {
    "TokenValidityMinutes": 60,
    "MaxResendsPerHour": 3,
    "VerificationBaseUrl": "https://app.example.com/verify-email"
  }
}
```

### IdP Configuration (Database)

```json
{
  "Name": "Corporate Cognito",
  "Issuer": "https://cognito-idp.ap-southeast-2.amazonaws.com/ap-southeast-2_XXXXXXXX",
  "Authority": "https://cognito-idp.ap-southeast-2.amazonaws.com/ap-southeast-2_XXXXXXXX",
  "IdpType": "Internal",
  "Enabled": true,
  "AutoProvisionEnabled": true,
  "ExpectedAudiences": ["client-id"],
  "AllowedAlgs": ["RS256"],
  "ClockSkewSeconds": 300
}
```

---

## API Endpoints Summary

### Phase 1: OAuth

| Method | Endpoint | Auth | Purpose |
|--------|----------|------|---------|
| GET | `/api/v1/auth/oauth/authorize` | No | Start OAuth flow |
| GET | `/api/v1/auth/oauth/callback` | No | Exchange code for tokens |

### Phase 2: Auto-Provisioning

Provisioning happens automatically during claims transformation. No explicit endpoint.

### Phase 3: Email Verification

| Method | Endpoint | Auth | Purpose |
|--------|----------|------|---------|
| POST | `/api/v1/user/email/send-verification` | Yes | Request verification email |
| POST | `/api/v1/user/email/resend-verification` | Yes | Resend (rate limited, max 3/hr) |
| GET | `/api/v1/user/email/status` | Yes | Check email + verification status |
| POST | `/api/v1/auth/email/verify` | No | Verify with code (JSON body) |
| GET | `/api/v1/auth/email/verify` | No | Verify with link (query params) |

---

## Key Source Files

| File | Layer | Purpose |
|------|-------|---------|
| `OAuthEndpoints.cs` | Presentation | OAuth authorize/callback endpoints |
| `CognitoOidcService.cs` | Infrastructure | PKCE, auth URL, token exchange |
| `DynamicJwtBearerEvents.cs` | ApiHost | Dynamic JWT validation per issuer |
| `IdpConfigurationService.cs` | ApiHost | IdP config caching (5-min TTL) |
| `UserRoleClaimsTransformation.cs` | ApiHost | Claims transformation, provisioning trigger |
| `GetOrProvisionUserQueryHandler.cs` | Application | User lookup, OIDC discovery, userinfo fetch |
| `ProvisionSsoUserCommandHandler.cs` | Application | User + UserIdentity creation |
| `SendEmailVerificationCommandHandler.cs` | Application | Token generation, activity logging |
| `VerifyEmailCommandHandler.cs` | Application | Token validation, email verified flag |
| `ResendEmailVerificationCommandHandler.cs` | Application | Rate-limited resend |
| `EmailVerificationService.cs` | Infrastructure | SHA256 hashing, code generation, templates |
| `EmailVerificationEndpoints.cs` | Presentation | Verification API endpoints |
| `OidcDiscoveryService.cs` | Infrastructure | OIDC .well-known fetching (1-hour cache) |
| `EmailVerificationCleanupService.cs` | Infrastructure | Hangfire recurring cleanup job |

---

## Related Documentation

- [Auto-Provisioning Strategy](./auto-provisioning.md) - Detailed provisioning architecture
- [Email Verification](./email-verification.md) - Token and code verification details
- [SSO Multi-IdP Authentication](../sso-multi-idp.md) - Multi-IdP configuration guide
- [Database Schema](./database.md) - Entity relationships and constraints
- [Cognito Managed Login Plan](../../.claude/Plans/cognito-managed-login.md) - OAuth implementation plan
- [UserInfo Provisioning Plan](../../.claude/Plans/auto-provision-oauth-improvements.md) - UserInfo-based provisioning
