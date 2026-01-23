# Email Verification Plan

This document outlines the implementation plan for email verification functionality in AuthSamples.

## Overview

The email verification system handles scenarios where:
1. **IdP doesn't provide EmailVerified claim** - User authenticates via SSO but IdP doesn't return `email_verified` in UserInfo
2. **User changes their email** - User updates their email address and needs to re-verify

The system will:
- Send a verification email with a secure code/link
- Verify when user submits the code or clicks the link
- Update the `EmailVerified` flag on `UserIdentity`

---

## Trigger Scenarios

### Scenario 1: SSO Auto-Provisioning Without EmailVerified

```
User authenticates via SSO
    ↓
UserRoleClaimsTransformation extracts claims
    ↓
email_verified claim is missing or false
    ↓
GetOrProvisionUserQuery provisions user with EmailVerified=false
    ↓
System creates EmailVerificationToken
    ↓
Background job sends verification email on "email" queue
    ↓
User clicks link or enters code
    ↓
EmailVerified updated to true
```

### Scenario 2: Email Change

```
User updates email via /api/v1/user/profile
    ↓
UpdateUserProfileCommandHandler detects email change
    ↓
Sets EmailVerified=false on UserIdentity
    ↓
Creates EmailVerificationToken for new email
    ↓
Background job sends verification email on "email" queue
    ↓
User verifies new email
    ↓
EmailVerified updated to true
```

---

## Architecture Components

### 1. Domain Layer

#### New Entity: EmailVerificationToken

```csharp
namespace AuthSamples.Modules.Auth.Domain.Entities;

public class EmailVerificationToken : BaseEntity, IAuditableEntity
{
    public Guid UserIdentityId { get; private set; }
    public string Email { get; private set; }         // Email being verified
    public string TokenHash { get; private set; }     // SHA256 hash of token
    public string Code { get; private set; }          // 6-digit code (alternative to link)
    public DateTime ExpiresAt { get; private set; }
    public bool IsUsed { get; private set; }
    public DateTime? UsedAt { get; private set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    // Navigation
    public UserIdentity? UserIdentity { get; private set; }

    public static EmailVerificationToken Create(
        Guid userIdentityId,
        string email,
        string tokenHash,
        string code,
        TimeSpan validityPeriod);

    public bool IsValid() => !IsUsed && DateTime.UtcNow < ExpiresAt;

    public void MarkAsUsed();
}
```

#### Domain Constants

```csharp
public static class EmailVerificationConstants
{
    public const int CodeLength = 6;
    public const int TokenValidityMinutes = 60;  // 1 hour
    public const int MaxActiveTokensPerUser = 3;
}
```

#### New ActivityType Enum Values

```csharp
public enum ActivityType
{
    // Existing...
    EmailVerificationSent = 10,
    EmailVerified = 11,
    EmailVerificationFailed = 12,
    EmailChanged = 13
}
```

### 2. Application Layer

#### New Commands

| Command | Purpose |
|---------|---------|
| `SendEmailVerificationCommand` | Create token and enqueue verification email |
| `VerifyEmailCommand` | Verify code/token and update EmailVerified |
| `ResendEmailVerificationCommand` | Invalidate existing tokens, create new one, resend |

#### SendEmailVerificationCommand

```csharp
public record SendEmailVerificationCommand(
    Guid UserIdentityId,
    string? IpAddress) : IRequest<Result<SendEmailVerificationResponse>>;

public record SendEmailVerificationResponse(
    string Message,
    DateTime ExpiresAt);
```

**Handler Logic:**
1. Get UserIdentity by ID
2. Validate UserIdentity exists and has email
3. Check if EmailVerified is already true → return early
4. Invalidate existing active tokens for this UserIdentity
5. Generate secure token (GUID) and 6-digit code
6. Create EmailVerificationToken entity
7. Persist token
8. Enqueue email job via `IBackgroundJobService.Enqueue<IEmailService>(..., "email")`
9. Create UserActivityLog (EmailVerificationSent)
10. Return success with expiry time

#### VerifyEmailCommand

```csharp
public record VerifyEmailCommand(
    Guid UserIdentityId,
    string? Token,          // Token from link (one of these required)
    string? Code,           // 6-digit code (one of these required)
    string? IpAddress) : IRequest<Result<VerifyEmailResponse>>;

public record VerifyEmailResponse(
    bool Success,
    string Message);
```

