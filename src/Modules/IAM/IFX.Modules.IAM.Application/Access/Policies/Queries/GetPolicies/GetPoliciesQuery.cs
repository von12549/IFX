using IFX.Modules.IAM.Application.Access.Policies.DTOs;
using IFX.Modules.IAM.Application.Common;
using MediatR;

namespace IFX.Modules.IAM.Application.Access.Policies.Queries.GetPolicies;

public record GetPoliciesQuery(Guid TenantId) : IRequest<Result<List<PolicyDefinitionDto>>>;
