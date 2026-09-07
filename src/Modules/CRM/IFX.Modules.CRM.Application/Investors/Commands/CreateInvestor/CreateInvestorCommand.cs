using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.CRM.Application.Transactions;
using IFX.Modules.CRM.Application.Common;
using IFX.Modules.CRM.Application.Investors.DTOs;
using IFX.Modules.CRM.Domain.Enums;
using MediatR;

namespace IFX.Modules.CRM.Application.Investors.Commands.CreateInvestor;


public record CreateInvestorCommand(
    string InvestorCode,
    string Name,
    PartyLegalStructure LegalStructure,
    string? TaxResidencyCountry = null,
    Guid? PartyId = null) : ICommand<Result<InvestorDto>, CrmTransactionOwner>;
