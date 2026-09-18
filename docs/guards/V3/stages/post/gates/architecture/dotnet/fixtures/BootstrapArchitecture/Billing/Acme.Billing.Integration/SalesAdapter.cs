using Acme.Sales.Contracts.Events;
using Acme.Billing.Application.Ports;
namespace Acme.Billing.Integrations;
public sealed class SalesAdapter : ISalesPort { private SaleCompletedIntegrationEvent? current; }
public sealed class BrokenAdapter { }
