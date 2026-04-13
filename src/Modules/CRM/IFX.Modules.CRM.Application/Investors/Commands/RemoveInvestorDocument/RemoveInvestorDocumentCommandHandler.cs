using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.Modules.CRM.Application.Common;
using IFX.Modules.CRM.Application.Common.Authorization;
using IFX.Modules.CRM.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.CRM.Application.Investors.Commands.RemoveInvestorDocument;

public class RemoveInvestorDocumentCommandHandler : IRequestHandler<RemoveInvestorDocumentCommand, Result<Unit>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ILogger<RemoveInvestorDocumentCommandHandler> _logger;

    public RemoveInvestorDocumentCommandHandler(IUnitOfWork unitOfWork, ICurrentUser currentUser,
        IResourceAuthorizationService authorizationService, ILogger<RemoveInvestorDocumentCommandHandler> logger)
    {
        _unitOfWork = unitOfWork; _currentUser = currentUser;
        _authorizationService = authorizationService; _logger = logger;
    }

    public async Task<Result<Unit>> Handle(RemoveInvestorDocumentCommand request, CancellationToken cancellationToken)
    {
        try
        {
            await _authorizationService.AuthorizeWithResolvedPolicyAsync(
                "investor", "update", new TenantScopeResourceAttributes(_currentUser.TenantId), ct: cancellationToken);

            if (_currentUser.TenantId == null) return Result<Unit>.Failure("Tenant context required.");
            var doc = await _unitOfWork.InvestorDocuments.GetByIdAsync(request.DocumentId, _currentUser.TenantId.Value, cancellationToken);
            if (doc == null || doc.InvestorId != request.InvestorId) return Result<Unit>.Failure("Document not found.");

            _unitOfWork.InvestorDocuments.Remove(doc);
            await _unitOfWork.SaveChangesAsync(cancellationToken);
            return Result<Unit>.Success(Unit.Value);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error removing investor document");
            return Result<Unit>.Failure("An error occurred.");
        }
    }
}
