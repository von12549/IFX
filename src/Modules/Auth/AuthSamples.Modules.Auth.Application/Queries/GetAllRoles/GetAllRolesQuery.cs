using AuthSamples.Modules.Auth.Application.Common;
using AuthSamples.Modules.Auth.Application.DTOs;
using MediatR;

namespace AuthSamples.Modules.Auth.Application.Queries.GetAllRoles;

public record GetAllRolesQuery() : IRequest<Result<List<UserRoleDto>>>;
