using IFX.Modules.IAM.Application.Common;
using IFX.Modules.IAM.Application.Identity.DTOs;
using MediatR;

namespace IFX.Modules.IAM.Application.Identity.Queries.GetAllIdps;

public record GetAllIdpsQuery : IRequest<Result<List<IdpDto>>>;
