# AWS Cognito Integration

## Purpose
AWS Cognito configuration, authentication flows, and health checks.

---

## Configuration

```json
{
  "CognitoSettings": {
    "UserPoolId": "ap-southeast-2_adW7gmF5P",
    "ClientId": "YOUR_CLIENT_ID",
    "ClientSecret": "YOUR_CLIENT_SECRET",
    "Region": "ap-southeast-2"
  }
}
```

See `docs/AWS_COGNITO_SETUP.md` for detailed setup instructions.

---

## Authentication Flows

### Registration
1. `CognitoService.SignUpAsync()` creates user in Cognito
2. Cognito sends verification email
3. User created in database with `IsActive=false`

### Confirmation
1. User submits confirmation code
2. `CognitoService.ConfirmSignUpAsync()` verifies code
3. User activated in database (`IsActive=true`)

### Login
1. `CognitoService.AuthenticateAsync()` validates credentials
2. Cognito returns JWT tokens (Access, ID, Refresh)
3. Extract `iss` (issuer) and `sub` (subject) from ID token
4. Look up user by `(Issuer, Subject)` tuple

### Token Refresh
1. `CognitoService.RefreshTokenAsync()` with refresh token
2. Returns new access token

### Logout
1. `CognitoService.GlobalSignOutAsync()` invalidates all sessions
2. Log logout event in database

---

## JWT Validation

Configured in `AuthenticationConfiguration.cs`:

```csharp
services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.Authority = $"https://cognito-idp.{region}.amazonaws.com/{userPoolId}";
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = false,
            ValidateLifetime = true
        };
    });
```

**Note:** Issuer validation supports both with/without trailing slash.

---

## Claims Transformation

`UserRoleClaimsTransformation` adds database role to JWT:

1. Extract `iss` and `sub` from JWT claims
2. Query database for user by `(Issuer, Subject)`
3. Add `ClaimTypes.Role` claim with user's role
4. Enables `RequireAuthorization(policy => policy.RequireRole("Admin"))`

---

## Health Check

`CognitoHealthCheck` verifies Cognito availability:

- Calls `DescribeUserPool` API
- Returns Healthy/Degraded/Unhealthy
- Tags: `aws`, `cognito`, `authentication`

---

## Seeded IdP

Default Cognito IdP seeded via migration:

| Field | Value |
|-------|-------|
| Name | IFX Cognito |
| Issuer | `https://cognito-idp.ap-southeast-2.amazonaws.com/ap-southeast-2_adW7gmF5P` |
| Enabled | true |
| AutoProvisionEnabled | true |
