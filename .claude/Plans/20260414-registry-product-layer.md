# Plan: Registry Product Layer — Product → Fund → FundClass Hierarchy

**Status:** Done

---

## Overview

Introduces a `Product` entity as an optional parent of `Fund` in the Registry module, establishing the industry-standard three-tier hierarchy: **Product (Scheme) → Fund (Sub-fund) → FundClass (Share Class)**. A Product holds scheme-level regulatory identity (ARSN, APIR, ISIN), issuer metadata, and PDS reference that apply across all funds under it. `Fund.ProductId` is a nullable FK so all existing data is unaffected.

---

## Goals

- Add `Product` domain entity with regulatory identity fields
- `Fund` gains an optional nullable `ProductId` FK — existing funds remain valid standalone
- New CRUD endpoints: `GET/POST /api/v1/product`, `GET/PUT/DELETE /api/v1/product/{id}`, `GET /api/v1/product/{id}/funds`
- Integration events: `ProductCreatedEvent`, `ProductStatusChangedEvent`
- Squash-friendly EF migration — add `Products` table + nullable `ProductId` FK on `Funds` as a delta migration on top of existing `InitialCreate`
- ABAC policies: `SameTenant + IsActive` for Product (same pattern as Fund)
- Swagger tag: `"Fund"` group (existing `registry` Swagger doc)

## Non-Goals

- Mandatory product association — `ProductId` stays nullable, enforcement is a business rule not enforced at DB level
- NAV pricing or distribution calculation at product level
- Frontend UI (separate plan)
- Regulatory submission / ASIC lodgement integration

---

## Architecture

### Why Product at the Registry layer

| Level | Entity | Identity | Holds |
|-------|--------|----------|-------|
| Scheme | `Product` | ARSN, APIR, ISIN | Issuer name, PDS ref, inception, wind-up |
| Sub-fund | `Fund` | FundCode | BaseCurrency, FundType, NAV frequency, Status |
| Share class | `FundClass` | ClassCode | Fee structure, class currency, Status |

The Taurus schema uses `Product` / `Scheme` → `Fund` → `Class` with the same split. Product is the regulatory construct; Fund is the investment vehicle; Class is the investor-facing unit series.

### Entity Fields

```csharp
public class Product : BaseEntity, IAuditableEntity
{
    public Guid TenantId { get; private set; }
    public string ProductCode   { get; private set; }   // short mnemonic, unique per tenant
    public string ProductName   { get; private set; }
    public ProductType ProductType { get; private set; }
    public string BaseCurrency  { get; private set; }   // ISO 4217
    public string? ApirCode     { get; private set; }   // AU: 9-char APIR
    public string? Isin         { get; private set; }   // ISO 6166 12-char
    public string? RegulatorSchemeNumber { get; private set; } // AU: ARSN
    public string? PdsReference { get; private set; }   // document reference / URL key
    public string? IssuerName   { get; private set; }
    public DateOnly InceptionDate { get; private set; }
    public DateOnly? WindUpDate { get; private set; }
    public ProductStatus Status { get; private set; }
    // IAuditableEntity
    public Guid? CreatedBy { get; set; }
    public Guid? UpdatedBy { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    public IReadOnlyCollection<Fund> Funds { get; private set; }
}
```

### Enums

```csharp
public enum ProductType
{
    ManagedFund       = 1,
    ETF               = 2,
    Superannuation    = 3,
    IDPS              = 4,
    LIT               = 5,   // Listed Investment Trust
    Other             = 99
}

public enum ProductStatus
{
    Active    = 1,
    Closed    = 2,
    Suspended = 3
}
```

### Fund change

```csharp
// Existing Fund entity — add:
public Guid? ProductId { get; private set; }
public Product? Product { get; private set; }

// New Update overload accepting optional ProductId:
public void SetProduct(Guid? productId) { ProductId = productId; }
```

---

## Implementation Phases

### Phase 1 — Domain

**New files:**
- `IFX.Modules.Registry.Domain/Entities/Product.cs` — entity + `Create` / `Update` / `ChangeStatus` / `WindUp` factory/methods
- `IFX.Modules.Registry.Domain/Enums/ProductType.cs`
- `IFX.Modules.Registry.Domain/Enums/ProductStatus.cs`
- `IFX.Modules.Registry.Domain/Repositories/IProductRepository.cs`

**Modified files:**
- `IFX.Modules.Registry.Domain/Entities/Fund.cs` — add `ProductId?`, `Product?`, `SetProduct(Guid?)`

### Phase 2 — Infrastructure

**New files:**
- `IFX.Modules.Registry.Infrastructure/Persistence/Configurations/ProductConfiguration.cs`

  ```csharp
  builder.ToTable("Products", "registry");
  builder.HasKey(p => p.Id);
  builder.HasIndex(p => new { p.TenantId, p.ProductCode }).IsUnique();
  builder.Property(p => p.ProductCode).HasMaxLength(20).IsRequired();
  builder.Property(p => p.ProductName).HasMaxLength(200).IsRequired();
  builder.Property(p => p.BaseCurrency).HasMaxLength(3).IsRequired();
  builder.Property(p => p.ApirCode).HasMaxLength(9);
  builder.Property(p => p.Isin).HasMaxLength(12);
  builder.Property(p => p.RegulatorSchemeNumber).HasMaxLength(20);
  builder.Property(p => p.PdsReference).HasMaxLength(500);
  builder.Property(p => p.IssuerName).HasMaxLength(200);
  builder.HasMany(p => p.Funds)
      .WithOne(f => f.Product)
      .HasForeignKey(f => f.ProductId)
      .OnDelete(DeleteBehavior.Restrict);
  ```

