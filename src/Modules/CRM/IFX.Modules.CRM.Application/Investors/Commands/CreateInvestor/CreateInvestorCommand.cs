using IFX.Modules.CRM.Application.Common;
using IFX.Modules.CRM.Application.Investors.DTOs;
using IFX.Modules.CRM.Domain.Enums;
using MediatR;

namespace IFX.Modules.CRM.Application.Investors.Commands.CreateInvestor;

public record CreateInvestorCommand(string InvestorCode, string Name, InvestorType Type, string ResidencyCountry, string TaxResidency) : IRequest<Result<InvestorDto>>;
