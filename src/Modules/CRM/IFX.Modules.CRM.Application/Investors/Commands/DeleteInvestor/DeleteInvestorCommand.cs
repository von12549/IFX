using IFX.Modules.CRM.Application.Common;
using MediatR;

namespace IFX.Modules.CRM.Application.Investors.Commands.DeleteInvestor;

public record DeleteInvestorCommand(Guid InvestorId) : IRequest<Result<bool>>;
