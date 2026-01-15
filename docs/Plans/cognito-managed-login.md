# Plan: Cognito Managed Login Implementation

## Selected Approach: Option B - Cognito Managed Login

**User Decision:** Replace SDK-based auth with OIDC Authorization Code flow using Cognito Hosted UI.

---

## What is Cognito Managed Login?

Cognito Managed Login (Hosted UI) provides:
- Hosted login page: `https://<domain>.auth.<region>.amazoncognito.com/login`
- OAuth 2.0 Authorization Code Grant with PKCE
- Token endpoint: `/oauth2/token`
- UserInfo endpoint: `/oauth2/userInfo` (works with access tokens!)
- Built-in IdP federation (Google, Facebook, SAML, OIDC)
- Customizable UI branding

**Key Benefit:** Access tokens from Managed Login CAN be used with `/oauth2/userInfo` endpoint, solving our auto-provisioning problem.

---

## Architecture Change Overview

### Current Flow (SDK-based)
```
Client → POST /api/v1/auth/login (username/password)
       → CognitoService.InitiateAuthAsync()
       → Returns tokens directly
```

### New Flow (Managed Login)
```
Client → GET /api/v1/auth/authorize
       → Redirect to Cognito Hosted UI
       → User logs in at Cognito
       → Redirect back with authorization code
       → POST /api/v1/auth/callback (exchange code for tokens)
       → /oauth2/userInfo available for user attributes
```

---

## Implementation Plan

### Phase 1: AWS Cognito Configuration

**Prerequisites (Manual AWS Console / Terraform):**

#### 1. Configure User Pool Domain
```
AWS Console → Cognito → User Pools → [Your Pool] → App Integration → Domain

Option A: Cognito domain
  - Domain prefix: myapp
  - Full URL: https://myapp.auth.ap-southeast-2.amazoncognito.com

Option B: Custom domain (requires ACM certificate)
  - Domain: auth.yourdomain.com
```

#### 2. Configure App Client OAuth Settings
```
AWS Console → Cognito → User Pools → [Your Pool] → App Integration → App clients → [Your Client]

Hosted UI Settings:
  - Allowed callback URLs:
    - https://localhost:5001/api/v1/auth/oauth/callback (development)
    - https://api.yourdomain.com/api/v1/auth/oauth/callback (production)

  - Allowed sign-out URLs:
    - https://localhost:5001/api/v1/auth/oauth/logout-callback (development)
    - https://api.yourdomain.com/api/v1/auth/oauth/logout-callback (production)

  - OAuth 2.0 grant types: ✓ Authorization code grant
  - OpenID Connect scopes: ✓ openid, ✓ email, ✓ profile
```

#### 3. Note Your Configuration Values
```
Domain:       myapp.auth.ap-southeast-2.amazoncognito.com
ClientId:     (from App client settings)
ClientSecret: (from App client settings - if confidential client)
Region:       ap-southeast-2
UserPoolId:   ap-southeast-2_XXXXXXXX
```

### Phase 2: Backend Implementation

#### New Files to Create

| File | Purpose |
|------|---------|
| `Application/Interfaces/IOidcAuthService.cs` | OIDC auth service interface |
| `Infrastructure/Services/CognitoOidcService.cs` | Cognito OIDC implementation |
| `Infrastructure/Configuration/CognitoOidcSettings.cs` | OAuth configuration |
| `Presentation/Endpoints/OAuthEndpoints.cs` | OAuth flow endpoints |
| `Application/Commands/ExchangeAuthCode/ExchangeAuthCodeCommand.cs` | Code exchange command |
| `Application/Commands/ExchangeAuthCode/ExchangeAuthCodeCommandHandler.cs` | Handler |

#### Files to Modify

