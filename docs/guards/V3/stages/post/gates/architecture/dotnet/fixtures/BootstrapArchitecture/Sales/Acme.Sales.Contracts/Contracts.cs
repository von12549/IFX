namespace Acme.Sales.Contracts.Events;

public sealed record SaleCompletedIntegrationEvent(Guid EventId, decimal Amount);
