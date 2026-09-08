using IFX.Modules.Holdings.Application.DTOs;
using IFX.Modules.Holdings.Application.Common;
using MediatR;

namespace IFX.Modules.Holdings.Application.Queries.GetHoldingsByClass;

public record GetHoldingsByClassQuery(Guid ClassId) : IRequest<Result<IReadOnlyList<HoldingSummaryDto>>>;
