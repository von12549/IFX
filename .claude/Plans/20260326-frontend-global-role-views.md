# Frontend Global Role Views Plan

**Date:** 2026-03-26
**Branch:** `feature/frontend-global-role-views`
**Base:** `main`
**Status:** Ready to Implement

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
| Tenant Page | Read-only view of own tenant (no create/delete) | Full cross-tenant CRUD |
| Permission Page | Tenant permissions only — Platform.* hidden | Tabs: Tenant Permissions / Platform Permissions |
| Policy Page | Tenant policies grouped by resource type | Tabs: Tenant Policies / Platform Policies, each grouped by resource type |
| Role Page | Current tenant's roles only | Tabs: Global Roles (read-only) / This Tenant / All Tenants (Phase 2) |
| User / RoleGroup / Department Page | Current tenant only | Current tenant + lazy-loaded cross-tenant section |

---

## Decisions (all open questions resolved)

**D1 — Tenant switcher for GlobalRole users:**
The existing `TenantSwitcher` in the header is unchanged. GlobalRole users use it to set the
current tenant context for Section 1 (same-tenant data). If no tenant is selected, show a
`TenantRequiredBanner` prompting them to pick one — do not silently show empty tables.

**D2 — Cross-tenant sections: lazy-loaded, collapsed by default:**
Cross-tenant queries can be expensive. The "All Tenants" section is **not loaded on page mount**.
It renders a collapsed `<ExpandableCrossTenantSection>` with a "Load all tenants" button.
Data fetches only when the user expands it. This avoids page-load latency for GlobalRole users
who only care about the current tenant's data.

**D3 — Permission scope: backend `Scope` field derived at query time (no DB change):**
`PermissionDto` gains a `Scope: "Tenant" | "Platform"` string field. The query handler derives
it from the permission name: `Platform.*` → `"Platform"`, anything else → `"Tenant"`.
No migration needed. Every consumer (permission page, role detail permission picker, future
global role management) benefits automatically.

**D4 — Cross-tenant sections are read-only:**
Write actions on cross-tenant data require switching the tenant switcher to that tenant first,
then Section 1 (current tenant) shows full CRUD. No special cross-tenant write path needed.

**D5 — Role Management uses a tab layout (not stacked sections):**
Three stacked sections is too much vertical space. Use tabs:
`"Global Roles" | "This Tenant" | "All Tenants"`.
- "Global Roles" tab is only shown to GlobalRole users.
- "All Tenants" tab is Phase 2 (lazy-loaded behind expand).
- Tenant-only users see only "This Tenant" with no tabs — no visual change for them.

**D6 — Sidebar hides platform links for tenant-only users (proactive, not just 403 toast):**
Platform nav items (`/globalroles`, platform policy/permission tabs) are conditionally rendered
in the Sidebar based on `isGlobalUser`. Tenant-only users never see these links and cannot
accidentally navigate to them. Backend 403 remains as the safety net, but the UI does not
rely on it as the primary guard.

**D7 — RoleDetailPage permission picker filters by scope:**
When assigning permissions to a tenant role, the picker only shows `scope === "Tenant"`
permissions. Platform permissions are never assignable to a tenant role. This is a free
benefit of D3 — no extra API call needed.

---

## Phase 1 — Foundation (no new backend endpoints)

### 1.1 Backend: Expose GlobalRoles in UserProfile

**Files:**
- `src/Modules/Auth/IFX.Modules.Auth.Application/Users/DTOs/UserProfileDto.cs`
  — add `IReadOnlyList<string> GlobalRoles { get; init; }`
- `src/Modules/Auth/IFX.Modules.Auth.Application/Users/Queries/GetUserProfile/GetUserProfileQueryHandler.cs`
  — map `GlobalRoles = currentUser.GlobalRoles.ToList()`

### 1.2 Backend: Add Scope to PermissionDto

**Files:**
- `src/Modules/Auth/IFX.Modules.Auth.Application/Authorization/Permissions/DTOs/PermissionDto.cs`
  — add `public string Scope { get; init; }`
- `src/Modules/Auth/IFX.Modules.Auth.Application/Authorization/Permissions/Queries/GetAllPermissions/GetAllPermissionsQueryHandler.cs`
  — derive scope during mapping:
  ```csharp
  Scope = p.Name.StartsWith("Platform.", StringComparison.OrdinalIgnoreCase)
      ? "Platform" : "Tenant"
  ```

### 1.3 Frontend: Update types

**File:** `src/Frontend/IFX.FrontEnd/src/types/api.ts`

```ts
// UserProfileDto
globalRoles: string[]          // new

// PermissionDto
scope: 'Tenant' | 'Platform'   // new
```

### 1.4 Frontend: AuthContext — GlobalRole helpers

**File:** `src/Frontend/IFX.FrontEnd/src/contexts/AuthContext.tsx`

