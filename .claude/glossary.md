# Glossary

## Purpose
Defines terms, abbreviations, and naming conventions used in this codebase.

---

## Core Concepts

| Term | Definition |
|------|------------|
| **User** | Core identity entity, independent of IdP |
| **UserIdentity** | IdP-specific identity data linked to a User |
| **Tenant** | Top-level organisational unit. Roles, RoleGroups, Idps, and Departments all belong to a tenant |
| **Department** | Sub-unit within a tenant; users can be assigned to departments |
| **PrimaryTenantId** | FK on User pointing to the user's default/primary tenant |
| **selectedTenantId** | Frontend (AuthContext) — the currently active tenant; drives all management page list queries |
| **IdP** | Identity Provider (e.g., AWS Cognito, Google) |
| **IdpType** | Classification of IdP: `Internal` (org-managed) or `External` (third-party SSO) |
| **IsPrimary** | Flag indicating the primary IdP for local authentication (only one can be primary) |
| **Subject** | Unique identifier assigned by IdP (the `sub` claim) |
| **Issuer** | URL identifying the IdP (the `iss` claim) |

---

## Abbreviations

| Abbrev | Meaning |
|--------|---------|
| CQRS | Command Query Responsibility Segregation |
| DDD | Domain-Driven Design |
| DTO | Data Transfer Object |
| IdP | Identity Provider |
| JWT | JSON Web Token |
| JWKS | JSON Web Key Set |
| SSO | Single Sign-On |

---

## Project Naming

| Pattern | Example |
|---------|---------|
| Module namespace | `IFX.Modules.Auth.{Layer}` |
| Command | `RegisterUserCommand` |
| Query | `GetUserProfileQuery` |
| Handler | `RegisterUserCommandHandler` |
| Validator | `RegisterUserCommandValidator` |
| Repository | `IUserRepository` / `UserRepository` |
| Endpoint class | `AuthEndpoints` |
| DTO | `UserProfileDto` |

---

## Database

| Term | Definition |
|------|------------|
| Schema | `auth` (all tables use this schema) |
| Aggregate Root | Entity that owns other entities (User owns UserIdentities) |
| Owned Entity | Entity stored in same table as owner (DeviceInfo in LoginEvent) |

---

## Authentication

| Term | Definition |
|------|------------|
| Access Token | Short-lived JWT for API access |
| Refresh Token | Long-lived token to obtain new access tokens |
| Claims Transformation | Process of adding database role to JWT claims |
