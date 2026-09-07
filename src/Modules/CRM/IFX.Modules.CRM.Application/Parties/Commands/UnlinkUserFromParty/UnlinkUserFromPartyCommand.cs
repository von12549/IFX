using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.CRM.Application.Transactions;
using IFX.Modules.CRM.Application.Common;
using MediatR;

namespace IFX.Modules.CRM.Application.Parties.Commands.UnlinkUserFromParty;

public record UnlinkUserFromPartyCommand(Guid UserId) : ICommand<Result<Unit>, CrmTransactionOwner>;
