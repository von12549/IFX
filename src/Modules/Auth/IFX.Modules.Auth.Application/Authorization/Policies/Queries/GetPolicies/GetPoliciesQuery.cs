using IFX.Modules.Auth.Application.Authorization.Policies.DTOs;
using IFX.Modules.Auth.Application.Common;
using MediatR;

namespace IFX.Modules.Auth.Application.Authorization.Policies.Queries.GetPolicies;

public record GetPoliciesQuery(Guid TenantId) : IRequest<Result<List<PolicyDefinitionDto>>>;
