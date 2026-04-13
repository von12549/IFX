using IFX.Modules.CRM.Application.Common;
using IFX.Modules.CRM.Application.Investors.DTOs;
using MediatR;

namespace IFX.Modules.CRM.Application.Investors.Commands.UpdateInvestor;

public record UpdateInvestorCommand(
    Guid InvestorId,
    string Name,
    string? TaxResidencyCountry,
    string? TIN,
    string? GIIN) : IRequest<Result<InvestorDto>>;
