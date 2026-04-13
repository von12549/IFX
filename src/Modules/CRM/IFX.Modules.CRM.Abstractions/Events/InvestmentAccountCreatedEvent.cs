using IFX.Platform.Messaging.Abstractions;

namespace IFX.Modules.CRM.Abstractions.Events;

public record InvestmentAccountCreatedEvent(Guid InvestmentAccountId, Guid TenantId, string AccountNumber, string AccountType) : IntegrationEvent;
