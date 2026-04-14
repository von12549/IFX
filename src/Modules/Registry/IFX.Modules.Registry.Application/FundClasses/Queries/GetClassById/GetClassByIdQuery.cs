using IFX.Modules.Registry.Application.Common;
using IFX.Modules.Registry.Application.FundClasses.DTOs;
using MediatR;

namespace IFX.Modules.Registry.Application.FundClasses.Queries.GetClassById;

public record GetClassByIdQuery(Guid ClassId, Guid FundId) : IRequest<Result<FundClassDto>>;
