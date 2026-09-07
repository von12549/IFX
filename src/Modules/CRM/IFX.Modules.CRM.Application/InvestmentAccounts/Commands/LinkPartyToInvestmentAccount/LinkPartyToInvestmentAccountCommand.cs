using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.CRM.Application.Transactions;
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
    int? LinkOrder) : ICommand<Result<Unit>, CrmTransactionOwner>;
