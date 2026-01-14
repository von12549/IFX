# CLAUDE.md

This file provides guidance to Claude Code when working with this repository.

## Project Overview

**AuthSamples** is a production-ready ASP.NET Core 8 authentication solution with:
- Clean Architecture (Domain → Application → Infrastructure → Presentation)
- CQRS pattern using MediatR
- Dynamic Multi-IdP SSO with auto-provisioning (database-driven)
- Full audit trail

## Golden Rules

1. **Dependencies flow inward only** - outer layers depend on inner, never reverse
2. **Domain has zero external dependencies** - pure business logic only
3. **Users identified by `(Issuer, Subject)` tuple** - not email alone
4. **One handler per command/query** - no shared handlers
5. **Result pattern for expected failures** - exceptions for unexpected errors

## Instruction Index

| Document | Purpose |
|----------|---------|
| `/.claude/architecture.md` | Layer responsibilities, dependency rules, patterns |
| `/.claude/coding-standards.md` | Naming conventions, error handling, logging |
| `/.claude/decisions.md` | Key architectural decisions with rationale |
| `/.claude/glossary.md` | Terms, abbreviations, naming patterns |
| `/.claude/dotnet/overview.md` | Tech stack, build/run commands |
| `/.claude/dotnet/cqrs.md` | Command/Query patterns, adding new operations |
| `/.claude/dotnet/ef-core.md` | Database schema, migrations |
| `/.claude/dotnet/testing.md` | Test structure, patterns |
| `/.claude/dotnet/aws-cognito.md` | Cognito configuration, auth flows |

## Quick Reference

### Build & Run
```bash
dotnet build AuthSamples.sln          # Build
dotnet test AuthSamples.sln           # Test (195 tests)
docker-compose up -d                   # Run with Docker
```

### EF Core Migrations
```bash
cd src/Modules/Auth/AuthSamples.Modules.Auth.Infrastructure
dotnet ef migrations add Name --startup-project ../../../ApiHost/AuthSamples.ApiHost
dotnet ef database update --startup-project ../../../ApiHost/AuthSamples.ApiHost
```

### API Endpoints
- Public: `POST /api/v1/auth/{register,confirm,login}`
- Authenticated: `POST /api/v1/auth/{logout,refresh,revoke}`, `GET/PUT /api/v1/user/profile`
- Admin: `GET/PUT /api/v1/usermanagement/users`, `GET/POST/PUT /api/v1/role`, `/api/v1/idp`
- Health: `GET /health`, `GET /health/ready`

## Conflict Resolution

If instructions conflict, prioritize:
1. Security/compliance
2. Architecture invariants (see `architecture.md`)
3. Module-specific rules
4. Style preferences

## When Uncertain

Load the most relevant `/.claude/*` document before making changes.

## Maintenance Rules
- CLAUDE.md maintenance must follow `/.claude/playbooks/claude-splitting-playbook.md`
- README.md maintenance must follow `/.claude/playbooks/readme-playbook.md`
