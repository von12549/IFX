using IFX.Modules.Holdings.Abstractions.DTOs;
using IFX.Modules.Holdings.Application.Common;
using MediatR;

namespace IFX.Modules.Holdings.Application.Queries.GetHoldingsByInvestor;

public record GetHoldingsByInvestorQuery(Guid InvestorId) : IRequest<Result<IReadOnlyList<HoldingSummaryDto>>>;
