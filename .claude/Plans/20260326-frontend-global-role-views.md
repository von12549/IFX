# Frontend Global Role Views Plan

**Date:** 2026-03-26
**Branch:** `feature/frontend-global-role-views`
**Base:** `main`
**Status:** Planning

---

## Goal

Differentiate the frontend UI for Tenant-only users vs GlobalRole users. GlobalRole users
(PlatformAdmin, PlatformSupport, PlatformAuditor) see a dual-section layout showing both
their current tenant's data and cross-tenant data. Tenant-only users see a simplified view
scoped to their tenant.

---

## Two User Archetypes

| | Tenant-only User | GlobalRole User |
|---|---|---|
| Context | One tenant, tenant-scoped RBAC | No tenant (or tenant selected via header), GlobalRole |
| Tenant Page | Select/view own tenant only | Full cross-tenant CRUD |
| Permission Page | Tenant permissions only (hide Platform.*) | Two sections: tenant + platform |
| Policy Page | Tenant policies, grouped by resource | Two sections: tenant + platform, grouped by resource |
| Role Page | Current tenant's roles | Three sections: GlobalRoles (read-only), current tenant, other tenants |
| User / RoleGroup / Department Page | Current tenant only | Two sections: current tenant + other tenants grouped |

---

## Phase 1 — Foundation (no new backend endpoints)

Deliver visible differentiation using data already available or cheaply added.

### 1.1 Backend: Expose GlobalRoles in UserProfile

**File:** `src/Modules/Auth/IFX.Modules.Auth.Application/Users/Queries/GetUserProfile/GetUserProfileQueryHandler.cs`

- Add `GlobalRoles: IReadOnlyList<string>` to `UserProfileDto`
- Query handler loads `GlobalRoles` from `ICurrentUser.GlobalRoles`

**File:** `src/Modules/Auth/IFX.Modules.Auth.Application/Users/DTOs/UserProfileDto.cs`

- Add `IReadOnlyList<string> GlobalRoles { get; init; }`

### 1.2 Backend: Add Scope to PermissionDto

Currently permissions have no explicit scope indicator. Platform permissions use the
naming convention `Platform.*` but relying on string prefix is fragile.

**Option A (recommended):** Add `Scope` enum value to `PermissionDto`:
```csharp
public string Scope { get; init; } // "Tenant" | "Platform"
```
Derive from the permission name: `Platform.*` → "Platform", else → "Tenant".

**Option B:** Frontend filters by `name.startsWith("Platform.")`.

Decision: Use Option A — adds one field, makes intent explicit and survives renames.

### 1.3 Frontend: AuthContext — add GlobalRole awareness

**File:** `src/Frontend/IFX.FrontEnd/src/contexts/AuthContext.tsx`

Add to `AuthContextValue`:
```ts
globalRoles: string[]           // e.g. ["PlatformAdmin"]
isGlobalUser: boolean           // globalRoles.length > 0
isGlobalAdmin: boolean          // globalRoles.includes("PlatformAdmin")
hasGlobalRole: (role: string) => boolean
```

Derive from `user.globalRoles` already loaded in profile.

**File:** `src/Frontend/IFX.FrontEnd/src/types/api.ts`

Add to `UserProfileDto`:
```ts
globalRoles: string[]
```

### 1.4 Frontend: Sidebar — conditional platform section

**File:** `src/Frontend/IFX.FrontEnd/src/components/layout/Sidebar.tsx`

- Show a "Platform" nav section for GlobalRole users containing:
  - Global Roles (read-only list page)
  - Platform Policies → links to `/policies` (platform tab active)
  - Platform Permissions → links to `/permissions` (platform tab active)
- Tenant-only users see no "Platform" section

### 1.5 Frontend: PermissionManagementPage — split by scope

**File:** `src/Frontend/IFX.FrontEnd/src/pages/PermissionManagementPage.tsx`

- **Tenant-only users:** filter out `scope === "Platform"` permissions — show only tenant-scoped ones
- **GlobalRole users:** show two tabs/sections:
  - "Tenant Permissions" — scope === "Tenant"
  - "Platform Permissions" — scope === "Platform"

### 1.6 Frontend: PolicyManagementPage — group by resource type + platform section

**File:** `src/Frontend/IFX.FrontEnd/src/pages/PolicyManagementPage.tsx`

**Common change (all users):** Group policies by `resourceType` within each section.

**GlobalRole users only:** Show two sections:
- "Tenant Policies" — `isPlatformDefault === false` (current tenant, grouped by resourceType)
- "Platform Policies" — call `GET /api/v1/platform/policy` (already exists), grouped by resourceType

### 1.7 Frontend: TenantManagementPage — restrict for tenant-only users

**File:** `src/Frontend/IFX.FrontEnd/src/pages/TenantManagementPage.tsx`

- **Tenant-only users:** Show only their own tenant (filtered from the list), hide create/delete buttons.
  Effectively read-only "my tenant" view.
- **GlobalRole users:** Unchanged (full CRUD).

### 1.8 Frontend: RoleManagementPage — GlobalRole section (read-only)

**File:** `src/Frontend/IFX.FrontEnd/src/pages/RoleManagementPage.tsx`

**GlobalRole users only:** Add a "Global Roles" section above the existing tenant roles section.
- Calls `GET /api/v1/platform/globalroles` (already exists)
- Read-only — no create/edit/delete for now
- Displays name, description

