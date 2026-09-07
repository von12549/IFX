using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.CRM.Application.Transactions;
using IFX.Modules.CRM.Application.Common;
using IFX.Modules.CRM.Application.Parties.DTOs;
using IFX.Modules.CRM.Domain.Enums;
using MediatR;

namespace IFX.Modules.CRM.Application.Parties.Commands.CreateParty;

public record CreatePartyCommand(string PartyCode, string Name, PartyLegalStructure LegalStructure) : ICommand<Result<PartyDto>, CrmTransactionOwner>;
