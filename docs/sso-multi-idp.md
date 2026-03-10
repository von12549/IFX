# SSO Multi-IdP Authentication

IFX supports dynamic multi-IdP (Identity Provider) authentication, allowing tokens from any configured identity provider to be validated and users to be auto-provisioned.

## Overview

The system accepts JWT access tokens from any IdP configured in the database `Idps` table. When a token arrives:

1. The issuer is extracted from the JWT
2. The IdP configuration is looked up from the database (cached for 5 minutes)
3. The token is validated against the IdP's OIDC configuration
4. If the user doesn't exist and `AutoProvisionEnabled = true`, a local user is created

## IdP Types and Role Assignment

| IdP Type | Description | Auto-Provisioned Role |
|----------|-------------|----------------------|
| `Internal` | Organization-managed IdP (e.g., corporate Cognito) | `User` |
| `External` | Third-party SSO provider (e.g., Google, Okta) | `SsoUser` |

## Configuration

IdPs are managed via the Admin API:

```http
# List all IdPs
GET /api/v1/idp

# Create IdP
POST /api/v1/idp
{
  "name": "Corporate SSO",
  "issuer": "https://cognito-idp.us-east-1.amazonaws.com/us-east-1_xxxxx",
  "authority": "https://cognito-idp.us-east-1.amazonaws.com/us-east-1_xxxxx",
  "idpType": "Internal",
  "enabled": true,
  "autoProvisionEnabled": true,
  "expectedAudiences": "[\"client-id\"]",
  "clockSkewSeconds": 300
}

# Update IdP
PUT /api/v1/idp/{idpId}
```

## Database Schema

The `Idps` table stores IdP configurations:

| Column | Type | Description |
|--------|------|-------------|
| `Id` | GUID | Primary key |
| `Name` | string | Display name |
| `Issuer` | string | OIDC issuer URL (unique) |
| `Authority` | string | OIDC authority URL |
| `IdpType` | string | `Internal` or `External` |
| `IsPrimary` | bool | Primary IdP for local auth (unique, max one) |
| `Enabled` | bool | Accept tokens from this IdP |
| `AutoProvisionEnabled` | bool | Auto-create users |
| `ExpectedAudiences` | JSON | Valid audience values |
| `AllowedAlgs` | JSON | Allowed signing algorithms |
| `ClockSkewSeconds` | int | Token expiry tolerance |

## Auto-Provisioning Flow

When a user authenticates via SSO for the first time:

1. Token validation succeeds
2. User lookup by `(Issuer, Subject)` returns no match
3. If `AutoProvisionEnabled = true`:
   - Extract email, name from JWT claims
   - Create `User` entity with role based on `IdpType`
   - Create `UserIdentity` linking to the IdP
   - Log registration activity
4. Add role claim to the authenticated principal

## Architecture

| Component | Layer | Purpose |
|-----------|-------|---------|
| `IdpConfigurationService` | ApiHost | Cache IdP configs, manage OIDC ConfigurationManagers |
| `DynamicJwtBearerEvents` | ApiHost | Dynamic token validation per issuer |
| `GetOrProvisionUserQuery` | Application | User lookup + auto-provisioning orchestration |
| `ProvisionSsoUserCommand` | Application | CQRS command for user auto-provisioning |
| `UserRoleClaimsTransformation` | ApiHost | Extract JWT claims, delegate to Application layer |

## See Also

- [Full Implementation Plan](plans/OIDC_SSO_MULTI_IDP_PLAN.md)
- [AWS Cognito Setup](AWS_COGNITO_SETUP.md)
- [Multi-IdP Migration](MULTI_IDP_MIGRATION_SUMMARY.md)
