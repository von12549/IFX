using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.DTOs;
using MediatR;

namespace IFX.Modules.Auth.Application.Queries.GetAllIdps;

public record GetAllIdpsQuery() : IRequest<Result<List<IdpDto>>>;