- `IFX.Modules.Registry.Infrastructure/Repositories/EfProductRepository.cs`

**Modified files:**
- `IFX.Modules.Registry.Infrastructure/Persistence/Configurations/FundConfiguration.cs` — add `ProductId` nullable FK column mapping
- `IFX.Modules.Registry.Infrastructure/Persistence/RegistryDbContext.cs` — add `DbSet<Product> Products`
- `IFX.Modules.Registry.Infrastructure/DependencyInjection.cs` — register `IProductRepository`

**Migration:**
```bash
cd src/Modules/Registry/IFX.Modules.Registry.Infrastructure
dotnet ef migrations add AddProduct \
  --context RegistryDbContext \
  --startup-project ../../../ApiHost/IFX.ApiHost
dotnet ef database update \
  --context RegistryDbContext \
  --startup-project ../../../ApiHost/IFX.ApiHost
```

Migration creates `registry.Products` table and adds nullable `ProductId` FK on `registry.Funds` with `ON DELETE NO ACTION` (Restrict).

### Phase 3 — Application

**New files (Products feature folder):**

```
IFX.Modules.Registry.Application/
└── Products/
    ├── Commands/
    │   ├── CreateProduct/
    │   │   ├── CreateProductCommand.cs
    │   │   └── CreateProductCommandHandler.cs
    │   ├── UpdateProduct/
    │   │   ├── UpdateProductCommand.cs
    │   │   └── UpdateProductCommandHandler.cs
    │   └── DeleteProduct/
    │       ├── DeleteProductCommand.cs
    │       └── DeleteProductCommandHandler.cs
    ├── Queries/
    │   ├── GetProductById/
    │   │   ├── GetProductByIdQuery.cs
    │   │   └── GetProductByIdQueryHandler.cs
    │   ├── GetProducts/
    │   │   ├── GetProductsQuery.cs
    │   │   └── GetProductsQueryHandler.cs
    │   └── GetProductFunds/
    │       ├── GetProductFundsQuery.cs
    │       └── GetProductFundsQueryHandler.cs
    ├── DTOs/
    │   └── ProductDto.cs
    └── Validators/
        └── CreateProductCommandValidator.cs
```

**DTOs:**
```csharp
public record ProductDto(
    Guid Id,
    Guid TenantId,
    string ProductCode,
    string ProductName,
    string ProductType,
    string BaseCurrency,
    string? ApirCode,
    string? Isin,
    string? RegulatorSchemeNumber,
    string? PdsReference,
    string? IssuerName,
    DateOnly InceptionDate,
    DateOnly? WindUpDate,
    string Status,
    DateTime CreatedAt,
    DateTime UpdatedAt);
```

**Commands:**
- `CreateProductCommand(string ProductCode, string ProductName, ProductType ProductType, string BaseCurrency, DateOnly InceptionDate, string? ApirCode, string? Isin, string? RegulatorSchemeNumber, string? PdsReference, string? IssuerName)`
- `UpdateProductCommand(Guid Id, string ProductName, string? ApirCode, string? Isin, string? RegulatorSchemeNumber, string? PdsReference, string? IssuerName, DateOnly? WindUpDate)`
- `DeleteProductCommand(Guid Id)` — sets `Status = Closed`

**New ABAC policy seed** (in migration or DI): `Product:list`, `Product:create`, `Product:update`, `Product:delete` using `SameTenant` template.

**Modified files:**
- `IFX.Modules.Registry.Application/Mappings/MappingProfile.cs` — add `Product → ProductDto` map
- `IFX.Modules.Registry.Application/Interfaces/IUnitOfWork.cs` — if Products needs its own save scope (likely reuse existing)

**Integration events (IFX.Modules.Registry.Abstractions):**
- `ProductCreatedEvent.cs`
- `ProductStatusChangedEvent.cs`

### Phase 4 — Presentation

**New files:**
```
IFX.Modules.Registry.Presentation/
└── Products/
    ├── Endpoints/
    │   └── ProductEndpoints.cs
    └── Requests/
        ├── CreateProductRequest.cs
        └── UpdateProductRequest.cs
```

**Routes:**
| Method | Route | Handler |
|--------|-------|---------|
| GET | `/api/v1/product` | `GetProducts` |
| POST | `/api/v1/product` | `CreateProduct` |
| GET | `/api/v1/product/{id}` | `GetProductById` |
| PUT | `/api/v1/product/{id}` | `UpdateProduct` |
| DELETE | `/api/v1/product/{id}` | `DeleteProduct` (soft-close) |
| GET | `/api/v1/product/{id}/funds` | `GetProductFunds` |

