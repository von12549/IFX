# Platform Module Implementation Plan

**Date**: 2026-01-20
**Branch**: `feature/platform-module`
**Status**: Implemented

## Overview

Create a Platform module for cross-cutting services (background jobs, notifications) that can be consumed by all application modules.

## Architecture

### Folder Structure

```
/src/Platform/
├── IFX.Platform.Shared/                    # Common types
│
├── BackgroundJobs/
│   ├── IFX.Platform.BackgroundJobs.Abstractions/
│   ├── IFX.Platform.BackgroundJobs.Infrastructure.Hangfire/
│   └── IFX.Platform.BackgroundJobs.Composition/
│
└── Notifications/
    ├── IFX.Platform.Notifications.Abstractions/
    ├── IFX.Platform.Notifications.Infrastructure.SendGrid/
    └── IFX.Platform.Notifications.Composition/
```

### Dependency Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                          ApiHost                                 │
│    (references all Composition projects)                        │
└──────────────┬──────────────────────────────────┬───────────────┘
               │                                  │
               ▼                                  ▼
┌──────────────────────────┐      ┌──────────────────────────────┐
│ BackgroundJobs.Composition│      │ Notifications.Composition    │
└──────────────┬───────────┘      └──────────────┬───────────────┘
               │                                  │
               ▼                                  ▼
┌──────────────────────────┐      ┌──────────────────────────────┐
│ Infrastructure.Hangfire  │      │ Infrastructure.SendGrid      │
└──────────────┬───────────┘      └──────────────┬───────────────┘
               │                                  │
               ▼                                  ▼
┌──────────────────────────┐      ┌──────────────────────────────┐
│ BackgroundJobs.Abstractions│    │ Notifications.Abstractions   │
└──────────────┬───────────┘      └──────────────┬───────────────┘
               │                                  │
               └────────────┬─────────────────────┘
                            ▼
                ┌───────────────────────┐
                │   Platform.Shared     │
                └───────────────────────┘
                            ▲
                            │
              ┌─────────────┴─────────────┐
              │  Auth.Application         │
              │  (consumes Abstractions)  │
              └───────────────────────────┘
```

## Project Details

### 1. IFX.Platform.Shared

Common types shared across platform modules.

```csharp
// Potential contents (future):
// - IPlatformService marker interface
// - Common result types if needed
// - Shared configuration base classes
```

**References**: None (leaf project)

---

### 2. BackgroundJobs Module

#### 2.1 IFX.Platform.BackgroundJobs.Abstractions

Interfaces for background job operations.

```csharp
// Future interfaces:
public interface IBackgroundJobService
{
    string Enqueue<T>(Expression<Action<T>> methodCall);
    string Schedule<T>(Expression<Action<T>> methodCall, TimeSpan delay);
    string Schedule<T>(Expression<Action<T>> methodCall, DateTimeOffset enqueueAt);
    void AddOrUpdateRecurring<T>(string recurringJobId, Expression<Action<T>> methodCall, string cronExpression);
    void RemoveRecurring(string recurringJobId);
}
```

**References**: Platform.Shared

#### 2.2 IFX.Platform.BackgroundJobs.Infrastructure.Hangfire

Hangfire implementation of background job interfaces.

**References**:
- BackgroundJobs.Abstractions
- Hangfire.Core
- Hangfire.SqlServer (or Hangfire.AspNetCore)

#### 2.3 IFX.Platform.BackgroundJobs.Composition

DI registration and configuration.

```csharp
public static class BackgroundJobsServiceCollectionExtensions
{
    public static IServiceCollection AddBackgroundJobs(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        // Register Hangfire services
        // Configure storage
        // Register IBackgroundJobService
    }
}
```

**References**:
- BackgroundJobs.Abstractions
- BackgroundJobs.Infrastructure.Hangfire

---

### 3. Notifications Module

#### 3.1 IFX.Platform.Notifications.Abstractions

Interfaces for notification operations.

```csharp
// Future interfaces:
public interface IEmailService
{
    Task<Result> SendEmailAsync(EmailMessage message, CancellationToken ct = default);
    Task<Result> SendTemplatedEmailAsync(string templateId, object model, EmailRecipient recipient, CancellationToken ct = default);
}