| File | Change |
|------|--------|
| `CognitoSettings.cs` | Add Domain, CallbackUrl, OAuth scopes |
| `DependencyInjection.cs` | Register OIDC service |
| `AuthEndpoints.cs` | Add authorize/callback endpoints or delegate to OAuthEndpoints |
| `GetOrProvisionUserQueryHandler.cs` | Use /userinfo for provisioning |
| `UserRoleClaimsTransformation.cs` | Call /userinfo when claims missing |

### Phase 3: Detailed Implementation Steps

#### Step 1: Add Configuration
```csharp
// CognitoOidcSettings.cs
public class CognitoOidcSettings
{
    public string Domain { get; set; }           // myapp.auth.ap-southeast-2.amazoncognito.com
    public string ClientId { get; set; }
    public string ClientSecret { get; set; }
    public string CallbackUrl { get; set; }      // https://api.example.com/api/v1/auth/callback
    public string LogoutCallbackUrl { get; set; }
    public string[] Scopes { get; set; } = ["openid", "email", "profile"];
}
```

#### Step 2: Add IOidcAuthService Interface
```csharp
public interface IOidcAuthService
{
    string BuildAuthorizationUrl(string state, string codeChallenge);
    Task<OidcTokenResult> ExchangeCodeForTokensAsync(string code, string codeVerifier);
    Task<OidcUserInfo> GetUserInfoAsync(string accessToken);
    string BuildLogoutUrl(string idTokenHint);
}
```

#### Step 3: Implement CognitoOidcService
- `BuildAuthorizationUrl`: Construct Cognito authorize URL with PKCE
- `ExchangeCodeForTokensAsync`: POST to `/oauth2/token` with code
- `GetUserInfoAsync`: GET `/oauth2/userInfo` with Bearer token
- `BuildLogoutUrl`: Construct logout URL

#### Step 4: Add OAuth Endpoints
```csharp
// OAuthEndpoints.cs
public static class OAuthEndpoints
{
    public static void Map(IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/v1/auth/oauth");

        group.MapGet("/authorize", HandleAuthorize);    // Redirects to Cognito
        group.MapGet("/callback", HandleCallback);      // Exchanges code for tokens
        group.MapGet("/logout", HandleLogout);          // Redirects to Cognito logout
    }
}
```

#### Step 5: Update Auto-Provisioning
- Modify `GetOrProvisionUserQueryHandler` to call `/oauth2/userInfo`
- Extract email, email_verified, name from userinfo response
- Use for auto-provisioning

### Phase 4: Migration Strategy (Selected: Parallel)

**Decision:** Keep old `/login` endpoint for backward compatibility.

- Keep existing SDK-based `/login`, `/register`, `/confirm` endpoints
- Add new `/oauth/*` endpoints for Managed Login flow
- Mark old `/login` as `[Obsolete]` with deprecation notice
- Clients can migrate at their own pace

---

## Final API Design

