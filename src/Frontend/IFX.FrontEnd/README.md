# IFX.FrontEnd

React 18 + TypeScript + Vite frontend for the IFX authentication platform.

## Tech Stack

- **React 18** + **TypeScript**
- **Vite** (dev server on port 8030)
- **React Router v6** — nested protected routes
- **Axios** — API client with Bearer token injection and 401→refresh interceptor
- **OAuth 2.0** — Authorization Code flow with PKCE via Cognito

## Getting Started

### Prerequisites

- Node.js 22+
- IFX API running on `http://localhost:5010`

### Run locally

```bash
npm install
npm run dev
```

Open `http://localhost:8030`.

### Run via Docker

```bash
# From repo root
docker-compose up -d
```

The `ifx-frontend` service starts automatically with Vite HMR enabled (source files are mounted as volumes).

## Pages

| Route | Page |
|-------|------|
| `/login` | Sign in via Cognito |
| `/register` | Register + email confirmation |
| `/callback` | OAuth token callback (hash fragment) |
| `/profile` | View and edit your profile |
| `/users` | User Management |
| `/users/:userId` | User Detail — assign/remove roles and role groups |
| `/idp` | Identity Provider Management |
| `/roles` | Role Management |
| `/roles/:roleId` | Role Detail — assign/remove permissions |
| `/rolegroups` | Role Group Management |
| `/rolegroups/:roleGroupId` | Role Group Detail — assign/remove roles |
| `/permissions` | Permission Management |

## Authentication Flow

1. User clicks **Sign in** → frontend calls `GET /api/v1/auth/oauth/authorize?response_mode=json`
2. Backend returns the Cognito authorization URL as JSON
3. Frontend redirects the browser to Cognito
4. After authentication, Cognito redirects to `GET /api/v1/auth/oauth/callback`
5. Backend exchanges the code for tokens and redirects to `http://localhost:8030/callback#access_token=...`
6. `CallbackPage` reads the hash fragment, stores tokens in `localStorage`, and navigates to `/profile`

Tokens are persisted in `localStorage` (`ifx_access_token`, `ifx_refresh_token`, `ifx_id_token`, `ifx_token_expiry`). The Axios interceptor automatically refreshes expired tokens on 401 and retries the original request.

## Project Structure

```
src/
├── api/              # Axios API clients (auth, user, role, roleGroup, permission, idp, userManagement)
├── components/
│   ├── layout/       # AppLayout, Header, Sidebar, UserMenu
│   └── shared/       # Modal, Chip, ProtectedRoute, SortableHeader
├── contexts/         # AuthContext (user session, login, logout, refresh)
├── pages/
│   └── auth/         # LoginPage, RegisterPage, CallbackPage
└── types/            # TypeScript interfaces for all API DTOs
```

## Environment

The API base URL is hardcoded to `http://localhost:5010` in `src/api/client.ts`. When running in Docker, the browser still calls this address directly (the frontend is a SPA — API calls go from the browser, not container-to-container).

## Build

```bash
npm run build   # outputs to dist/
npm run preview # preview production build locally
```
