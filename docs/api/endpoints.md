# API Endpoints Reference

Base URL: `http://localhost:5000`

Swagger UI: `http://localhost:5000/swagger`

## Authentication Endpoints

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
