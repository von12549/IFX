using Acme.Sales.Contracts.Events;
using Acme.Billing.Application.Ports;
using Acme.Billing.Contracts;
namespace Acme.Billing.Infrastructure.Integrations;
public sealed class EmbeddedSalesAdapter : ISalesPort { private SaleCompletedIntegrationEvent? current; }
public sealed class BillingInboundAdapter : IBillingContract { }
public sealed class BrokenInboundAdapter { }
