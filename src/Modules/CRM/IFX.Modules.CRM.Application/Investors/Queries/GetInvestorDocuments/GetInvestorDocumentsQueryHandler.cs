using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.Modules.CRM.Application.Common;
using IFX.Modules.CRM.Application.Common.Authorization;
using IFX.Modules.CRM.Application.Interfaces;
using IFX.Modules.CRM.Application.Investors.DTOs;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.CRM.Application.Investors.Queries.GetInvestorDocuments;

public class GetInvestorDocumentsQueryHandler : IRequestHandler<GetInvestorDocumentsQuery, Result<IReadOnlyList<InvestorDocumentDto>>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ILogger<GetInvestorDocumentsQueryHandler> _logger;

    public GetInvestorDocumentsQueryHandler(
        IUnitOfWork unitOfWork,
        IMapper mapper,
        ICurrentUser currentUser,
        IResourceAuthorizationService authorizationService,
        ILogger<GetInvestorDocumentsQueryHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _logger = logger;
    }

    public async Task<Result<IReadOnlyList<InvestorDocumentDto>>> Handle(GetInvestorDocumentsQuery request, CancellationToken cancellationToken)
    {
        try
        {
            await _authorizationService.AuthorizeWithResolvedPolicyAsync(
                "investor", "read", new TenantScopeResourceAttributes(_currentUser.TenantId), ct: cancellationToken);

            if (_currentUser.TenantId == null)
                return Result<IReadOnlyList<InvestorDocumentDto>>.Failure("Tenant context required.");
            var tenantId = _currentUser.TenantId.Value;

            var documents = await _unitOfWork.InvestorDocuments.GetByInvestorIdAsync(request.InvestorId, tenantId, cancellationToken);
            var dtos = _mapper.Map<IReadOnlyList<InvestorDocumentDto>>(documents);
            return Result<IReadOnlyList<InvestorDocumentDto>>.Success(dtos);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting documents for investor {InvestorId}", request.InvestorId);
            return Result<IReadOnlyList<InvestorDocumentDto>>.Failure("An error occurred.");
        }
    }
}
