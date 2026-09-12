using IFX.Modules.IAM.Application.Ports.Authorization;
using IFX.BuildingBlocks.Security.Authorization;
using IFX.Modules.IAM.Application.Access.Policies.Authorization;
using IFX.Modules.IAM.Application.Common;
using IFX.Modules.IAM.Application.Interfaces;
using IFX.Modules.IAM.Domain.Access;
using IFX.Modules.IAM.Domain.Tenancy;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.IAM.Application.Access.Policies.Commands.DeletePolicy;
public class DeletePolicyCommandHandler : IRequestHandler<DeletePolicyCommand, Result<bool>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ICurrentUser _currentUser;
    private readonly ILogger<DeletePolicyCommandHandler> _logger;
    public DeletePolicyCommandHandler(IUnitOfWork unitOfWork, ICurrentUser currentUser, IResourceAuthorizationService authorizationService, ILogger<DeletePolicyCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _logger = logger;
    }

    public async Task<Result<bool>> Handle(DeletePolicyCommand request, CancellationToken cancellationToken)
    {
        {
            var policy = _currentUser.TenantId is { } tenantId
                ? await _unitOfWork.PolicyDefinitions.GetTenantByIdAsync(request.PolicyId, tenantId, cancellationToken)
                : await _unitOfWork.PolicyDefinitions.GetPlatformByIdAsync(request.PolicyId, cancellationToken);
            if (policy is null)
                return Result<bool>.Failure("Policy not found.");
            if (policy.Scope == PolicyScope.Platform && !_currentUser.IsGlobalAdmin)
                return Result<bool>.Failure("Platform policy management requires PlatformAdmin.");
            await _authorizationService.AuthorizeWithResolvedPolicyAsync("policy", "delete", new PolicyResourceAttributes(policy.Id, policy.TenantId, policy.CreatedById), ct: cancellationToken);
            _unitOfWork.PolicyDefinitions.Remove(policy);
            _logger.LogInformation("Policy deleted: {PolicyId} for {Scope} ({ResourceType}/{Action})", policy.Id, policy.Scope, policy.ResourceType, policy.Action);
            return Result<bool>.Success(true);
        }
    }
}
