using IFX.Modules.IAM.Application.Common;
using IFX.Modules.IAM.Application.Identity.DTOs;
using MediatR;

namespace IFX.Modules.IAM.Application.Identity.Queries.GetIdpById;

public record GetIdpByIdQuery(Guid IdpId) : IRequest<Result<IdpDto>>;
