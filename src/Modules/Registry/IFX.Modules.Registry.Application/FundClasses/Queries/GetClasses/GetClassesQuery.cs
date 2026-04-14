using IFX.Modules.Registry.Application.Common;
using IFX.Modules.Registry.Application.FundClasses.DTOs;
using MediatR;

namespace IFX.Modules.Registry.Application.FundClasses.Queries.GetClasses;

public record GetClassesQuery(Guid FundId) : IRequest<Result<List<FundClassDto>>>;
