using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.Modules.CRM.Application.Common;
using IFX.Modules.CRM.Application.Common.Authorization;
using IFX.Modules.CRM.Application.Interfaces;
using IFX.Modules.CRM.Domain.Entities;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.CRM.Application.Investors.Commands.AddInvestorDocument;

public class AddInvestorDocumentCommandHandler : IRequestHandler<AddInvestorDocumentCommand, Result<Unit>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ILogger<AddInvestorDocumentCommandHandler> _logger;

    public AddInvestorDocumentCommandHandler(IUnitOfWork unitOfWork, ICurrentUser currentUser,
        IResourceAuthorizationService authorizationService, ILogger<AddInvestorDocumentCommandHandler> logger)
    {
        _unitOfWork = unitOfWork; _currentUser = currentUser;
        _authorizationService = authorizationService; _logger = logger;
    }

    public async Task<Result<Unit>> Handle(AddInvestorDocumentCommand request, CancellationToken cancellationToken)
    {
        try
        {
            await _authorizationService.AuthorizeWithResolvedPolicyAsync(
                "investor", "update", new TenantScopeResourceAttributes(_currentUser.TenantId), ct: cancellationToken);

            if (_currentUser.TenantId == null) return Result<Unit>.Failure("Tenant context required.");
            var tenantId = _currentUser.TenantId.Value;

            var investor = await _unitOfWork.Investors.GetByIdAsync(request.InvestorId, tenantId, cancellationToken);
            if (investor == null) return Result<Unit>.Failure("Investor not found.");

            var doc = InvestorDocument.Create(request.InvestorId, tenantId, request.DocumentType,
                request.DocumentNumber, request.IssueCountry, request.IssueState, request.IssueDate, request.ExpiryDate);
            doc.CreatedBy = _currentUser.UserId;

            await _unitOfWork.InvestorDocuments.AddAsync(doc, cancellationToken);
            await _unitOfWork.SaveChangesAsync(cancellationToken);
            return Result<Unit>.Success(Unit.Value);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error adding investor document");
            return Result<Unit>.Failure("An error occurred.");
        }
    }
}