All routes under `.WithTags("Fund")` to include in the existing `registry` Swagger doc.

**Modified files:**
- `IFX.Modules.Registry.Presentation/Extensions/EndpointExtensions.cs` — call `ProductEndpoints.Map(app)`

### Phase 5 — Fund.ProductId update

**No breaking changes** — `ProductId` is nullable. Existing `CreateFundCommand` gains an optional `ProductId?` parameter.

**Modified files:**
- `IFX.Modules.Registry.Presentation/Funds/Requests/CreateFundRequest.cs` — add `Guid? ProductId`
- `IFX.Modules.Registry.Presentation/Funds/Requests/UpdateFundRequest.cs` — add `Guid? ProductId`
- `IFX.Modules.Registry.Application/Funds/Commands/CreateFund/CreateFundCommand.cs` — add `Guid? ProductId`
- `IFX.Modules.Registry.Application/Funds/Commands/UpdateFund/UpdateFundCommand.cs` — add `Guid? ProductId`
- Handlers: call `fund.SetProduct(command.ProductId)` when provided

### Phase 6 — Tests

**New files:**
- `IFX.Modules.Registry.Domain.Tests/ProductEntityTests.cs` — Create, Update, WindUp, ChangeStatus guard tests
- `IFX.Modules.Registry.Application.Tests/Products/CreateProductCommandHandlerTests.cs`
- `IFX.Modules.Registry.Application.Tests/Products/GetProductsQueryHandlerTests.cs`
- `IFX.Modules.Registry.Application.Tests/Products/GetProductFundsQueryHandlerTests.cs`

---

## File Inventory

| File | Action |
|------|--------|
| `Registry.Domain/Entities/Product.cs` | New |
| `Registry.Domain/Enums/ProductType.cs` | New |
| `Registry.Domain/Enums/ProductStatus.cs` | New |
| `Registry.Domain/Repositories/IProductRepository.cs` | New |
| `Registry.Domain/Entities/Fund.cs` | Modify — add `ProductId?`, `SetProduct` |
| `Registry.Infrastructure/Persistence/Configurations/ProductConfiguration.cs` | New |
| `Registry.Infrastructure/Persistence/Configurations/FundConfiguration.cs` | Modify — `ProductId` column |
| `Registry.Infrastructure/Persistence/RegistryDbContext.cs` | Modify — `DbSet<Product>` |
| `Registry.Infrastructure/Repositories/EfProductRepository.cs` | New |
| `Registry.Infrastructure/DependencyInjection.cs` | Modify — register repo |
| `Registry.Infrastructure/Migrations/YYYYMMDD_AddProduct.cs` | New (generated) |
| `Registry.Application/Products/Commands/CreateProduct/*` | New (2 files) |
| `Registry.Application/Products/Commands/UpdateProduct/*` | New (2 files) |
| `Registry.Application/Products/Commands/DeleteProduct/*` | New (2 files) |
| `Registry.Application/Products/Queries/GetProductById/*` | New (2 files) |
| `Registry.Application/Products/Queries/GetProducts/*` | New (2 files) |
| `Registry.Application/Products/Queries/GetProductFunds/*` | New (2 files) |
| `Registry.Application/Products/DTOs/ProductDto.cs` | New |
| `Registry.Application/Products/Validators/CreateProductCommandValidator.cs` | New |
| `Registry.Application/Mappings/MappingProfile.cs` | Modify — Product map |
| `Registry.Abstractions/Events/ProductCreatedEvent.cs` | New |
| `Registry.Abstractions/Events/ProductStatusChangedEvent.cs` | New |
| `Registry.Presentation/Products/Endpoints/ProductEndpoints.cs` | New |
| `Registry.Presentation/Products/Requests/CreateProductRequest.cs` | New |
| `Registry.Presentation/Products/Requests/UpdateProductRequest.cs` | New |
| `Registry.Presentation/Extensions/EndpointExtensions.cs` | Modify — map Product routes |
| `Registry.Presentation/Funds/Requests/CreateFundRequest.cs` | Modify — `ProductId?` |
| `Registry.Presentation/Funds/Requests/UpdateFundRequest.cs` | Modify — `ProductId?` |
| `Registry.Application/Funds/Commands/CreateFund/CreateFundCommand.cs` | Modify — `ProductId?` |
| `Registry.Application/Funds/Commands/UpdateFund/UpdateFundCommand.cs` | Modify — `ProductId?` |
| Domain + Application test files | New (5 files) |

---

## CLAUDE.md Updates Required

After implementation, update:
- **API Endpoints** section — add Product routes
- **`/.claude/Plans/` index row** — mark this plan

---

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| `ProductId` FK breaks existing Fund seeds | Nullable FK — no impact |
| SQL Server cascade conflict (Product → Fund → FundClass) | `OnDelete(Restrict)` on both hops; soft-delete pattern |
| `FundType` enum overlaps with `ProductType` | Keep both — `ProductType` is scheme-level classification (regulatory), `FundType` is vehicle-level |
| Migration on a running container | `RegistryMigrator.MigrateAsync` handles it; `AddProduct` migration is additive only |
