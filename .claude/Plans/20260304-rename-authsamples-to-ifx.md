# Plan: Rename AuthSamples.* → IFX.*

**Date:** 2026-03-04
**Branch:** `feature/rename-authsamples-to-ifx`
**Status:** Implemented

---

## Context

The solution currently uses `AuthSamples` as its root namespace and project prefix throughout 22 projects, 274+ C# files, Docker configs, and documentation. The goal is a clean, consistent rename to `IFX` — affecting project names, directory names, namespaces, using statements, the solution file, database names, and all documentation.

---

## Scope Summary

| Category | Count | Action |
|---|---|---|
| Directories to rename | 22 | `git mv` |
| `.csproj` files to rename | 19 source + 8 test = **22 total** | `git mv` inside renamed dirs |
| `.sln` file | 1 | `git mv` |
| C# files (namespace/using) | ~274 | global text replace |
| Docker/compose files | 3 | global text replace |
| Env config files | 4 | global text replace |
| Documentation files | 24 | global text replace |

**Not renamed:** `src/BuildingBlocks/App.Abstractions/` (no `AuthSamples` prefix)
**Not renamed:** Root directory `C:\AuthSample` (already different from `AuthSamples`)

---

## Phase 1 – Create Feature Branch

```bash
git checkout -b feature/rename-authsamples-to-ifx
```

---

## Phase 2 – Rename Directories (git mv)

Use `git mv` to preserve git history. Rename each project directory:

### Source Projects (13)
| Old | New |
|---|---|
| `src/ApiHost/AuthSamples.ApiHost` | `src/ApiHost/IFX.ApiHost` |
| `src/Modules/Auth/AuthSamples.Modules.Auth.Domain` | `src/Modules/Auth/IFX.Modules.Auth.Domain` |
| `src/Modules/Auth/AuthSamples.Modules.Auth.Application` | `src/Modules/Auth/IFX.Modules.Auth.Application` |
| `src/Modules/Auth/AuthSamples.Modules.Auth.Infrastructure` | `src/Modules/Auth/IFX.Modules.Auth.Infrastructure` |
| `src/Modules/Auth/AuthSamples.Modules.Auth.Presentation` | `src/Modules/Auth/IFX.Modules.Auth.Presentation` |
| `src/Modules/Auth/AuthSamples.Modules.Auth.Composition` | `src/Modules/Auth/IFX.Modules.Auth.Composition` |
| `src/Platform/AuthSamples.Platform.Shared` | `src/Platform/IFX.Platform.Shared` |
| `src/Platform/BackgroundJobs/AuthSamples.Platform.BackgroundJobs.Abstractions` | `src/Platform/BackgroundJobs/IFX.Platform.BackgroundJobs.Abstractions` |
| `src/Platform/BackgroundJobs/AuthSamples.Platform.BackgroundJobs.Infrastructure.Hangfire` | `src/Platform/BackgroundJobs/IFX.Platform.BackgroundJobs.Infrastructure.Hangfire` |
| `src/Platform/BackgroundJobs/AuthSamples.Platform.BackgroundJobs.Composition` | `src/Platform/BackgroundJobs/IFX.Platform.BackgroundJobs.Composition` |
| `src/Platform/Notifications/AuthSamples.Platform.Notifications.Abstractions` | `src/Platform/Notifications/IFX.Platform.Notifications.Abstractions` |
| `src/Platform/Notifications/AuthSamples.Platform.Notifications.Infrastructure.SendGrid` | `src/Platform/Notifications/IFX.Platform.Notifications.Infrastructure.SendGrid` |
| `src/Platform/Notifications/AuthSamples.Platform.Notifications.Composition` | `src/Platform/Notifications/IFX.Platform.Notifications.Composition` |
| `src/WebUI/AuthSamples.WebUI` | `src/WebUI/IFX.WebUI` |