**Handler Logic:**
1. Validate either Token or Code is provided
2. Get UserIdentity by ID
3. If Token provided: hash it, lookup by TokenHash
4. If Code provided: lookup by UserIdentityId + Code
5. Validate token is not expired and not used
6. Mark token as used
7. Update UserIdentity.EmailVerified = true
8. Create UserActivityLog (EmailVerified)
9. Return success

#### ResendEmailVerificationCommand

```csharp
public record ResendEmailVerificationCommand(
    Guid UserIdentityId,
    string? IpAddress) : IRequest<Result<ResendEmailVerificationResponse>>;
```

**Handler Logic:**
1. Get UserIdentity by ID
2. Invalidate all existing tokens
3. Delegate to SendEmailVerificationCommand handler
4. Apply rate limiting (max 3 resends per hour)

### 3. Infrastructure Layer

#### Repository Interface

```csharp
public interface IEmailVerificationTokenRepository
{
    Task<EmailVerificationToken?> GetByTokenHashAsync(string tokenHash, CancellationToken ct = default);
    Task<EmailVerificationToken?> GetByCodeAsync(Guid userIdentityId, string code, CancellationToken ct = default);
    Task<IReadOnlyList<EmailVerificationToken>> GetActiveByUserIdentityIdAsync(Guid userIdentityId, CancellationToken ct = default);
    Task AddAsync(EmailVerificationToken token, CancellationToken ct = default);
    Task UpdateAsync(EmailVerificationToken token, CancellationToken ct = default);
    Task InvalidateAllAsync(Guid userIdentityId, CancellationToken ct = default);
}
```

#### EF Core Configuration

```csharp
public class EmailVerificationTokenConfiguration : IEntityTypeConfiguration<EmailVerificationToken>
{
    public void Configure(EntityTypeBuilder<EmailVerificationToken> builder)
    {
        builder.ToTable("EmailVerificationTokens");
        builder.HasKey(e => e.Id);

        builder.Property(e => e.Email).HasMaxLength(256).IsRequired();
        builder.Property(e => e.TokenHash).HasMaxLength(64).IsRequired();  // SHA256 = 64 hex chars
        builder.Property(e => e.Code).HasMaxLength(6).IsRequired();

        builder.HasIndex(e => e.TokenHash).IsUnique();
        builder.HasIndex(e => new { e.UserIdentityId, e.Code });
        builder.HasIndex(e => e.ExpiresAt);  // For cleanup job

        builder.HasOne(e => e.UserIdentity)
            .WithMany()
            .HasForeignKey(e => e.UserIdentityId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
```

### 4. Presentation Layer

#### API Endpoints

| Endpoint | Method | Auth | Description |
|----------|--------|------|-------------|
| `/api/v1/auth/email/verify` | POST | None | Verify email with token/code |
| `/api/v1/user/email/send-verification` | POST | Authenticated | Request verification email |
| `/api/v1/user/email/resend-verification` | POST | Authenticated | Resend verification email |

#### Public Endpoint: Verify Email

```csharp
// POST /api/v1/auth/email/verify
public record VerifyEmailRequest(
    Guid UserIdentityId,
    string? Token,
    string? Code);

// Also support link-based: GET /api/v1/auth/email/verify?token=xxx&uid=xxx
```

#### Authenticated Endpoints

```csharp
// POST /api/v1/user/email/send-verification
// No body required - uses authenticated user's identity

// POST /api/v1/user/email/resend-verification
// No body required - uses authenticated user's identity
```

---

## Email Templates

### Verification Email Content

**Subject:** Verify your email address

**Body (HTML):**
```html
<h1>Verify Your Email</h1>
<p>Hello {{userName}},</p>
<p>Please verify your email address by clicking the link below or entering the verification code.</p>

<p><strong>Verification Code:</strong> {{code}}</p>

<p><a href="{{verificationLink}}">Click here to verify your email</a></p>

<p>This link expires in {{expiryMinutes}} minutes.</p>

<p>If you didn't request this verification, please ignore this email.</p>
```

**Variables:**
- `{{userName}}` - User's display name or "User"
- `{{code}}` - 6-digit verification code
- `{{verificationLink}}` - Full verification URL with token
- `{{expiryMinutes}}` - Token validity in minutes

---

## Database Schema

### New Table: EmailVerificationTokens

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

## Integration with Auto-Provisioning

### Modified GetOrProvisionUserQueryHandler

After provisioning a user where `EmailVerified = false`:

```csharp
// In ProvisionSsoUserCommandHandler or GetOrProvisionUserQueryHandler
if (!command.EmailVerified && !string.IsNullOrEmpty(command.Email))
{
    // Send email verification command
    await mediator.Send(new SendEmailVerificationCommand(
        userIdentity.Id,
        command.IpAddress));
}
```

