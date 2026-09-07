using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.CRM.Application.Transactions;
using IFX.Modules.CRM.Application.Common;
using IFX.Modules.CRM.Domain.Enums;
using MediatR;

namespace IFX.Modules.CRM.Application.Parties.Commands.RemovePartyRole;

public record RemovePartyRoleCommand(Guid PartyId, PartyFunctionalRole Role) : ICommand<Result<Unit>, CrmTransactionOwner>;
