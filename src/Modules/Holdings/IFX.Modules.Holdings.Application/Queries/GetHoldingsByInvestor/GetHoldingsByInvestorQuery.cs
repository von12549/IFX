using IFX.Modules.Holdings.Application.DTOs;
using IFX.Modules.Holdings.Application.Common;
using MediatR;

namespace IFX.Modules.Holdings.Application.Queries.GetHoldingsByInvestor;

public record GetHoldingsByInvestorQuery(Guid InvestmentAccountId) : IRequest<Result<IReadOnlyList<HoldingSummaryDto>>>;
