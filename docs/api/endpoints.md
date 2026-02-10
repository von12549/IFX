# API Endpoints Reference

Base URL: `http://localhost:5000`

Swagger UI: `http://localhost:5000/swagger`

Hangfire Dashboard: `http://localhost:5000/hangfire` (Background Jobs Monitoring)

## OAuth 2.0 Endpoints (Recommended)

OAuth 2.0 Authorization Code flow with PKCE via Cognito Managed Login.

### Initiate Authorization
```http
GET /api/v1/auth/oauth/authorize
```

Query parameters:
- `redirect_uri` (optional) - Custom redirect URI
- `response_mode` (optional) - Set to `json` to return URL instead of redirecting (for SPAs)

Redirects to Cognito Hosted UI, or returns JSON if `response_mode=json`:
```json
{
  "success": true,
  "data": {
    "authorizationUrl": "https://cognito.../oauth2/authorize?...",
    "state": "abc123"
  }
}
```

### OAuth Callback
```http
GET /api/v1/auth/oauth/callback
```

Query parameters:
- `code` - Authorization code from IdP
- `state` - State parameter for CSRF protection
- `redirect_to` (optional) - Frontend URL to redirect with tokens

Returns tokens or redirects to frontend with tokens in URL fragment.

### Get User Info (Requires Auth)
```http
GET /api/v1/auth/oauth/userinfo
Authorization: Bearer <access_token>
```

Response:
```json
{
  "success": true,
  "data": {
    "sub": "abc123",
    "email": "user@example.com",
    "emailVerified": true,
    "name": "Test User",
    "givenName": "Test",
    "familyName": "User"
  }
}
```

### OAuth Logout
```http
GET /api/v1/auth/oauth/logout
```

Query parameters:
- `post_logout_redirect_uri` (optional) - URL to redirect after logout

Header (optional):
- `X-Id-Token` - ID token for logout hint

Redirects to Cognito logout endpoint.

### OAuth Logout Callback
```http
GET /api/v1/auth/oauth/logout-callback
```

Handles post-logout callback.

---

## Email Verification Endpoints

### Verify Email (Public)
```http
POST /api/v1/auth/email/verify
Content-Type: application/json

{
  "userIdentityId": "guid",
  "token": "verification-token",  // OR
  "code": "123456"                // 6-digit code
}
```

### Verify Email from Link (Public)
```http
GET /api/v1/auth/email/verify?token=xxx&uid=guid
```

### Send Verification Email (Requires Auth)
```http
POST /api/v1/user/email/send-verification
Authorization: Bearer <access_token>
```

Response:
```json
{
  "success": true,
  "data": {
    "message": "Verification email sent successfully",
    "expiresAt": "2026-01-15T12:00:00Z"
  }
}
```

### Resend Verification Email (Requires Auth)
```http
POST /api/v1/user/email/resend-verification
Authorization: Bearer <access_token>
```

Rate limited to 3 per hour.

### Get Verification Status (Requires Auth)
```http
GET /api/v1/user/email/verification-status
Authorization: Bearer <access_token>
```

Response:
```json
{
  "success": true,
  "data": {
    "email": "user@example.com",
    "emailVerified": true
  }
}
```

---

## Legacy Authentication Endpoints

> **Note**: Direct login is deprecated. Use OAuth 2.0 endpoints above for new integrations.

### Register User
```http
POST /api/v1/auth/register
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "Test@12345",
  "username": "testuser",
  "firstName": "Test",
  "lastName": "User",
  "birthDate": "1990-01-01",
  "phoneNumber": "+61412345678"
}
```

### Confirm Registration
```http
POST /api/v1/auth/confirm
Content-Type: application/json

{
  "email": "user@example.com",
  "confirmationCode": "123456"
}
```

### Login
```http
POST /api/v1/auth/login
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "Test@12345"
}
```

Response:
```json
{
  "success": true,
  "data": {
    "accessToken": "eyJraWQiOiI...",
    "idToken": "eyJraWQiOiJ...",
    "refreshToken": "eyJjdHkiOi...",
    "expiresIn": 3600,
    "user": { ... }
  }
}
```

### Logout (Requires Auth)
```http
POST /api/v1/auth/logout
Authorization: Bearer <access_token>
```

### Refresh Token
```http
POST /api/v1/auth/refresh
Content-Type: application/json

{
  "email": "user@example.com",
  "refreshToken": "eyJjdHkiOi..."
}
```

### Revoke Token
```http
POST /api/v1/auth/revoke
Content-Type: application/json

{
  "refreshToken": "eyJjdHkiOi..."
}
```

## User Endpoints (Requires Auth)

### Get Profile
```http
GET /api/v1/user/profile
Authorization: Bearer <access_token>
```

### Update Profile
```http
PUT /api/v1/user/profile
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "firstName": "Updated",
  "lastName": "Name",
  "phoneNumber": "+61412345679"
}
```

### Get Login History
```http
GET /api/v1/user/login-history?page=1&pageSize=20
Authorization: Bearer <access_token>
```

### Get Activity Log
```http
GET /api/v1/user/activity-log?page=1&pageSize=50
Authorization: Bearer <access_token>
```

### Sync Profile from Cognito
```http
POST /api/v1/user/sync
Authorization: Bearer <access_token>
```

## Admin Endpoints (Requires Admin Role)

### Get All Users
```http
GET /api/v1/usermanagement/users?page=1&pageSize=20
Authorization: Bearer <admin_token>
```

### Update User (Admin)
```http
PUT /api/v1/usermanagement/users/{userId}
Authorization: Bearer <admin_token>
Content-Type: application/json

{
  "firstName": "Updated",
  "lastName": "Name"
}
```

### Get All Roles
```http
GET /api/v1/role
Authorization: Bearer <admin_token>
```

### Add Role
```http
POST /api/v1/role
Authorization: Bearer <admin_token>
Content-Type: application/json

{
  "roleName": "Manager",
  "description": "Manager role"
}
```

### Update Role
```http
PUT /api/v1/role/{roleId}
Authorization: Bearer <admin_token>
Content-Type: application/json

{
  "roleName": "UpdatedManager",
  "description": "Updated description"
}
```

### Get All Identity Providers
```http
GET /api/v1/idp
Authorization: Bearer <admin_token>
```

### Create Identity Provider
```http
POST /api/v1/idp
Authorization: Bearer <admin_token>
Content-Type: application/json

{
  "name": "Google SSO",
  "issuer": "https://accounts.google.com",
  "authority": "https://accounts.google.com",
  "description": "Google Single Sign-On",
  "enabled": true
}
```

### Update Identity Provider
```http
PUT /api/v1/idp/{idpId}
Authorization: Bearer <admin_token>
Content-Type: application/json

{
  "name": "Google SSO Updated",
  "enabled": false
}
```

## Health Endpoints

### Detailed Health Check
```http
GET /health
```

### Readiness Probe
```http
GET /health/ready
```
