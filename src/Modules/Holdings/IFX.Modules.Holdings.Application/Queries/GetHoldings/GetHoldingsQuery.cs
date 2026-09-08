using IFX.Modules.Holdings.Application.DTOs;
using IFX.Modules.Holdings.Application.Common;
using MediatR;

namespace IFX.Modules.Holdings.Application.Queries.GetHoldings;

public record GetHoldingsQuery() : IRequest<Result<IReadOnlyList<HoldingSummaryDto>>>;
