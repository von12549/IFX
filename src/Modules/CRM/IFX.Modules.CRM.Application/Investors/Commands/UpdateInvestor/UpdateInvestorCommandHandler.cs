using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.Modules.CRM.Application.Common;
using IFX.Modules.CRM.Application.Common.Authorization;
using IFX.Modules.CRM.Application.Interfaces;
using IFX.Modules.CRM.Application.Investors.DTOs;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.CRM.Application.Investors.Commands.UpdateInvestor;
public class UpdateInvestorCommandHandler : IRequestHandler<UpdateInvestorCommand, Result<InvestorDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ILogger<UpdateInvestorCommandHandler> _logger;
    public UpdateInvestorCommandHandler(IUnitOfWork unitOfWork, IMapper mapper, ICurrentUser currentUser, IResourceAuthorizationService authorizationService, ILogger<UpdateInvestorCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _logger = logger;
    }

    public async Task<Result<InvestorDto>> Handle(UpdateInvestorCommand request, CancellationToken cancellationToken)
    {
        {
            if (_currentUser.TenantId == null)
                return Result<InvestorDto>.Failure("Tenant context is required.");
            var investor = await _unitOfWork.Investors.GetByIdAsync(request.InvestorId, _currentUser.TenantId.Value, cancellationToken);
            if (investor == null)
                return Result<InvestorDto>.Failure("Investor not found.");
            var resourceAttributes = new TenantScopeResourceAttributes(_currentUser.TenantId);
            await _authorizationService.AuthorizeWithResolvedPolicyAsync("investor", "update", resourceAttributes, ct: cancellationToken);
            investor.Update(request.Name, request.TaxResidencyCountry, request.TIN, request.GIIN);
            _logger.LogInformation("Investor updated: {InvestorId}", request.InvestorId);
            return Result<InvestorDto>.Success(_mapper.Map<InvestorDto>(investor));
        }
    }
}