Add to `AuthContextValue`:
```ts
globalRoles: string[]                     // from user.globalRoles
isGlobalUser: boolean                     // globalRoles.length > 0
isGlobalAdmin: boolean                    // globalRoles.includes('PlatformAdmin')
hasGlobalRole: (role: string) => boolean  // globalRoles.includes(role)
```

Derive on every `user` update. Memoize with `useMemo`.

### 1.5 Frontend: TenantRequiredBanner component

**File:** `src/Frontend/IFX.FrontEnd/src/components/TenantRequiredBanner.tsx`  *(new)*

Shown at the top of any page when `isGlobalUser && !selectedTenantId`:
```tsx
<Alert>
  You have no tenant selected. Use the tenant switcher in the header
  to select a tenant and view its data.
</Alert>
```

Used on: UserManagementPage, RoleManagementPage, RoleGroupManagementPage,
DepartmentManagementPage, PolicyManagementPage (Section 1 of each).

### 1.6 Frontend: Sidebar — conditional platform section

**File:** `src/Frontend/IFX.FrontEnd/src/components/layout/Sidebar.tsx`

Add a "Platform" group **only when `isGlobalUser`**:
```
▸ Platform                        ← only visible to GlobalRole users
    Global Roles          /globalroles
    Platform Policies     /policies?tab=platform
    Platform Permissions  /permissions?tab=platform
```

The standard nav links remain unchanged for all users. Tenant-only users never see the
Platform group (D6).

### 1.7 Frontend: New GlobalRolesPage (read-only)

**File:** `src/Frontend/IFX.FrontEnd/src/pages/GlobalRolesPage.tsx`  *(new)*
**Route:** `/globalroles`  — only reachable if `isGlobalUser` (Sidebar hides it otherwise)

- Calls `GET /api/v1/platform/globalroles` (already exists)
- Displays name, description in a read-only table
- No create/edit/delete — "Read-only for now" label in page header

### 1.8 Frontend: PermissionManagementPage — tabs by scope

**File:** `src/Frontend/IFX.FrontEnd/src/pages/PermissionManagementPage.tsx`

- Read `?tab=platform` from URL query param to support deep-linking from Sidebar.
- **Tenant-only users:** render only `scope === 'Tenant'` permissions. No tabs — the split
  is invisible to them.
- **GlobalRole users:** render two tabs:
  - **Tenant Permissions** — `scope === 'Tenant'`, full CRUD
  - **Platform Permissions** — `scope === 'Platform'`, full CRUD

### 1.9 Frontend: RoleDetailPage — filter permission picker

**File:** `src/Frontend/IFX.FrontEnd/src/pages/RoleDetailPage.tsx`

When opening the "Assign Permissions" modal, filter the available permissions list to
`scope === 'Tenant'` only (D7). Platform permissions are never assignable to a tenant role.

### 1.10 Frontend: PolicyManagementPage — tabs + group by resource type

**File:** `src/Frontend/IFX.FrontEnd/src/pages/PolicyManagementPage.tsx`

- Read `?tab=platform` from URL query param.
- **Common change (all users):** Within any policy list, group rows by `resourceType`
  using a collapsible group header (e.g. `▸ user (3)`, `▸ role (5)`).
- **Tenant-only users:** single tab, tenant policies grouped by resource type.
- **GlobalRole users:** two tabs:
  - **Tenant Policies** — existing `GET /api/v1/policy`, grouped by resourceType
  - **Platform Policies** — `GET /api/v1/platform/policy` (already exists), grouped by resourceType

### 1.11 Frontend: TenantManagementPage — restrict tenant-only users

**File:** `src/Frontend/IFX.FrontEnd/src/pages/TenantManagementPage.tsx`

- **Tenant-only users:** filter the tenant list to only show the user's own tenants
  (`user.tenants`). Hide the "+ Create Tenant" and "Delete" buttons.
  Show a read-only badge: "You can view your tenant details here."
- **GlobalRole users:** unchanged — full CRUD over all tenants.

### 1.12 Frontend: RoleManagementPage — tabs

**File:** `src/Frontend/IFX.FrontEnd/src/pages/RoleManagementPage.tsx`

- **Tenant-only users:** no tabs — existing layout unchanged.
- **GlobalRole users:** tab bar:
  - **Global Roles** — calls `GET /api/v1/platform/globalroles`, read-only table
    (same as GlobalRolesPage but inline). Badge: "Read-only".
  - **This Tenant** — existing role list with full CRUD (moved into tab)
  - **All Tenants** — Phase 2 (lazy `ExpandableCrossTenantSection`)

---

## Phase 2 — Cross-Tenant Views

Requires new backend endpoints. Each is gated by GlobalRole ABAC policy.

### 2.1 Backend: Cross-tenant query handlers

New queries under `src/Modules/Auth/IFX.Modules.Auth.Application/`:

| Query | Endpoint | Returns |
|-------|----------|---------|
| `GetAllUsersAcrossTenantsQuery` | `GET /api/v1/platform/users` | `CrossTenantResultDto<UserManagementDto>` |
| `GetAllRolesAcrossTenantsQuery` | `GET /api/v1/platform/roles` | `CrossTenantResultDto<RoleDto>` |
| `GetAllRoleGroupsAcrossTenantsQuery` | `GET /api/v1/platform/rolegroups` | `CrossTenantResultDto<RoleGroupDto>` |
| `GetAllDepartmentsAcrossTenantsQuery` | `GET /api/v1/platform/departments` | `CrossTenantResultDto<DepartmentDto>` |

**Shared DTO:**
```csharp
public class CrossTenantResultDto<T>
{
    public IReadOnlyList<TenantGroupDto<T>> Tenants { get; init; }
}

public class TenantGroupDto<T>
{
    public Guid TenantId { get; init; }
    public string TenantName { get; init; }
    public IReadOnlyList<T> Items { get; init; }
}
```

Each handler:
- No `X-Tenant-Id` filter
- Requires `ICurrentUser.GlobalRoles.Count > 0` (throws `ForbiddenException` otherwise)
- Excludes the current tenant from results (current tenant is shown in Section 1)
- Orders by TenantName, then by item name

### 2.2 Frontend: ExpandableCrossTenantSection component

**File:** `src/Frontend/IFX.FrontEnd/src/components/ExpandableCrossTenantSection.tsx`  *(new)*

```tsx
<ExpandableCrossTenantSection
  label="All Tenants"
  fetchFn={() => platformApi.getAllRoles()}
  renderItems={(group) => <RoleTable roles={group.items} tenantName={group.tenantName} readOnly />}
/>
```

Behaviour (D2):
- Renders a collapsed row with "▸ Load all tenants" on initial paint — **no API call on mount**.
- On expand: fires `fetchFn`, shows loading spinner, renders grouped results.
- Each tenant group is its own collapsible sub-section.
- All rows are read-only (no create/edit/delete buttons).

### 2.3 Frontend: Add platform API module

**File:** `src/Frontend/IFX.FrontEnd/src/api/platform.ts`  *(new)*

```ts
export const platformApi = {
  getGlobalRoles: () => apiClient.get('/api/v1/platform/globalroles'),
  getAllUsers: () => apiClient.get('/api/v1/platform/users'),
  getAllRoles: () => apiClient.get('/api/v1/platform/roles'),
  getAllRoleGroups: () => apiClient.get('/api/v1/platform/rolegroups'),
  getAllDepartments: () => apiClient.get('/api/v1/platform/departments'),
  getPolicies: () => apiClient.get('/api/v1/platform/policy'),
}
```

### 2.4 Frontend: Wire ExpandableCrossTenantSection into pages

**RoleManagementPage** — "All Tenants" tab:
```tsx
<ExpandableCrossTenantSection fetchFn={platformApi.getAllRoles} renderItems={...} />
```

**RoleGroupManagementPage, UserManagementPage, DepartmentManagementPage** — second section
below the existing table, only rendered when `isGlobalUser`.

---

## Implementation Order

### Phase 1
1. Backend: `UserProfileDto` + handler — add `GlobalRoles`
2. Backend: `PermissionDto` + handler — add `Scope`
3. Frontend: `types/api.ts` — add `globalRoles`, `scope`
4. Frontend: `AuthContext` — add `globalRoles`, `isGlobalUser`, `isGlobalAdmin`, `hasGlobalRole`
5. Frontend: `TenantRequiredBanner` component
6. Frontend: `Sidebar` — Platform nav group (conditional on `isGlobalUser`)
7. Frontend: `GlobalRolesPage` + route `/globalroles`
8. Frontend: `PermissionManagementPage` — tabs by scope
9. Frontend: `RoleDetailPage` — filter permission picker to Tenant scope
10. Frontend: `PolicyManagementPage` — tabs + group by resourceType
11. Frontend: `TenantManagementPage` — restrict tenant-only users
12. Frontend: `RoleManagementPage` — tab layout
13. Tests: backend handler tests (GlobalRoles in profile, Scope in PermissionDto); frontend component tests

### Phase 2
14. Backend: `CrossTenantResultDto<T>` + `TenantGroupDto<T>` shared DTOs
15. Backend: Four cross-tenant query handlers + platform controller extensions
16. Frontend: `platform.ts` API module
17. Frontend: `ExpandableCrossTenantSection` component
18. Frontend: Wire into RoleManagementPage, RoleGroupManagementPage, UserManagementPage, DepartmentManagementPage

---

## What Does NOT Change

- Existing tenant-scoped CRUD for all pages — no behavioral change for tenant users
- API client `X-Tenant-Id` header injection and tenant switcher — unchanged
- RBAC/ABAC enforcement — backend still gates all actions
- Auth flow (login, token refresh, logout) — unchanged
- RoleGroup, User, Department, IdP CRUD logic — extended with optional cross-tenant view, not replaced
