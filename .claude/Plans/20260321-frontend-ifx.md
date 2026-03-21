# Plan: IFX.FrontEnd React Application

**Branch:** `feature/frontend-ifx`
**Date:** 2026-03-21
**Purpose:** Visual test harness and data management demo for IFX ApiHost.

---

## API Audit: Changes Required Before Frontend

After auditing all endpoints, the following API gaps must be fixed first:

### Missing Endpoints

| Gap | Needed For | Action |
|-----|-----------|--------|
| `GET /api/v1/usermanagement/users/{userId}` | User Info detail page | Add `GetUserByIdQuery` + handler + endpoint |
| `GET /api/v1/idp/{idpId}` | Idp Info detail page | Add `GetIdpByIdQuery` + handler + endpoint |

### Confirmed Working (no changes needed)

- `GET /api/v1/auth/oauth/authorize?response_mode=json` — returns `{ authorizationUrl, state }` for SPA redirect
- Callback delivers tokens to frontend via URL hash fragment: `{FrontendCallbackUrl}#access_token=...&id_token=...&refresh_token=...`
- `GET /api/v1/role/` — returns list with permissions included (sufficient for Role Info detail)
- `GET /api/v1/role/{roleId}` — returns single role with permissions
- `GET /api/v1/rolegroup/` — returns list with roles included (sufficient for RoleGroup Info detail)
- `GET /api/v1/permission/` — returns full list (sufficient for Permission Management)
- `GET /api/v1/usermanagement/users` — returns `UserProfileDto` with `Roles` and `RoleGroups` (just fixed)
- CORS: `AllowAll` policy active — frontend on `localhost:8030` works without changes

---

## Phase 1: Backend API Fixes

### 1.1 Add `GetUserByIdQuery`

**Files to create:**
- `Application/Users/Queries/GetUserById/GetUserByIdQuery.cs`
- `Application/Users/Queries/GetUserById/GetUserByIdQueryHandler.cs`

**Handler:** uses `IUserRepository.GetByIdWithRolesAndGroupsAsync(id)` → maps to `UserProfileDto`

### 1.2 Add `GetUserById` Endpoint

**File:** `Presentation/Users/Endpoints/UserManagementEndpointExtensions.cs`
- Add `GET /api/v1/usermanagement/users/{userId}`

**File:** `Presentation/Users/Endpoints/UserManagementEndpoints.cs`
- Add `GetUserById` static method

### 1.3 Add `GetIdpByIdQuery`

**Files to create:**
- `Application/Identity/Queries/GetIdpById/GetIdpByIdQuery.cs`
- `Application/Identity/Queries/GetIdpById/GetIdpByIdQueryHandler.cs`

**Handler:** fetches single Idp from `IUnitOfWork.Idps.GetByIdAsync(id)` → maps to `IdpDto`

### 1.4 Add `GetIdpById` Endpoint

**File:** `Presentation/Identity/Endpoints/IdpEndpointExtensions.cs`
- Add `GET /api/v1/idp/{idpId}`

**File:** `Presentation/Identity/Endpoints/IdpEndpoints.cs`
- Add `GetIdpById` static method

---

## Phase 2: Frontend Project Setup

### Location
```
src/Frontend/IFX.FrontEnd/
```

### Tech Stack
- **Vite** + **React 18** + **TypeScript**
- **React Router v6** — client-side routing
- **Axios** — API client with interceptor for Bearer token
- **Port:** 8030 (matches `COGNITO_OIDC_FRONTEND_CALLBACK_URL`)

