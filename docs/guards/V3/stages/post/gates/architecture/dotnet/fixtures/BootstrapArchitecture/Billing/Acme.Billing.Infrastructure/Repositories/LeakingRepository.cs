using Acme.Sales.Contracts.Events;
namespace Acme.Billing.Infrastructure.Repositories;
public sealed class LeakingRepository { private SaleCompletedIntegrationEvent? current; }
