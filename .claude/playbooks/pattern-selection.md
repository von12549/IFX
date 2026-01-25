# Pattern Selection Playbook

## Purpose
This document defines when to use the **Platform Pattern** vs the **Modules Pattern** for new components. Claude MUST follow these guidelines when adding new functionality to the codebase.

---

## Golden Rules

1. **Match pattern to purpose** - Platform for infrastructure, Modules for business domains
2. **Don't force fit** - A business domain should never use Platform's 3-project structure
3. **Keep dependencies inward** - Both patterns enforce strict dependency direction
4. **Consider cross-module needs** - Add `.Abstractions` project if other modules need your contracts

---

## Pattern Overview

### Platform Pattern (3 Projects)

```
src/Platform/{ServiceName}/
├── AuthSamples.Platform.{ServiceName}.Abstractions/     # Contracts only
├── AuthSamples.Platform.{ServiceName}.Infrastructure.{Provider}/  # Implementation
└── AuthSamples.Platform.{ServiceName}.Composition/      # DI + Configuration
```

**Characteristics:**
- No domain logic - pure delegation to external providers
- Conditional registration via feature flags
- NoOp implementations for testing/disabled state
- Single responsibility: one service, one interface

### Modules Pattern (5 Projects)

```
src/Modules/{ModuleName}/
├── AuthSamples.Modules.{ModuleName}.Domain/           # Pure business logic
├── AuthSamples.Modules.{ModuleName}.Application/      # CQRS operations
├── AuthSamples.Modules.{ModuleName}.Infrastructure/   # Data access
├── AuthSamples.Modules.{ModuleName}.Presentation/     # HTTP endpoints
└── AuthSamples.Modules.{ModuleName}.Composition/      # Module installer
```

**Characteristics:**
- Rich domain model with entities, events, value objects
- CQRS with MediatR (one handler per command/query)
- Repository pattern (interfaces in Domain, implementations in Infrastructure)
- Clean Architecture with strict dependency flow

---

## Decision Flowchart

```
                    ┌─────────────────────────┐
                    │   New Component Needed  │
                    └───────────┬─────────────┘
                                │
                    ┌───────────▼─────────────┐
                    │  Does it have business  │
                    │   logic or domain       │
                    │      entities?          │
                    └───────────┬─────────────┘
                                │
              ┌─────────────────┼─────────────────┐
              │ YES             │                 │ NO
              ▼                 │                 ▼
    ┌─────────────────┐        │       ┌─────────────────┐
    │  MODULES PATTERN │        │       │ Is it a cross-  │
    │   (5 projects)   │        │       │ cutting infra   │
    └─────────────────┘        │       │    service?     │
                               │       └────────┬────────┘
                               │                │
                               │    ┌───────────┼───────────┐
                               │    │ YES       │           │ NO
                               │    ▼           │           ▼
                               │  ┌─────────────────┐  ┌─────────────┐
                               │  │PLATFORM PATTERN │  │ Consider if │
                               │  │  (3 projects)   │  │  it belongs │
                               │  └─────────────────┘  │ in existing │
                               │                       │   module    │
                               │                       └─────────────┘
```

---

## When to Use Platform Pattern

Use Platform Pattern when ALL of these apply:

| Criteria | Description |
|----------|-------------|
| No business logic | Just contracts and delegation to external providers |
| Cross-cutting concern | Used by multiple modules or the entire application |
| Swappable implementation | May need different providers (e.g., SendGrid vs SES) |
| Feature-flag friendly | Can be disabled without breaking the app |

### Platform Pattern Examples

| Service | Provider Examples | Why Platform? |
|---------|-------------------|---------------|
| BackgroundJobs | Hangfire, Quartz | Infrastructure concern, swappable |
| Notifications | SendGrid, AWS SES, SMTP | External provider, swappable |
| Caching | Redis, MemoryCache | Infrastructure, swappable |
| FileStorage | S3, Azure Blob, Local | External provider, swappable |
| Logging (structured) | Serilog, NLog | Infrastructure, swappable |
| Messaging | RabbitMQ, Azure Service Bus | Infrastructure, swappable |

### Platform Pattern Project Structure

```
Abstractions/
├── I{ServiceName}Service.cs    # Main interface
└── Models/
    ├── {Input}Message.cs       # Input DTOs
    └── {Output}Result.cs       # Output DTOs

Infrastructure.{Provider}/
├── {Provider}{ServiceName}Service.cs  # Implementation
└── {Provider}Settings.cs              # Provider-specific config

Composition/
├── {ServiceName}Settings.cs                         # General settings
├── {ServiceName}ServiceCollectionExtensions.cs      # AddXxx()
├── {ServiceName}ApplicationBuilderExtensions.cs     # UseXxx() if needed
└── NoOp{ServiceName}Service.cs                      # Disabled/test impl
```

---

## When to Use Modules Pattern

Use Modules Pattern when ANY of these apply:

| Criteria | Description |
|----------|-------------|
| Has domain entities | User, Order, Payment, Product, etc. |
| Business rules | Validation, state transitions, domain logic |
| CQRS operations | Commands that change state, queries that read |
| Bounded context | Distinct area of business functionality |
| HTTP endpoints | Public API surface area |

### Modules Pattern Examples

| Module | Entities | Why Module? |
|--------|----------|-------------|
| Auth | User, Role, UserIdentity, LoginEvent | Complex domain, identity rules |
| Orders | Order, OrderItem, OrderStatus | Business logic, state machine |
| Payments | Payment, Transaction, Refund | Financial rules, audit |
| Inventory | Product, Stock, Warehouse | Business logic, tracking |
| Notifications (domain) | NotificationTemplate, NotificationLog | If business rules exist |