### New OAuth Endpoints

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/api/v1/auth/oauth/authorize` | Start OAuth flow, redirect to Cognito |
| GET | `/api/v1/auth/oauth/callback` | Handle callback, exchange code, return JSON |
| POST | `/api/v1/auth/oauth/logout` | Logout via Cognito |
| GET | `/api/v1/auth/oauth/userinfo` | Get user info (proxies to Cognito) |

### Existing Endpoints (Kept for Compatibility)

| Endpoint | Status |
|----------|--------|
| `POST /api/v1/auth/login` | **Deprecated** - still works, use OAuth flow for new integrations |
| `POST /api/v1/auth/register` | Keep (Cognito SignUp still works) |
| `POST /api/v1/auth/confirm` | Keep (Cognito ConfirmSignUp still works) |
| `POST /api/v1/auth/refresh` | Keep (works with both flows) |
| `POST /api/v1/auth/logout` | Keep (SDK-based logout) |

---

## Token Response Format (Selected: JSON)

**Decision:** Return tokens as JSON response from callback.

```json
// GET /api/v1/auth/oauth/callback?code=xxx&state=yyy
// Response:
{
  "accessToken": "eyJ...",
  "idToken": "eyJ...",
  "refreshToken": "xxx",
  "expiresIn": 3600,
  "tokenType": "Bearer"
}
```

### Client Flow with JSON Response
```
1. Frontend generates state + PKCE (code_verifier, code_challenge)
2. Frontend stores state + code_verifier in sessionStorage
3. Frontend redirects user to: GET /api/v1/auth/oauth/authorize?state=xxx&code_challenge=yyy
4. Backend redirects to: Cognito Hosted UI
5. User authenticates at Cognito
6. Cognito redirects to: /api/v1/auth/oauth/callback?code=xxx&state=yyy
7. Backend exchanges code for tokens (needs code_verifier from client)
8. Backend returns JSON with tokens
9. Frontend stores tokens and redirects to app
```

**Note:** Since PKCE code_verifier is generated client-side, the callback needs to either:
- Option A: Client handles callback page, sends code + code_verifier to backend
- Option B: Backend generates and stores PKCE (simpler for this architecture)

**Recommended:** Backend generates PKCE, stores in short-lived cache keyed by state.

---

## Federation (Selected: Cognito Only)

**Decision:** No federated IdPs for now, only Cognito native authentication.

Future federation can be added later by:
1. Configuring IdP in Cognito console
2. Adding identity_provider parameter to authorize URL
3. No backend code changes needed

---

## Security Considerations

1. **PKCE Required**: Backend generates code_verifier/code_challenge
2. **State Parameter**: Prevent CSRF attacks, link to PKCE verifier
3. **Short-lived State Cache**: Store PKCE verifier for 5 minutes max
4. **Token Validation**: Continue validating JWTs as before
5. **HTTPS Only**: All OAuth endpoints require HTTPS

---

## Testing Plan

1. Unit tests for `CognitoOidcService`
2. Integration tests for OAuth flow
3. Manual testing with Cognito Hosted UI
4. Verify backward compatibility with old `/login` endpoint

---

## Database Analysis

### Current Idp Table Schema
The `Idp` entity already has:
- `Authority` - OIDC authority URL (for token validation)
- `LoginUrl` - Custom login URL
- `Issuer` - Token issuer URL

### Database Changes Required: **NONE**

**Rationale:**
1. Cognito OAuth domain is a **User Pool level setting**, not per-IdP
2. The domain (e.g., `myapp.auth.ap-southeast-2.amazoncognito.com`) is for the entire Cognito User Pool
3. It should be stored in **application configuration** (`CognitoOidcSettings`), not database
4. The `Idp` table is for multi-IdP SSO support (external IdPs), not OAuth flow configuration

**Future consideration:** If we later want to support OAuth flows for multiple Cognito User Pools or external OAuth providers, we could add:
- `OAuthDomain` column - OAuth authorization server domain
- `UserInfoEndpoint` column - OIDC userinfo endpoint URL

For now, these are NOT needed.

---

## Summary of Files

### New Files
| Path | Purpose |
|------|---------|
| `Infrastructure/Configuration/CognitoOidcSettings.cs` | OAuth settings (Domain, ClientId, Scopes) |
| `Application/Interfaces/IOidcAuthService.cs` | Service interface |
| `Infrastructure/Services/CognitoOidcService.cs` | OIDC implementation |
| `Presentation/Endpoints/OAuthEndpoints.cs` | OAuth endpoints |

### Modified Files
| Path | Change |
|------|--------|
| `appsettings.json` | Add CognitoOidc section with Domain |
| `DependencyInjection.cs` | Register IOidcAuthService |
| `AuthEndpoints.cs` | Add deprecation notice to /login |
| `GetOrProvisionUserQueryHandler.cs` | Use /userinfo for auto-provisioning |
| `UserRoleClaimsTransformation.cs` | Call /userinfo when claims missing |

### Database Migrations: **NONE REQUIRED**
