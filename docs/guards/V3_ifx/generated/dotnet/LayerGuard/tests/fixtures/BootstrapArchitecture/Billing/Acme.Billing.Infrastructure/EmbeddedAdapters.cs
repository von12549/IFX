using Acme.Sales.Contracts.Events;
using Acme.Billing.Application.Ports;
namespace Acme.Billing.Infrastructure.Integrations;
public sealed class EmbeddedSalesAdapter : ISalesPort { private SaleCompletedIntegrationEvent? current; }
