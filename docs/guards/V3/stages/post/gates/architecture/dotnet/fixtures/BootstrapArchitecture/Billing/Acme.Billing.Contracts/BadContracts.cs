using Microsoft.AspNetCore.Http;
namespace Acme.Billing.Internal;

public sealed class BillingDbContext { }
public sealed class BillingHandler { }
public sealed class CompatibilityHandler { }
public sealed record BillingIntegrationEvent(Acme.Sales.Domain.SaleEntity Sale, HttpContext Context);
public static class ReflectionLeak { public const string Type = "MassTransit.ConsumeContext"; }
