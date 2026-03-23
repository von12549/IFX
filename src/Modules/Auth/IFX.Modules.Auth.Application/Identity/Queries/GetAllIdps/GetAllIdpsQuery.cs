using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Identity.DTOs;
using MediatR;

namespace IFX.Modules.Auth.Application.Identity.Queries.GetAllIdps;

public record GetAllIdpsQuery : IRequest<Result<List<IdpDto>>>;
