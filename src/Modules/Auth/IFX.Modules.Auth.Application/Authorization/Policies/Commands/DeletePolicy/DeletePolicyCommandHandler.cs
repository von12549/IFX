using IFX.BuildingBlocks.Security.Authorization.Abac.Resolver;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.Modules.Auth.Application.Authorization.Policies.Authorization;
using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Authorization.Policies.Commands.DeletePolicy;

public class DeletePolicyCommandHandler : IRequestHandler<DeletePolicyCommand, Result<bool>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly IAbacPolicyCache _policyCache;
    private readonly ILogger<DeletePolicyCommandHandler> _logger;

    public DeletePolicyCommandHandler(
        IUnitOfWork unitOfWork,
        IResourceAuthorizationService authorizationService,
        IAbacPolicyCache policyCache,
        ILogger<DeletePolicyCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _authorizationService = authorizationService;
        _policyCache = policyCache;
        _logger = logger;
    }

    public async Task<Result<bool>> Handle(DeletePolicyCommand request, CancellationToken cancellationToken)
    {
        try
        {
            var policy = await _unitOfWork.PolicyDefinitions.GetByIdAsync(request.PolicyId, cancellationToken);
            if (policy is null)
                return Result<bool>.Failure("Policy not found.");

            await _authorizationService.AuthorizeWithResolvedPolicyAsync(
                "policy", "delete",
                new PolicyResourceAttributes(policy.Id, policy.TenantId, policy.CreatedById),
                ct: cancellationToken);

            _unitOfWork.PolicyDefinitions.Remove(policy);
            await _unitOfWork.SaveChangesAsync(cancellationToken);

            if (policy.TenantId is null)
                _policyCache.InvalidatePlatform(policy.ResourceType, policy.Action);
            else
                _policyCache.Invalidate(policy.TenantId.Value, policy.ResourceType, policy.Action);

            _logger.LogInformation(
                "Policy deleted: {PolicyId} for {Scope} ({ResourceType}/{Action})",
                policy.Id, policy.TenantId is null ? "platform" : policy.TenantId, policy.ResourceType, policy.Action);

            return Result<bool>.Success(true);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error deleting policy {PolicyId}", request.PolicyId);
            return Result<bool>.Failure("An error occurred while deleting the policy.");
        }
    }
}
