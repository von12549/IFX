# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Status

This repository has been reset to a clean state. The git history shows this is intended to be an ASP.NET Core authentication sample project (based on repository name: `authSampleProject`).

## Current State

- **Repository:** Fresh start with only `.gitignore`
- **Previous implementation:** All commits and code have been removed
- **Ready for:** New implementation

## Expected Architecture (Based on Repository Context)

This repository appears to be intended for demonstrating authentication patterns in ASP.NET Core applications.

When code is added, update this file with:
- Build and test commands
- Project structure and architecture
- Authentication flow details
- Database setup instructions
- Required configuration (AWS Cognito, connection strings, etc.)

## .gitignore Configuration

The repository includes a comprehensive .NET-specific `.gitignore` that excludes:
- Build artifacts (`bin/`, `obj/`, `Debug/`, `Release/`)
- NuGet packages (`*.nupkg`, `*.snupkg`)
- Test results
- IDE-specific files (Visual Studio cache files)
- Logs and coverage reports

## Next Steps for Development

When starting development:

1. **Define project structure** - Decide on architecture (Clean Architecture, N-Tier, etc.)
2. **Create solution file** - `dotnet new sln`
3. **Add projects** - Create Domain, Application, Infrastructure, and Web layers if using Clean Architecture
4. **Configure authentication** - Set up AWS Cognito or other auth provider
5. **Update this file** - Document commands, architecture, and setup instructions
