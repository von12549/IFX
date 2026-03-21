using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Identity.DTOs;
using MediatR;

namespace IFX.Modules.Auth.Application.Identity.Queries.GetIdpById;

public record GetIdpByIdQuery(Guid IdpId) : IRequest<Result<IdpDto>>;
