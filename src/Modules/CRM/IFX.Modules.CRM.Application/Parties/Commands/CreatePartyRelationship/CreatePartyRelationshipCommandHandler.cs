using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.Modules.CRM.Application.Common;
using IFX.Modules.CRM.Application.Common.Authorization;
using IFX.Modules.CRM.Application.Interfaces;
using IFX.Modules.CRM.Domain.Entities;
using IFX.Modules.CRM.Domain.Enums;
using MediatR;
using Microsoft.Extensions.Logging;
using IFX.BuildingBlocks.Application.Events;

namespace IFX.Modules.CRM.Application.Parties.Commands.CreatePartyRelationship;
public class CreatePartyRelationshipCommandHandler : IRequestHandler<CreatePartyRelationshipCommand, Result<Unit>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ICommittedEventBuffer _eventBuffer;
    private readonly ILogger<CreatePartyRelationshipCommandHandler> _logger;
    public CreatePartyRelationshipCommandHandler(IUnitOfWork unitOfWork, ICurrentUser currentUser, IResourceAuthorizationService authorizationService, ICommittedEventBuffer eventBuffer, ILogger<CreatePartyRelationshipCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _eventBuffer = eventBuffer;
        _logger = logger;
    }

    public async Task<Result<Unit>> Handle(CreatePartyRelationshipCommand request, CancellationToken cancellationToken)
    {
        {
            await _authorizationService.AuthorizeWithResolvedPolicyAsync("party", "update", new TenantScopeResourceAttributes(_currentUser.TenantId), ct: cancellationToken);
            if (_currentUser.TenantId == null)
                return Result<Unit>.Failure("Tenant context required.");
            var tenantId = _currentUser.TenantId.Value;
            var directionError = await ValidateDirectionAsync(request, tenantId, cancellationToken);
            if (directionError != null)
                return Result<Unit>.Failure(directionError);
            var existing = await _unitOfWork.PartyRelationships.GetAsync(request.FromPartyId, request.ToPartyId, request.RelationshipType, tenantId, cancellationToken);
            if (existing != null && existing.ExpiryDate == null)
                return Result<Unit>.Failure("An active relationship of this type already exists between these parties.");
            var relationship = PartyRelationship.Create(tenantId, request.FromPartyId, request.ToPartyId, request.RelationshipType, request.EffectiveDate);
            relationship.CreatedBy = _currentUser.UserId;
            await _unitOfWork.PartyRelationships.AddAsync(relationship, cancellationToken);
            _logger.LogInformation("PartyRelationship {Type} created: {From} -> {To}", request.RelationshipType, request.FromPartyId, request.ToPartyId);
            return Result<Unit>.Success(Unit.Value);
        }
    }

    private async Task<string?> ValidateDirectionAsync(CreatePartyRelationshipCommand request, Guid tenantId, CancellationToken ct)
    {
        switch (request.RelationshipType)
        {
            case PartyRelationshipType.ParentFirm:
                var fromHasAdvisoryRole = await _unitOfWork.PartyRoleAssignments.HasRoleAsync(request.FromPartyId, PartyFunctionalRole.AdvisorRep, tenantId, ct) || await _unitOfWork.PartyRoleAssignments.HasRoleAsync(request.FromPartyId, PartyFunctionalRole.AdvisoryBranch, tenantId, ct);
                if (!fromHasAdvisoryRole)
                    return "For ParentFirm: FromParty must have role AdvisorRep or AdvisoryBranch.";
                var toHasFirmRole = await _unitOfWork.PartyRoleAssignments.HasRoleAsync(request.ToPartyId, PartyFunctionalRole.AdvisoryFirm, tenantId, ct) || await _unitOfWork.PartyRoleAssignments.HasRoleAsync(request.ToPartyId, PartyFunctionalRole.AdvisoryBranch, tenantId, ct);
                if (!toHasFirmRole)
                    return "For ParentFirm: ToParty must have role AdvisoryFirm or AdvisoryBranch.";
                break;
            case PartyRelationshipType.AuthorizedToAdvise:
                var fromHasAnyAdvisoryRole = await _unitOfWork.PartyRoleAssignments.HasRoleAsync(request.FromPartyId, PartyFunctionalRole.AdvisorRep, tenantId, ct) || await _unitOfWork.PartyRoleAssignments.HasRoleAsync(request.FromPartyId, PartyFunctionalRole.AdvisoryFirm, tenantId, ct) || await _unitOfWork.PartyRoleAssignments.HasRoleAsync(request.FromPartyId, PartyFunctionalRole.AdvisoryBranch, tenantId, ct);
                if (!fromHasAnyAdvisoryRole)
                    return "For AuthorizedToAdvise: FromParty must have an advisory role (AdvisoryFirm, AdvisoryBranch, or AdvisorRep).";
                break;
        }

        return null;
    }
}
