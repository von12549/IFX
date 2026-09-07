namespace Acme.Sales.Contracts.Context;
public sealed record ContractRequestContext(Guid CorrelationId, Guid TenantId, DateTimeOffset SentAt);