### Modules Pattern Project Dependencies

```
                    ┌────────────────────┐
                    │  Composition       │ ← ApiHost references only this
                    └────────────────────┘
                              │
           ┌──────────────────┼──────────────────┐
           ▼                  ▼                  ▼
    ┌─────────────┐   ┌─────────────┐   ┌─────────────┐
    │ Presentation│   │Infrastructure│   │ Application │
    └─────────────┘   └─────────────┘   └─────────────┘
           │                  │                  │
           └──────────────────┼──────────────────┘
                              ▼
                    ┌─────────────────┐
                    │   Application   │
                    └─────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │     Domain      │ ← Zero external dependencies
                    └─────────────────┘
```

---

## Cross-Module Communication

When modules need to share contracts:

### Option 1: Add Abstractions Project (Recommended)

```
src/Modules/{ModuleName}/
├── AuthSamples.Modules.{ModuleName}.Abstractions/  ← NEW
│   ├── I{ModuleName}Service.cs
│   └── Models/
│       └── {Dto}s.cs
├── AuthSamples.Modules.{ModuleName}.Domain/
└── ...
```

**Usage:** Other modules reference only `.Abstractions`:
```xml
<ProjectReference Include="..\..\Auth\AuthSamples.Modules.Auth.Abstractions\..." />
```

### Option 2: Domain Events (Loose Coupling)

Publish domain events for cross-module communication:
```csharp
// Module A publishes
public record UserCreatedDomainEvent(Guid UserId, string Email) : IDomainEvent;

// Module B subscribes
public class UserCreatedHandler : INotificationHandler<UserCreatedDomainEvent>
```

---

## Naming Conventions

### Platform Services

| Element | Pattern | Example |
|---------|---------|---------|
| Abstractions project | `AuthSamples.Platform.{Name}.Abstractions` | `AuthSamples.Platform.Caching.Abstractions` |
| Infrastructure project | `AuthSamples.Platform.{Name}.Infrastructure.{Provider}` | `AuthSamples.Platform.Caching.Infrastructure.Redis` |
| Composition project | `AuthSamples.Platform.{Name}.Composition` | `AuthSamples.Platform.Caching.Composition` |
| Main interface | `I{Name}Service` | `ICacheService` |
| Extension method | `Add{Name}()` | `AddCaching()` |

### Business Modules

| Element | Pattern | Example |
|---------|---------|---------|
| Domain project | `AuthSamples.Modules.{Name}.Domain` | `AuthSamples.Modules.Orders.Domain` |
| Application project | `AuthSamples.Modules.{Name}.Application` | `AuthSamples.Modules.Orders.Application` |
| Infrastructure project | `AuthSamples.Modules.{Name}.Infrastructure` | `AuthSamples.Modules.Orders.Infrastructure` |
| Presentation project | `AuthSamples.Modules.{Name}.Presentation` | `AuthSamples.Modules.Orders.Presentation` |
| Composition project | `AuthSamples.Modules.{Name}.Composition` | `AuthSamples.Modules.Orders.Composition` |
| Module installer | `{Name}ModuleInstaller` | `OrdersModuleInstaller` |
| Extension method | `Add{Name}Module()` | `AddOrdersModule()` |

---

## DI Registration Patterns

### Platform Pattern

```csharp
// In Composition project
public static class CachingServiceCollectionExtensions
{
    public static IServiceCollection AddCaching(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        var settings = configuration
            .GetSection(CachingSettings.SectionName)
            .Get<CachingSettings>() ?? new CachingSettings();

        if (!settings.Enabled)
        {
            services.AddSingleton<ICacheService, NoOpCacheService>();
            return services;
        }

        // Register real implementation based on provider
        services.AddSingleton<ICacheService, RedisCacheService>();
        return services;
    }
}
```

### Modules Pattern

```csharp
// In Composition project
public sealed class OrdersModuleInstaller : IModuleInstaller
{
    public string ModuleName => "Orders";

    public IServiceCollection InstallServices(
        IServiceCollection services,
        IConfiguration configuration)
    {
        services.AddOrdersApplication();      // MediatR handlers
        services.AddOrdersInfrastructure(configuration);  // DbContext, repos
        return services;
    }

    public IEndpointRouteBuilder MapEndpoints(IEndpointRouteBuilder builder)
    {
        builder.MapOrderEndpoints();
        return builder;
    }
}
```

---

## Quick Decision Reference

| Question | Answer → Pattern |
|----------|------------------|
| Does it delegate to external provider? | Yes → Platform |
| Does it have domain entities? | Yes → Modules |
| Does it need CQRS commands/queries? | Yes → Modules |
| Does it expose HTTP endpoints? | Yes → Modules |
| Can it be disabled without breaking app? | Yes → Platform |
| Is it used by ALL modules? | Yes → Platform |
| Is it a bounded business context? | Yes → Modules |

---

## Anti-Patterns to Avoid

| Bad | Good | Reason |
|-----|------|--------|
| Business logic in Platform service | Move to Module | Platform is for delegation only |
| Modules Pattern for simple provider wrapper | Use Platform Pattern | Over-engineering |
| Direct cross-module project references | Use Abstractions or events | Creates tight coupling |
| Platform service with domain entities | Convert to Module | Mixing concerns |
| Module without Composition layer | Always add Composition | Breaks discovery pattern |

---

## References

- **ADR-007**: Platform Pattern vs Modules Pattern decision
- **architecture.md**: Layer responsibilities and dependency rules
- **naming-conventions.md**: Full naming convention reference

---

End of playbook.
