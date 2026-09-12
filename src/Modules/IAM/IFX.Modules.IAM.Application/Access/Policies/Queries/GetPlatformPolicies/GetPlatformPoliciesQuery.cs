using IFX.Modules.IAM.Application.Access.Policies.DTOs;
using IFX.Modules.IAM.Application.Common;
using MediatR;

namespace IFX.Modules.IAM.Application.Access.Policies.Queries.GetPlatformPolicies;

public record GetPlatformPoliciesQuery : IRequest<Result<List<PolicyDefinitionDto>>>;
