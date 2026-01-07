using AuthSamples.Modules.Cognito.Application.Common;
using AuthSamples.Modules.Cognito.Application.DTOs;
using MediatR;

namespace AuthSamples.Modules.Cognito.Application.Queries.GetAllRoles;

public record GetAllRolesQuery() : IRequest<Result<List<UserRoleDto>>>;