**Phase 2 handles** the "other tenants grouped by tenant" section.

---

## Phase 2 — Cross-Tenant Views (new backend endpoints)

Requires new backend query endpoints that return data across all tenants.
Each endpoint is protected by `IsGlobalAdmin` or `PlatformSupport` ABAC policy.

### 2.1 Backend: Cross-tenant query endpoints

New endpoints under `GET /api/v1/platform/`:

| Endpoint | Returns | DTO |
|----------|---------|-----|
| `GET /api/v1/platform/users` | All users across tenants | `CrossTenantUsersDto` (grouped by tenant) |
| `GET /api/v1/platform/roles` | All roles across tenants | `CrossTenantRolesDto` |
| `GET /api/v1/platform/rolegroups` | All role groups across tenants | `CrossTenantRoleGroupsDto` |
| `GET /api/v1/platform/departments` | All departments across tenants | `CrossTenantDepartmentsDto` |

**Response shape:**
```json
{
  "tenants": [
    {
      "tenantId": "...",
      "tenantName": "Acme Corp",
      "items": [ ... ]
    }
  ]
}
```

Each handler:
- No `X-Tenant-Id` filter applied
- Requires GlobalRole (checked via `ICurrentUser.GlobalRoles.Count > 0`)
- Returns all active records grouped by tenantId

### 2.2 Frontend: Dual-section layout components

Introduce a reusable `CrossTenantSection` component:
```tsx
<CrossTenantSection
  title="Other Tenants"
  groups={crossTenantData.tenants}
  renderGroup={(tenant) => <TenantGroup key={tenant.tenantId} tenant={tenant} />}
/>
```

### 2.3 Frontend: Update pages with cross-tenant section

Each page gains a second section below the existing content:

**UserManagementPage:**
- Section 1: Current tenant users (unchanged)
- Section 2: Cross-tenant users grouped by tenant (read-only rows)

**RoleManagementPage:**
- Section 1: Global Roles (read-only) — from Phase 1
- Section 2: Current tenant roles (unchanged, with CRUD)
- Section 3: Other tenant roles grouped by tenant (read-only)

**RoleGroupManagementPage:**
- Section 1: Current tenant role groups (unchanged)
- Section 2: Cross-tenant role groups grouped by tenant (read-only)

**DepartmentManagementPage:**
- Section 1: Current tenant departments (unchanged)
- Section 2: Cross-tenant departments grouped by tenant (read-only)

Cross-tenant sections are **read-only** (no create/edit/delete). Navigating to a cross-tenant
item can be done by switching the tenant switcher to that tenant first.

---

## Implementation Order

### Phase 1
1. Backend: `UserProfileDto` + `GetUserProfileQueryHandler` — add `GlobalRoles`
2. Backend: `PermissionDto` — add `Scope` field
3. Frontend: `types/api.ts` — add `globalRoles` to `UserProfileDto`, `scope` to `PermissionDto`
4. Frontend: `AuthContext` — add `globalRoles`, `isGlobalUser`, `isGlobalAdmin`, `hasGlobalRole`
5. Frontend: `Sidebar` — platform nav section for GlobalRole users
6. Frontend: `PermissionManagementPage` — split by scope
7. Frontend: `PolicyManagementPage` — group by resourceType + platform section
8. Frontend: `TenantManagementPage` — restrict for tenant-only users
9. Frontend: `RoleManagementPage` — GlobalRoles section (read-only)
10. Tests: update profile query handler test; add frontend component tests

### Phase 2
11. Backend: Cross-tenant query handlers + DTOs (Users, Roles, RoleGroups, Departments)
12. Backend: Platform controller extensions
13. Frontend: `CrossTenantSection` component
14. Frontend: Update UserManagementPage, RoleManagementPage, RoleGroupManagementPage, DepartmentManagementPage

---

## Open Questions / Decisions

**Q1: Where does the tenant switcher live for GlobalRole users?**
GlobalRole users can set `X-Tenant-Id` to browse a specific tenant's data in Section 1.
The existing TenantSwitcher in the header is used as-is — no change needed.

**Q2: Are cross-tenant sections always visible or toggled?**
Recommended: default collapsed / lazy-loaded behind an "Expand" button.
Cross-tenant queries can be expensive; don't fire them on page load.

**Q3: Permission scope — naming convention vs DB field?**
Decided: Add `Scope` string to `PermissionDto` (derived at query time), not a new DB column.
The permission name already encodes scope (`Platform.*`); the DTO exposes it explicitly.

**Q4: Can a GlobalRole user perform write actions on cross-tenant data?**
Phase 2 cross-tenant sections are read-only. Write access requires switching to the target
tenant via the tenant switcher — then Section 1 shows that tenant's data with full CRUD.

**Q5: Role Management — three sections is a lot of vertical space.**
Consider a tab layout: "Global Roles" | "Current Tenant" | "All Tenants" (Phase 2).

---

## What Does NOT Change

- Existing tenant-scoped CRUD for all pages — no behavioral change for tenant users
- API client `X-Tenant-Id` header injection — unchanged
- Tenant switcher behavior — unchanged
- RBAC/ABAC enforcement — backend still gates all actions
- Auth flow (login, token refresh, logout) — unchanged
