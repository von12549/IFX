using IFX.Modules.Auth.Application.Authorization.Policies.DTOs;
using IFX.Modules.Auth.Application.Common;
using MediatR;

namespace IFX.Modules.Auth.Application.Authorization.Policies.Queries.GetPlatformPolicies;

public record GetPlatformPoliciesQuery : IRequest<Result<List<PolicyDefinitionDto>>>;
