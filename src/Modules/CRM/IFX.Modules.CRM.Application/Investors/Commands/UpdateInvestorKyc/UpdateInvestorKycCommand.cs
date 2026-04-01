using IFX.Modules.CRM.Application.Common;
using IFX.Modules.CRM.Application.Investors.DTOs;
using IFX.Modules.CRM.Domain.Enums;
using MediatR;

namespace IFX.Modules.CRM.Application.Investors.Commands.UpdateInvestorKyc;

public record UpdateInvestorKycCommand(Guid InvestorId, KycStatus KycStatus) : IRequest<Result<InvestorDto>>;
