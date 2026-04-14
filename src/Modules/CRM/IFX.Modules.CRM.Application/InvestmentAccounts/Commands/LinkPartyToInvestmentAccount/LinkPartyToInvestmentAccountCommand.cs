using IFX.Modules.CRM.Application.Common;
using IFX.Modules.CRM.Domain.Enums;
using MediatR;

namespace IFX.Modules.CRM.Application.InvestmentAccounts.Commands.LinkPartyToInvestmentAccount;

public record LinkPartyToInvestmentAccountCommand(
    Guid InvestmentAccountId,
    Guid PartyId,
    InvestmentAccountRelationshipType RelationshipType,
    DateOnly EffectiveDate,
    decimal? OwnershipPercentage,
    int? LinkOrder) : IRequest<Result<Unit>>;