public record EmailMessage(
    string To,
    string Subject,
    string Body,
    bool IsHtml = true,
    string? From = null);

public record EmailRecipient(string Email, string? Name = null);
```

**References**: Platform.Shared

#### 3.2 IFX.Platform.Notifications.Infrastructure.SendGrid

SendGrid implementation of notification interfaces.

**References**:
- Notifications.Abstractions
- SendGrid

#### 3.3 IFX.Platform.Notifications.Composition

DI registration and configuration.

```csharp
public static class NotificationsServiceCollectionExtensions
{
    public static IServiceCollection AddNotifications(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        // Register SendGrid client
        // Register IEmailService
    }
}
```

**References**:
- Notifications.Abstractions
- Notifications.Infrastructure.SendGrid

---

## Implementation Phases

### Phase 1: Project Scaffolding (Current)
- [ ] Create folder structure
- [ ] Create empty .csproj files with correct references
- [ ] Add projects to IFX.sln
- [ ] Verify solution builds

### Phase 2: BackgroundJobs Implementation (Future)
- [ ] Define abstractions (IBackgroundJobService)
- [ ] Implement Hangfire infrastructure
- [ ] Add composition/DI registration
- [ ] Configure Hangfire dashboard
- [ ] Add to ApiHost

### Phase 3: Notifications Implementation (Future)
- [ ] Define abstractions (IEmailService)
- [ ] Implement SendGrid infrastructure
- [ ] Add composition/DI registration
- [ ] Add email templates support
- [ ] Add to ApiHost

### Phase 4: Integration (Future)
- [ ] Integrate with Auth module (e.g., email verification)
- [ ] Add background job for sending emails
- [ ] Add health checks

---

## Solution File Changes

Add to `IFX.sln`:

```
Project("{FAE04EC0-...}") = "IFX.Platform.Shared", "src\Platform\IFX.Platform.Shared\IFX.Platform.Shared.csproj"
Project("{FAE04EC0-...}") = "IFX.Platform.BackgroundJobs.Abstractions", "src\Platform\BackgroundJobs\IFX.Platform.BackgroundJobs.Abstractions\IFX.Platform.BackgroundJobs.Abstractions.csproj"
Project("{FAE04EC0-...}") = "IFX.Platform.BackgroundJobs.Infrastructure.Hangfire", "src\Platform\BackgroundJobs\IFX.Platform.BackgroundJobs.Infrastructure.Hangfire\IFX.Platform.BackgroundJobs.Infrastructure.Hangfire.csproj"
Project("{FAE04EC0-...}") = "IFX.Platform.BackgroundJobs.Composition", "src\Platform\BackgroundJobs\IFX.Platform.BackgroundJobs.Composition\IFX.Platform.BackgroundJobs.Composition.csproj"
Project("{FAE04EC0-...}") = "IFX.Platform.Notifications.Abstractions", "src\Platform\Notifications\IFX.Platform.Notifications.Abstractions\IFX.Platform.Notifications.Abstractions.csproj"
Project("{FAE04EC0-...}") = "IFX.Platform.Notifications.Infrastructure.SendGrid", "src\Platform\Notifications\IFX.Platform.Notifications.Infrastructure.SendGrid\IFX.Platform.Notifications.Infrastructure.SendGrid.csproj"
Project("{FAE04EC0-...}") = "IFX.Platform.Notifications.Composition", "src\Platform\Notifications\IFX.Platform.Notifications.Composition\IFX.Platform.Notifications.Composition.csproj"
```

---

## Notes

- All projects target `net8.0`
- Use `<ImplicitUsings>enable</ImplicitUsings>` and `<Nullable>enable</Nullable>`
- Abstractions projects should have no external NuGet dependencies (except Platform.Shared)
- Infrastructure projects contain provider-specific NuGet packages
- Composition projects handle all DI wiring
