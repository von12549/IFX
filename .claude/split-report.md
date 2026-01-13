# Split Report

## Purpose
Documents the splitting of the legacy monolithic `CLAUDE.md` into a structured instruction system.

## Date
January 2026

---

## Summary

The original `CLAUDE.md` (742 lines) was split into 10 focused documents totaling ~500 lines, with the root file reduced to ~70 lines.

---

## What Moved Where

| Original Section | Destination |
|-----------------|-------------|
| Project Overview | `CLAUDE.md` (condensed) |
| Architecture (structure, patterns) | `/.claude/architecture.md` |
| Technology Stack | `/.claude/dotnet/overview.md` |
| Build and Test Commands | `/.claude/dotnet/overview.md` |
| Layer Details (Domain, Application, etc.) | `/.claude/architecture.md` |
| Database Schema | `/.claude/dotnet/ef-core.md` |
| Authentication Flow | `/.claude/dotnet/aws-cognito.md` |
| Configuration | `/.claude/dotnet/aws-cognito.md` |
| API Endpoints | `CLAUDE.md` (quick reference) |
| Key Design Decisions | `/.claude/decisions.md` |
| Logging | `/.claude/coding-standards.md` |
| Health Checks | `/.claude/dotnet/aws-cognito.md` |
| Docker | `/.claude/dotnet/overview.md` |
| Common Tasks (Add Command/Query/Entity) | `/.claude/dotnet/cqrs.md`, `/.claude/dotnet/ef-core.md` |
| Testing Locally | `/.claude/dotnet/overview.md` |
| Troubleshooting | `/.claude/dotnet/overview.md` |
| Completed Features | Removed (changelog, not instructions) |
| Future Enhancements | Removed (roadmap, not instructions) |
| Migration Documentation | Removed (reference only, link preserved in decisions.md) |

---

## New Files Created

| File | Lines | Purpose |
|------|-------|---------|
| `/.claude/architecture.md` | ~120 | Layer responsibilities, dependency rules |
| `/.claude/coding-standards.md` | ~80 | Naming, error handling, logging, security |
| `/.claude/decisions.md` | ~90 | ADRs with rationale |
| `/.claude/glossary.md` | ~60 | Terms and abbreviations |
| `/.claude/dotnet/overview.md` | ~90 | Tech stack, build/run commands |
| `/.claude/dotnet/cqrs.md` | ~110 | CQRS patterns, adding operations |
| `/.claude/dotnet/ef-core.md` | ~110 | Database schema, migrations |
| `/.claude/dotnet/testing.md` | ~80 | Test structure and patterns |
| `/.claude/dotnet/aws-cognito.md` | ~90 | Cognito configuration, auth flows |

---

## Removed/Deprecated Items

| Item | Reason |
|------|--------|
| Completed Features list | Changelog, not actionable instructions |
| Future Enhancements list | Roadmap, not actionable instructions |
| Detailed code examples (>50 lines) | Moved to relevant tech docs, condensed |
| Duplicate endpoint listings | Consolidated to quick reference |

---

## Ambiguities Resolved

| Issue | Resolution |
|-------|------------|
| Layer Details vs Architecture | Architecture.md covers invariants; dotnet/*.md covers implementation |
| Common Tasks spread across topics | Split by concern: CQRS for commands/queries, EF Core for entities |
| Config examples (appsettings.json) | Moved to aws-cognito.md as primary use case |

---

## Verification Checklist

- [x] No important constraint was lost
- [x] Root file is short (~70 lines, under 150 target)
- [x] Each new file has clear scope header
- [x] No rule appears in more than one place
- [x] Module local docs not created (not needed)