### Project Structure
```
src/Frontend/IFX.FrontEnd/
├── public/
│   └── ifx-logo.svg              # IFX icon (geometric/abstract)
├── src/
│   ├── api/                      # Axios API layer (one file per domain)
│   │   ├── client.ts             # Axios instance + interceptor
│   │   ├── auth.ts               # /auth/register, /auth/oauth/*
│   │   ├── user.ts               # /user/profile
│   │   ├── userManagement.ts     # /usermanagement/users
│   │   ├── idp.ts                # /idp
│   │   ├── role.ts               # /role
│   │   ├── roleGroup.ts          # /rolegroup
│   │   └── permission.ts         # /permission
│   ├── contexts/
│   │   └── AuthContext.tsx       # access_token, user profile, login/logout
│   ├── components/
│   │   ├── layout/
│   │   │   ├── AppLayout.tsx     # Header + Sidebar + <Outlet>
│   │   │   ├── Header.tsx        # IFX logo left | "IFX" title center | UserMenu right
│   │   │   ├── Sidebar.tsx       # Nav links to all management pages
│   │   │   └── UserMenu.tsx      # Avatar (initials) dropdown: Profile, Logout
│   │   └── shared/
│   │       ├── ProtectedRoute.tsx
│   │       ├── DataTable.tsx     # Generic list table
│   │       └── Modal.tsx         # Generic confirm/form modal
│   ├── pages/
│   │   ├── auth/
│   │   │   ├── RegisterPage.tsx
│   │   │   ├── LoginPage.tsx     # Initiates OAuth flow via /auth/oauth/authorize?response_mode=json
│   │   │   └── CallbackPage.tsx  # Reads window.location.hash, stores tokens, redirects to /profile
│   │   ├── UserProfilePage.tsx   # View/Edit own profile
│   │   ├── IdpManagementPage.tsx # List → Idp Info (inline detail panel or detail route)
│   │   ├── UserManagementPage.tsx
│   │   ├── UserDetailPage.tsx    # User Info: profile + assign/remove roles & role groups
│   │   ├── RoleGroupManagementPage.tsx
│   │   ├── RoleGroupDetailPage.tsx  # RoleGroup Info + assign/remove roles
│   │   ├── RoleManagementPage.tsx
│   │   ├── RoleDetailPage.tsx    # Role Info + assign/remove permissions
│   │   └── PermissionManagementPage.tsx
│   ├── types/
│   │   └── api.ts                # TypeScript interfaces matching API response shapes
│   ├── App.tsx                   # Route definitions
│   └── main.tsx
├── index.html
├── vite.config.ts                # port: 8030
├── tsconfig.json
└── package.json
```

---

## Phase 3: Page Specifications

### Auth Pages (unauthenticated)

#### `/register` — Register Page
- Fields: Email, Password, Confirm Password, First Name, Last Name
- Calls `POST /api/v1/auth/register`
- On success → show confirm code form
- Confirm code calls `POST /api/v1/auth/confirm`
- On confirm success → redirect to `/login`

#### `/login` — Login Page
- Button: "Sign in with IFX Cognito"
- Calls `GET /api/v1/auth/oauth/authorize?response_mode=json` → gets `authorizationUrl`
- Redirects browser to `authorizationUrl`

#### `/callback` — OAuth Callback Page (route matches `FrontendCallbackUrl`)
- Reads `window.location.hash` on mount
- Parses: `access_token`, `id_token`, `refresh_token`, `expires_in`
- Stores in `AuthContext` (localStorage for persistence)
- Fetches `GET /api/v1/user/profile` to populate user state
- Redirects to `/profile`
- On `#error=...` → shows error and link back to `/login`

### Authenticated Pages (inside `AppLayout`)

#### `/profile` — User Profile Page
- Displays: Avatar initials, DisplayName, Email, FirstName, LastName, Phone, Roles, RoleGroups
- "Edit" button → fields become editable inputs, button becomes "Save"
- Save calls `PUT /api/v1/user/profile`
- Logout button also available here

#### `/idp` — Idp Management Page
- Table: Name, Type, IsPrimary, Domain, ClientId, Actions (Edit)
- Row click → detail panel or `/idp/{idpId}` with full info
- "Create" button → inline form or modal: Domain, ClientId, ClientSecret, Type, IsPrimary
- "Edit" → modal pre-filled, calls `PUT /api/v1/idp/{idpId}`
- API: `GET /api/v1/idp/`, `GET /api/v1/idp/{idpId}`, `POST /api/v1/idp/`, `PUT /api/v1/idp/{idpId}`

#### `/users` — User Management Page
- Paginated table: DisplayName, Email, Roles, RoleGroups, IsActive
- Row click → `/users/{userId}`
- API: `GET /api/v1/usermanagement/users?page=1&pageSize=50`

#### `/users/:userId` — User Info (Detail) Page
- Shows full `UserProfileDto`: profile fields, Roles chips, RoleGroups chips
- "Assign Roles" button → multi-select from all roles list → `POST /api/v1/usermanagement/users/{id}/roles`
- "Remove Role" chip × → `DELETE /api/v1/usermanagement/users/{id}/roles/{roleId}`
- "Assign Role Groups" button → multi-select → `POST /api/v1/usermanagement/users/{id}/rolegroups`
- "Remove Role Group" chip × → `DELETE /api/v1/usermanagement/users/{id}/rolegroups/{roleGroupId}`
- API: `GET /api/v1/usermanagement/users/{userId}` *(new endpoint from Phase 1)*

#### `/rolegroups` — RoleGroup Management Page
- Table: Name, Description, Roles count
- "Create" button → modal: Name, Description
- Row click → `/rolegroups/{roleGroupId}`

#### `/rolegroups/:roleGroupId` — RoleGroup Info (Detail) Page
- Shows: Name, Description, Roles list as chips
- "Edit" → inline edit name/description, calls `PUT /api/v1/rolegroup/{id}`
- "Assign Roles" → multi-select from all roles → `POST /api/v1/rolegroup/{id}/roles`
- "Remove Role" chip × → `DELETE /api/v1/rolegroup/{id}/roles/{roleId}`
- "Delete Group" → confirm modal → `DELETE /api/v1/rolegroup/{id}`

