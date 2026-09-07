using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.CRM.Application.Transactions;
using IFX.Modules.CRM.Application.Common;
using IFX.Modules.CRM.Application.Parties.DTOs;
using IFX.Modules.CRM.Domain.Enums;
using MediatR;

namespace IFX.Modules.CRM.Application.Parties.Commands.UpdateParty;

public record UpdatePartyCommand(Guid PartyId, string Name, PartyLegalStructure LegalStructure) : ICommand<Result<PartyDto>, CrmTransactionOwner>;
