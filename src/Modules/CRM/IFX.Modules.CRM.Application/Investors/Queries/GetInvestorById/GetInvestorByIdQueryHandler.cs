using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization;

using IFX.Modules.CRM.Application.Common;
using IFX.Modules.CRM.Application.Common.Authorization;
using IFX.Modules.CRM.Application.Interfaces;
using IFX.Modules.CRM.Application.Investors.DTOs;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.CRM.Application.Investors.Queries.GetInvestorById;

public class GetInvestorByIdQueryHandler : IRequestHandler<GetInvestorByIdQuery, Result<InvestorDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ILogger<GetInvestorByIdQueryHandler> _logger;

    public GetInvestorByIdQueryHandler(
        IUnitOfWork unitOfWork,
        IMapper mapper,
        ICurrentUser currentUser,
        IResourceAuthorizationService authorizationService,
        ILogger<GetInvestorByIdQueryHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _logger = logger;
    }

    public async Task<Result<InvestorDto>> Handle(GetInvestorByIdQuery request, CancellationToken cancellationToken)
    {
        try
        {
            if (_currentUser.TenantId == null)
                return Result<InvestorDto>.Failure("Tenant context is required.");

            var investor = await _unitOfWork.Investors.GetByIdAsync(request.InvestorId, _currentUser.TenantId.Value, cancellationToken);
            if (investor == null)
                return Result<InvestorDto>.Failure("Investor not found.");

            var resourceAttributes = new TenantScopeResourceAttributes(_currentUser.TenantId);

            await _authorizationService.AuthorizeWithResolvedPolicyAsync(
                "investor", "read",
                resourceAttributes,
                ct: cancellationToken);

            return Result<InvestorDto>.Success(_mapper.Map<InvestorDto>(investor));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving investor {InvestorId}", request.InvestorId);
            return Result<InvestorDto>.Failure("An error occurred while retrieving the investor.");
        }
    }
}
