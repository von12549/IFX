using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.Modules.CRM.Application.Common;
using IFX.Modules.CRM.Application.Common.Authorization;
using IFX.Modules.CRM.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.CRM.Application.Parties.Commands.RemovePartyRole;

public class RemovePartyRoleCommandHandler : IRequestHandler<RemovePartyRoleCommand, Result<Unit>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ILogger<RemovePartyRoleCommandHandler> _logger;

    public RemovePartyRoleCommandHandler(IUnitOfWork unitOfWork, ICurrentUser currentUser,
        IResourceAuthorizationService authorizationService, ILogger<RemovePartyRoleCommandHandler> logger)
    {
        _unitOfWork = unitOfWork; _currentUser = currentUser;
        _authorizationService = authorizationService; _logger = logger;
    }

    public async Task<Result<Unit>> Handle(RemovePartyRoleCommand request, CancellationToken cancellationToken)
    {
        try
        {
            await _authorizationService.AuthorizeWithResolvedPolicyAsync(
                "party", "update", new TenantScopeResourceAttributes(_currentUser.TenantId), ct: cancellationToken);

            if (_currentUser.TenantId == null) return Result<Unit>.Failure("Tenant context required.");
            var tenantId = _currentUser.TenantId.Value;

            var assignment = await _unitOfWork.PartyRoleAssignments.GetAsync(request.PartyId, request.Role, tenantId, cancellationToken);
            if (assignment == null) return Result<Unit>.Failure("Role assignment not found.");

            _unitOfWork.PartyRoleAssignments.Remove(assignment);
            await _unitOfWork.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("Role {Role} removed from party {PartyId}", request.Role, request.PartyId);
            return Result<Unit>.Success(Unit.Value);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error removing role {Role} from party {PartyId}", request.Role, request.PartyId);
            return Result<Unit>.Failure("An error occurred while removing the role.");
        }
    }
}