### Modified UpdateUserProfileCommandHandler

When email is changed:

```csharp
// Detect email change
if (newEmail != identity.Email.Value)
{
    // Update email
    identity.UpdateEmail(newEmail, emailVerified: false);

    // Send verification for new email
    await mediator.Send(new SendEmailVerificationCommand(
        identity.Id,
        request.IpAddress));
}
```

---

## Background Job Integration

### Email Job Enqueuing

```csharp
backgroundJobService.Enqueue<IEmailService>(
    service => service.SendEmailAsync(
        new EmailMessage
        {
            To = email,
            ToName = userName,
            Subject = "Verify your email address",
            HtmlBody = htmlContent,
            PlainTextBody = plainTextContent
        },
        default),
    "email");  // Uses "email" queue
```

### Cleanup Job (Recurring)

```csharp
// Add recurring job to clean up expired tokens
backgroundJobService.AddOrUpdateRecurring<IEmailVerificationCleanupService>(
    "email-verification-cleanup",
    service => service.CleanupExpiredTokensAsync(default),
    "0 0 * * *"  // Daily at midnight
);
```

---

## Security Considerations

1. **Token Storage**: Store only SHA256 hash of token, not plaintext
2. **Code Brute Force**: Rate limit code verification attempts (5 attempts per token)
3. **Token Expiry**: Tokens expire after 1 hour
4. **Single Use**: Tokens are marked as used immediately upon verification
5. **Rate Limiting**: Max 3 verification emails per hour per user
6. **No Email Enumeration**: Return generic success message for non-existent users

---

## Implementation Tasks

### Phase 1: Domain & Infrastructure

1. [ ] Create `EmailVerificationToken` entity in Domain layer
2. [ ] Add new `ActivityType` enum values
3. [ ] Create `IEmailVerificationTokenRepository` interface
4. [ ] Implement EF Core configuration
5. [ ] Create database migration
6. [ ] Implement repository

### Phase 2: Application Layer

7. [ ] Create `SendEmailVerificationCommand` with handler and validator
8. [ ] Create `VerifyEmailCommand` with handler and validator
9. [ ] Create `ResendEmailVerificationCommand` with handler
10. [ ] Add email verification service for token generation

### Phase 3: Presentation Layer

11. [ ] Create verification endpoints in new `EmailVerificationEndpoints.cs`
12. [ ] Create endpoint extensions for route mapping
13. [ ] Add request/response DTOs

### Phase 4: Integration

14. [ ] Modify `ProvisionSsoUserCommandHandler` to trigger verification
15. [ ] Modify `UpdateUserProfileCommandHandler` for email changes
16. [ ] Add cleanup recurring job registration

### Phase 5: Testing

17. [ ] Unit tests for command handlers
18. [ ] Unit tests for token generation/validation
19. [ ] Integration tests for verification flow

---

## Configuration

### appsettings.json

```json
{
  "EmailVerification": {
    "TokenValidityMinutes": 60,
    "MaxResendsPerHour": 3,
    "MaxVerificationAttempts": 5,
    "VerificationBaseUrl": "https://app.example.com/verify-email"
  }
}
```

---

## API Flow Examples

### Flow 1: SSO Login Without EmailVerified

```
1. User authenticates via SSO
2. IdP returns email but email_verified=false
3. User provisioned with EmailVerified=false
4. SendEmailVerificationCommand enqueues email
5. User receives email with code: 123456
6. User calls POST /api/v1/auth/email/verify { "userIdentityId": "...", "code": "123456" }
7. EmailVerified set to true
```

### Flow 2: Email Change

```
1. Authenticated user calls PUT /api/v1/user/profile { "email": "new@example.com" }
2. Handler updates email, sets EmailVerified=false
3. SendEmailVerificationCommand enqueues email to new address
4. User verifies new email
5. EmailVerified set to true
```

### Flow 3: Link-Based Verification

```
1. Email contains link: https://app.example.com/verify-email?token=xxx&uid=yyy
2. Frontend extracts params, calls POST /api/v1/auth/email/verify
3. Backend validates token hash
4. EmailVerified set to true
```

---

## Related Documentation

- [Auto-Provisioning Architecture](../../docs/architecture/auto-provisioning.md)
- [Background Jobs Platform](../dotnet/background-jobs.md)
- [Notifications Platform](../dotnet/notifications.md)