#### `/roles` — Role Management Page
- Table: Name, Description, Permissions count
- "Create" button → modal: Name, Description
- Row click → `/roles/{roleId}`

#### `/roles/:roleId` — Role Info (Detail) Page
- Shows: Name, Description, Permissions list as chips
- "Edit" → inline edit, calls `PUT /api/v1/role/{id}`
- "Assign Permissions" → multi-select from all permissions → `POST /api/v1/role/{id}/permissions`
- "Remove Permission" chip × → `DELETE /api/v1/role/{id}/permissions/{permissionId}`
- "Delete Role" → confirm modal → `DELETE /api/v1/role/{id}`

#### `/permissions` — Permission Management Page
- Table: Name, Description, Actions (Edit, Delete)
- "Create" button → modal: Name, Description
- Edit → modal → `PUT /api/v1/permission/{id}`
- Delete → confirm → `DELETE /api/v1/permission/{id}`

---

## Phase 4: Layout & Design

### Header
```
[ IFX Icon ]    IFX    [ AB ] ← UserMenu (initials: FirstName[0] + LastName[0])
```
- IFX icon: SVG geometric mark, left-aligned
- "IFX" title: centered, bold
- UserMenu: avatar circle with initials, dropdown → "My Profile" + "Logout"

### Sidebar (left nav, visible when authenticated)
```
Management
  ├── Idp Management
  ├── User Management
  ├── RoleGroup Management
  ├── Role Management
  └── Permission Management
```
Active route highlighted.

### Design Tokens
- Background: `#0f172a` (slate-900) — dark
- Surface: `#1e293b` (slate-800)
- Accent: `#6366f1` (indigo-500)
- Text: `#f1f5f9` (slate-100)
- Muted: `#94a3b8` (slate-400)
- Success: `#22c55e`, Error: `#ef4444`
- Font: Inter (Google Fonts)
- No external component library — custom CSS modules or plain CSS

---

## Phase 5: Token Management

### Storage
- `localStorage`:
  - `ifx_access_token`
  - `ifx_refresh_token`
  - `ifx_id_token`
  - `ifx_token_expiry` (timestamp)

### Axios Interceptor (`client.ts`)
- Request interceptor: reads `ifx_access_token`, sets `Authorization: Bearer {token}`
- Response interceptor: on 401 → attempt refresh via `POST /api/v1/auth/refresh` with `refresh_token` → retry once → on failure clear storage and redirect to `/login`

### Logout
- Calls `GET /api/v1/auth/oauth/logout` (browser redirect) for Cognito session termination
- On `logout-callback` completes → clears localStorage → redirects to `/login`

---

## Phase 6: Route Table Summary

| Route | Page | Auth Required |
|-------|------|--------------|
| `/login` | LoginPage | No |
| `/register` | RegisterPage | No |
| `/callback` | CallbackPage | No |
| `/profile` | UserProfilePage | Yes |
| `/idp` | IdpManagementPage | Yes |
| `/idp/:idpId` | IdpDetailPage | Yes |
| `/users` | UserManagementPage | Yes |
| `/users/:userId` | UserDetailPage | Yes |
| `/rolegroups` | RoleGroupManagementPage | Yes |
| `/rolegroups/:roleGroupId` | RoleGroupDetailPage | Yes |
| `/roles` | RoleManagementPage | Yes |
| `/roles/:roleId` | RoleDetailPage | Yes |
| `/permissions` | PermissionManagementPage | Yes |
| `/` | Redirect → `/profile` or `/login` | — |

---

## Implementation Order

1. **Phase 1** — Add missing backend endpoints (`GetUserById`, `GetIdpById`)
2. **Phase 2** — Scaffold Vite + React project at `src/WebUI/IFX.FrontEnd`
3. **Phase 3** — Auth flow: `AuthContext`, `CallbackPage`, `LoginPage`, `ProtectedRoute`
4. **Phase 4** — `AppLayout`, `Header`, `Sidebar`, `UserMenu`
5. **Phase 5** — `UserProfilePage` (view + inline edit)
6. **Phase 6** — Management pages: Permissions → Roles → RoleGroups → Users → Idp
7. **Phase 7** — Token refresh interceptor + logout flow

---

## Notes

- The OAuth flow uses `response_mode=json` so the SPA gets the auth URL, avoids CORS issues with the IdP redirect, and controls when the redirect happens.
- Tokens arrive via URL hash fragment (not query string) — they never hit the server or browser history.
- The frontend is purely a test/demo tool — no production security hardening needed.
- All management endpoints require `Authorization: Bearer {token}` — the Axios interceptor handles this automatically.
