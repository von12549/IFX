using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.Modules.CRM.Application.Common;
using IFX.Modules.CRM.Application.Common.Authorization;
using IFX.Modules.CRM.Application.Interfaces;
using IFX.Modules.CRM.Domain.Entities;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.CRM.Application.Parties.Commands.AssignPartyRole;

public class AssignPartyRoleCommandHandler : IRequestHandler<AssignPartyRoleCommand, Result<Unit>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ILogger<AssignPartyRoleCommandHandler> _logger;

    public AssignPartyRoleCommandHandler(IUnitOfWork unitOfWork, ICurrentUser currentUser,
        IResourceAuthorizationService authorizationService, ILogger<AssignPartyRoleCommandHandler> logger)
    {
        _unitOfWork = unitOfWork; _currentUser = currentUser;
        _authorizationService = authorizationService; _logger = logger;
    }

    public async Task<Result<Unit>> Handle(AssignPartyRoleCommand request, CancellationToken cancellationToken)
    {
        try
        {
            await _authorizationService.AuthorizeWithResolvedPolicyAsync(
                "party", "update", new TenantScopeResourceAttributes(_currentUser.TenantId), ct: cancellationToken);

            if (_currentUser.TenantId == null) return Result<Unit>.Failure("Tenant context required.");
            var tenantId = _currentUser.TenantId.Value;

            var party = await _unitOfWork.Parties.GetByIdAsync(request.PartyId, tenantId, cancellationToken);
            if (party == null) return Result<Unit>.Failure("Party not found.");

            if (await _unitOfWork.PartyRoleAssignments.HasRoleAsync(request.PartyId, request.Role, tenantId, cancellationToken))
                return Result<Unit>.Failure($"Party already has role '{request.Role}'.");

            var assignment = PartyRoleAssignment.Assign(tenantId, request.PartyId, request.Role, _currentUser.UserId);
            assignment.CreatedBy = _currentUser.UserId;
            await _unitOfWork.PartyRoleAssignments.AddAsync(assignment, cancellationToken);
            await _unitOfWork.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("Role {Role} assigned to party {PartyId}", request.Role, request.PartyId);
            return Result<Unit>.Success(Unit.Value);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error assigning role {Role} to party {PartyId}", request.Role, request.PartyId);
            return Result<Unit>.Failure("An error occurred while assigning the role.");
        }
    }
}
