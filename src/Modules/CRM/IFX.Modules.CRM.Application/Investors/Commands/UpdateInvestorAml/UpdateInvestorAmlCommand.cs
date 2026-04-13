using IFX.Modules.CRM.Application.Common;
using IFX.Modules.CRM.Application.Investors.DTOs;
using IFX.Modules.CRM.Domain.Enums;
using MediatR;

namespace IFX.Modules.CRM.Application.Investors.Commands.UpdateInvestorAml;

public record UpdateInvestorAmlCommand(
    Guid InvestorId,
    AmlStatus AmlStatus,
    string? AmlGatewayReference,
    bool? IsPEP,
    string? PepDetails,
    string? SourceOfWealth,
    int UnresolvedPepCount,
    int UnresolvedSanctionCount,
    int UnresolvedAdverseMediaCount) : IRequest<Result<InvestorDto>>;