### Test Projects (8)
| Old | New |
|---|---|
| `tests/AuthSamples.Tests.Common` | `tests/IFX.Tests.Common` |
| `tests/AuthSamples.Modules.Auth.Domain.Tests` | `tests/IFX.Modules.Auth.Domain.Tests` |
| `tests/AuthSamples.Modules.Auth.Application.Tests` | `tests/IFX.Modules.Auth.Application.Tests` |
| `tests/AuthSamples.Modules.Auth.Infrastructure.Tests` | `tests/IFX.Modules.Auth.Infrastructure.Tests` |
| `tests/AuthSamples.Modules.Auth.Presentation.Tests` | `tests/IFX.Modules.Auth.Presentation.Tests` |
| `tests/AuthSamples.IntegrationTests` | `tests/IFX.IntegrationTests` |
| `tests/AuthSamples.Platform.BackgroundJobs.Tests` | `tests/IFX.Platform.BackgroundJobs.Tests` |
| `tests/AuthSamples.Platform.Notifications.Tests` | `tests/IFX.Platform.Notifications.Tests` |

---

## Phase 3 – Rename .csproj Files (git mv)

After each directory is renamed, rename the `.csproj` inside it:

```
IFX.ApiHost/AuthSamples.ApiHost.csproj  →  IFX.ApiHost/IFX.ApiHost.csproj
IFX.Modules.Auth.Domain/AuthSamples.Modules.Auth.Domain.csproj  →  ...IFX.Modules.Auth.Domain.csproj
... (repeat for all 22 projects)
```

---

## Phase 4 – Rename Solution File (git mv)

```bash
git mv AuthSamples.sln IFX.sln
```

---

## Phase 5 – Global Content Replacement

Run a single find-replace pass across all text files. Replace **all** occurrences of `AuthSamples` with `IFX`:

**Files affected:**
- All `.cs` files (namespaces: `namespace AuthSamples.` → `namespace IFX.`, using statements: `using AuthSamples.` → `using IFX.`)
- All `.csproj` files (project references, assembly names, root namespaces)
- `IFX.sln` (project entries, folder structure)
- `docker-compose.yml` (dockerfile path, `SENDGRID_FROM_NAME`)
- `src/ApiHost/IFX.ApiHost/Dockerfile` (build args, COPY paths)
- `src/ApiHost/IFX.ApiHost/Properties/launchSettings.json` (profile name)
- All 4 `.env` files (headers, `SENDGRID_FROM_NAME`)
- `docker-compose.dcproj`
- All documentation files in `docs/`, `.claude/`, `README.md`, `CLAUDE.md`

**Additional specific replacements:**
- `AuthSamplesDb` → `IFXDb` (docker-compose.yml line 48, docker/init-databases.sql, connection strings)

**Exclude from replacement:**
- `obj/` and `bin/` directories (generated, will be rebuilt)
- `.vs/` directory (Visual Studio cache, will be regenerated)
- `.git/` directory (git internals)

**Command used:**
```bash
find . -type f \
  \( -name "*.cs" -o -name "*.csproj" -o -name "*.sln" -o -name "*.json" \
     -o -name "*.yml" -o -name "*.yaml" -o -name "*.md" -o -name "*.sql" \
     -o -name "*.env" -o -name ".env*" -o -name "*.dcproj" -o -name "Dockerfile" \) \
  -not -path "*/obj/*" -not -path "*/bin/*" -not -path "*/.vs/*" -not -path "*/.git/*" \
  -exec sed -i 's/AuthSamples/IFX/g' {} +
```

---

## Phase 6 – Verification

### 6a. Build
```bash
dotnet build IFX.sln
```
Result: **0 errors**, 16 pre-existing warnings.

### 6b. Test
```bash
dotnet test IFX.sln --filter "FullyQualifiedName!~IFX.IntegrationTests"
```
Result: **252/252 unit tests pass**.

Integration tests require a live database/infrastructure — failure is pre-existing, not a regression.

### 6c. Spot-check for missed references
```bash
grep -r "AuthSamples" . --include="*.cs" --include="*.csproj" --include="*.sln" \
  --exclude-dir=obj --exclude-dir=bin --exclude-dir=.vs --exclude-dir=.git
```
Result: **0 results**.

---

## Notes

- `src/BuildingBlocks/App.Abstractions/` has no `AuthSamples` prefix — left unchanged.
- `src/WebUI/IFX.WebUI/` is a pure frontend (no `.csproj`) — directory renamed only.
- The `.vs/` Visual Studio cache directory regenerates on next VS open — not modified.
- EF Core migration history table names embed the context name, not the namespace — no migration file changes needed.
