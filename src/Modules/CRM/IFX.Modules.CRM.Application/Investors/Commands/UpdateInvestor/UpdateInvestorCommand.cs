using IFX.Modules.CRM.Application.Common;
using IFX.Modules.CRM.Application.Investors.DTOs;
using IFX.Modules.CRM.Domain.Enums;
using MediatR;

namespace IFX.Modules.CRM.Application.Investors.Commands.UpdateInvestor;

public record UpdateInvestorCommand(Guid InvestorId, string Name, InvestorType Type, string ResidencyCountry, string TaxResidency) : IRequest<Result<InvestorDto>>;
