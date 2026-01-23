# Email Verification Strategy & Flow

This document describes the email verification mechanism in AuthSamples.

## Overview

The system implements a **token-based email verification** mechanism that handles two primary scenarios:
1. **SSO users without verified email** - IdP doesn't provide `email_verified=true`
2. **Email address changes** - User updates their email via profile endpoint

The implementation uses CQRS pattern with MediatR, background job processing via Hangfire, and secure token/code generation.

## Key Principles

| Principle | Description |
|-----------|-------------|
| **Dual Verification** | Supports both link-based (token) and code-based verification |
| **Secure Token Storage** | Only SHA256 hash stored; plaintext token sent via email |
| **Rate Limiting** | Max 3 verification emails per user per hour |
| **Auto-Expiry** | Tokens expire after 60 minutes |
| **Single Use** | Tokens are invalidated immediately upon use |

---

## Architecture Components

### 1. Domain Layer

```
┌─────────────────────────────────────────────────────────────────┐
│                    EmailVerificationToken                        │
├─────────────────────────────────────────────────────────────────┤
│  Id                    : Guid                                    │
│  UserIdentityId        : Guid (FK)                              │
│  Email                 : string (256)                           │
│  TokenHash             : string (64) - SHA256 hex               │
│  Code                  : string (6) - Numeric code              │
│  ExpiresAt             : DateTime                               │
│  IsUsed                : bool                                   │
│  UsedAt                : DateTime?                              │
├─────────────────────────────────────────────────────────────────┤
│  Methods:                                                        │
│  • Create(userIdentityId, email, tokenHash, code, validity)     │
│  • IsValid() → bool (not used AND not expired)                  │
│  • MarkAsUsed() → sets IsUsed=true, UsedAt=now                 │
│  • Invalidate() → same as MarkAsUsed                            │
└─────────────────────────────────────────────────────────────────┘
```

### 2. Application Layer Commands

| Command | Purpose |
|---------|---------|
| `SendEmailVerificationCommand` | Create token and return info for email sending |
| `VerifyEmailCommand` | Verify code/token and update EmailVerified flag |
| `ResendEmailVerificationCommand` | Rate-limited resend (invalidates existing tokens) |

### 3. Key Files

| File | Purpose |
|------|---------|
| `EmailVerificationToken.cs` | Domain entity for verification tokens |
| `IEmailVerificationService.cs` | Token generation, hashing, email templates |
| `EmailVerificationService.cs` | Implementation with SHA256 and secure random |
| `SendEmailVerificationCommandHandler.cs` | Creates tokens, logs activity |
| `VerifyEmailCommandHandler.cs` | Validates and marks email as verified |
| `ResendEmailVerificationCommandHandler.cs` | Rate-limited resend logic |
| `EmailVerificationEndpoints.cs` | API endpoints for verification |
| `EmailVerificationCleanupService.cs` | Recurring job for expired token cleanup |

---

## Complete Email Verification Flow

### Flow 1: SSO Auto-Provisioning (Email Not Verified)

```
┌──────────────────────────────────────────────────────────────────────────┐
│ 1. User authenticates via SSO                                            │
│    • IdP returns email but email_verified=false or missing               │
└────────────────────────────────────┬─────────────────────────────────────┘
                                     ▼
┌──────────────────────────────────────────────────────────────────────────┐
│ 2. ProvisionSsoUserCommandHandler                                        │
│    • Creates User and UserIdentity with EmailVerified=false              │
│    • Returns ProvisionSsoUserResponse with:                              │
│      - RequiresEmailVerification = true                                  │
│      - UserIdentityId (for verification command)                         │
│      - Email address                                                     │
└────────────────────────────────────┬─────────────────────────────────────┘
                                     ▼
┌──────────────────────────────────────────────────────────────────────────┐
│ 3. Caller sends SendEmailVerificationCommand                             │
│    • Handler creates EmailVerificationToken                              │
│    • Returns token, code, and expiry for email                           │
└────────────────────────────────────┬─────────────────────────────────────┘
                                     ▼
┌──────────────────────────────────────────────────────────────────────────┐
│ 4. Background job sends verification email                               │
│    • Uses "email" queue in Hangfire                                      │
│    • Email contains 6-digit code AND verification link                   │
└────────────────────────────────────┬─────────────────────────────────────┘
                                     ▼
┌──────────────────────────────────────────────────────────────────────────┐
│ 5. User verifies via API                                                 │
│    • POST /api/v1/auth/email/verify with code OR                         │
│    • GET /api/v1/auth/email/verify?token=xxx&uid=xxx                    │
└────────────────────────────────────┬─────────────────────────────────────┘
                                     ▼
┌──────────────────────────────────────────────────────────────────────────┐
│ 6. VerifyEmailCommandHandler                                             │
│    • Validates token/code                                                │
│    • Marks token as used                                                 │
│    • Sets UserIdentity.EmailVerified = true                              │
│    • Creates activity log (EmailVerified)                                │
└──────────────────────────────────────────────────────────────────────────┘
```

