using IFX.Modules.Holdings.Application.DTOs;
using IFX.Modules.Holdings.Application.Common;
using MediatR;

namespace IFX.Modules.Holdings.Application.Queries.GetHoldingById;

public record GetHoldingByIdQuery(Guid HoldingId) : IRequest<Result<HoldingSummaryDto>>;