### Flow 2: Email Change via Profile Update

```
┌──────────────────────────────────────────────────────────────────────────┐
│ 1. User calls PUT /api/v1/user/profile with new email                    │
└────────────────────────────────────┬─────────────────────────────────────┘
                                     ▼
┌──────────────────────────────────────────────────────────────────────────┐
│ 2. UpdateUserProfileCommandHandler                                       │
│    • Detects email change via UserIdentity.UpdateEmail()                 │
│    • Sets EmailVerified = false                                          │
│    • Creates activity log (EmailChanged)                                 │
│    • Returns RequiresEmailVerification = true                            │
└────────────────────────────────────┬─────────────────────────────────────┘
                                     ▼
┌──────────────────────────────────────────────────────────────────────────┐
│ 3. UserEndpoints.UpdateProfile                                           │
│    • Sends SendEmailVerificationCommand                                  │
│    • Builds verification email with link and code                        │
│    • Enqueues email job on "email" queue                                 │
└────────────────────────────────────┬─────────────────────────────────────┘
                                     ▼
┌──────────────────────────────────────────────────────────────────────────┐
│ 4. Same verification flow as above (steps 4-6)                           │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## Token Generation & Security

### Token Structure

```
┌─────────────────────────────────────────────────────────────────┐
│ Token: GUID without dashes (32 hex characters)                   │
│ Example: "a1b2c3d4e5f6789012345678abcdef01"                     │
│                                                                  │
│ TokenHash: SHA256(Token) → 64 hex characters                    │
│ Example: "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca..."  │
│                                                                  │
│ Code: 6-digit numeric code (000000-999999)                       │
│ Example: "123456"                                                │
└─────────────────────────────────────────────────────────────────┘
```

### Security Measures

| Measure | Implementation |
|---------|----------------|
| Token Storage | Only SHA256 hash stored in database |
| Code Generation | `RandomNumberGenerator.GetInt32()` (cryptographic) |
| Token in Email | Full token sent via email, never logged |
| Expiry | 60-minute validity period |
| Single Use | Immediately marked as used upon verification |
| Invalidation | All existing tokens invalidated when new one created |

---

## API Endpoints

### Public Endpoints (No Auth Required)

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/v1/auth/email/verify` | POST | Verify email with token or code |
| `/api/v1/auth/email/verify` | GET | Verify email via link (token + uid) |

### Authenticated Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/v1/user/email/send-verification` | POST | Request verification email |
| `/api/v1/user/email/resend-verification` | POST | Resend verification (rate limited) |

### Request/Response Examples

#### POST /api/v1/auth/email/verify

**Request (by code):**
```json
{
  "userIdentityId": "550e8400-e29b-41d4-a716-446655440000",
  "code": "123456"
}
```

**Request (by token):**
```json
{
  "userIdentityId": "550e8400-e29b-41d4-a716-446655440000",
  "token": "a1b2c3d4e5f6789012345678abcdef01"
}
```

**Success Response:**
```json
{
  "success": true,
  "data": {
    "success": true,
    "message": "Email verified successfully"
  }
}
```

---

## Rate Limiting

### Resend Limits

| Limit | Value | Enforcement |
|-------|-------|-------------|
| Max Resends | 3 per hour | Activity log counting |
| Activity Type | `EmailVerificationSent` | Counted per UserId |
| Reset | After 1 hour | Based on activity timestamp |

### Implementation

```csharp
// In ResendEmailVerificationCommandHandler
var recentCount = await GetRecentVerificationSentCountAsync(
    userId, TimeSpan.FromHours(1), cancellationToken);

if (recentCount >= MaxResendsPerHour) // MaxResendsPerHour = 3
{
    return Result.Failure("Too many verification emails sent...");
}
```

---

## Email Templates

### HTML Template Features

- Responsive design with inline CSS
- Clear verification code display (large, spaced)
- Clickable verification button
- Expiry time warning
- Plain text fallback included

### Template Variables

| Variable | Example |
|----------|---------|
| `userName` | "John Doe" |
| `code` | "123456" |
| `verificationLink` | "https://app.example.com/verify?token=xxx&uid=yyy" |
| `expiryMinutes` | 60 |

---

## Database Schema

### EmailVerificationTokens Table

```sql
CREATE TABLE EmailVerificationTokens (
    Id              UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    UserIdentityId  UNIQUEIDENTIFIER NOT NULL,
    Email           NVARCHAR(256) NOT NULL,
    TokenHash       NVARCHAR(64) NOT NULL,
    Code            NVARCHAR(6) NOT NULL,
    ExpiresAt       DATETIME2 NOT NULL,
    IsUsed          BIT NOT NULL DEFAULT 0,
    UsedAt          DATETIME2 NULL,
    CreatedAt       DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    UpdatedAt       DATETIME2 NOT NULL DEFAULT GETUTCDATE(),

    CONSTRAINT FK_EmailVerificationTokens_UserIdentity
        FOREIGN KEY (UserIdentityId) REFERENCES UserIdentities(Id)
        ON DELETE CASCADE,

    CONSTRAINT UQ_EmailVerificationTokens_TokenHash
        UNIQUE (TokenHash)
);

CREATE INDEX IX_EmailVerificationTokens_UserIdentityCode
    ON EmailVerificationTokens(UserIdentityId, Code);

CREATE INDEX IX_EmailVerificationTokens_ExpiresAt
    ON EmailVerificationTokens(ExpiresAt);
```

---

## Activity Logging

### Activity Types

| ActivityType | When Created |
|--------------|--------------|
| `EmailVerificationSent` | Token created, email queued |
| `EmailVerified` | Successful verification |
| `EmailVerificationFailed` | Invalid token/code attempt |
| `EmailChanged` | Email address updated in profile |

### Audit Trail Example

```
User: 550e8400-e29b-41d4-a716-446655440000
Activities:
1. EmailChanged - "Email changed from old@example.com to new@example.com"
2. EmailVerificationSent - "Email verification sent to new@example.com"
3. EmailVerified - "Email verified: new@example.com"
```

---

## Cleanup Job

### Recurring Job Configuration

```csharp
// In RecurringJobsExtensions.cs
backgroundJobService.AddOrUpdateRecurring<IEmailVerificationCleanupService>(
    "email-verification-cleanup",
    service => service.CleanupExpiredTokensAsync(default),
    "0 2 * * *"); // Daily at 2:00 AM
```

### Cleanup Logic

```csharp
// Deletes all tokens where ExpiresAt < DateTime.UtcNow
await _unitOfWork.EmailVerificationTokens.DeleteExpiredAsync(cancellationToken);
```

---

## Integration Points

### UserIdentity Methods

```csharp
// Update email and reset verification status
public bool UpdateEmail(EmailAddress newEmail)
{
    if (Email.Value == newEmail.Value)
        return false; // No change

    Email = newEmail;
    EmailVerified = false; // Reset verification
    return true;
}

// Set verification status
public void SetEmailVerified(bool verified)
{
    EmailVerified = verified;
}
```

### ProvisionSsoUserResponse

```csharp
public record ProvisionSsoUserResponse
{
    public Guid UserId { get; init; }
    public Guid UserIdentityId { get; init; }     // For verification command
    public string RoleName { get; init; }
    public bool WasProvisioned { get; init; }
    public bool RequiresEmailVerification { get; init; }  // Trigger verification
    public string? Email { get; init; }
}
```

---

## Configuration

### appsettings.json

```json
{
  "EmailVerification": {
    "TokenValidityMinutes": 60,
    "MaxResendsPerHour": 3,
    "VerificationBaseUrl": "https://app.example.com/verify-email"
  }
}
```

---

## Error Handling

### Common Error Responses

| Error | HTTP Status | Message |
|-------|-------------|---------|
| User not found | 400 | "User identity not found" |
| Already verified | 400 | "Email is already verified" |
| Invalid token/code | 400 | "Invalid or expired verification token/code" |
| Expired token | 400 | "Verification token has expired or already been used" |
| Rate limited | 400 | "Too many verification emails sent. Please wait..." |
| Token mismatch | 400 | "Invalid verification request" |

---

## Test Coverage

### Unit Tests

| Test Class | Tests | Coverage |
|------------|-------|----------|
| `EmailVerificationTokenTests` | 8 | Entity creation, validation, expiry |
| `SendEmailVerificationCommandHandlerTests` | 6 | Success, failure, logging |
| `VerifyEmailCommandHandlerTests` | 10 | Token/code paths, edge cases |
| `ResendEmailVerificationCommandHandlerTests` | 7 | Rate limiting, delegation |
| `EmailVerificationServiceTests` | 15 | Token generation, hashing, templates |

---

## Related Documentation

- [Auto-Provisioning Architecture](./auto-provisioning.md) - SSO user provisioning
- [Background Jobs Platform](../../.claude/dotnet/background-jobs.md) - Hangfire configuration
- [Notifications Platform](../../.claude/dotnet/notifications.md) - Email service
- [Database Schema](./database.md) - Entity relationships
