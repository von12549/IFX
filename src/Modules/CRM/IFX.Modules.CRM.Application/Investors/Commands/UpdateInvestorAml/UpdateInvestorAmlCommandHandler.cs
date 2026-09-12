using IFX.Modules.CRM.Application.Ports.Authorization;
using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization;
using IFX.Modules.CRM.Application.Common;
using IFX.Modules.CRM.Application.Common.Authorization;
using IFX.Modules.CRM.Application.Interfaces;
using IFX.Modules.CRM.Application.Investors.DTOs;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.CRM.Application.Investors.Commands.UpdateInvestorAml;
public class UpdateInvestorAmlCommandHandler : IRequestHandler<UpdateInvestorAmlCommand, Result<InvestorDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ILogger<UpdateInvestorAmlCommandHandler> _logger;
    public UpdateInvestorAmlCommandHandler(IUnitOfWork unitOfWork, IMapper mapper, ICurrentUser currentUser, IResourceAuthorizationService authorizationService, ILogger<UpdateInvestorAmlCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _logger = logger;
    }

    public async Task<Result<InvestorDto>> Handle(UpdateInvestorAmlCommand request, CancellationToken cancellationToken)
    {
        {
            if (_currentUser.TenantId == null)
                return Result<InvestorDto>.Failure("Tenant context is required.");
            var investor = await _unitOfWork.Investors.GetByIdAsync(request.InvestorId, _currentUser.TenantId.Value, cancellationToken);
            if (investor == null)
                return Result<InvestorDto>.Failure("Investor not found.");
            await _authorizationService.AuthorizeWithResolvedPolicyAsync("investor", "update", new TenantScopeResourceAttributes(_currentUser.TenantId), ct: cancellationToken);
            investor.UpdateAmlStatus(request.AmlStatus, request.AmlGatewayReference, request.IsPEP, request.PepDetails, request.SourceOfWealth, request.UnresolvedPepCount, request.UnresolvedSanctionCount, request.UnresolvedAdverseMediaCount);
            investor.UpdatedBy = _currentUser.UserId;
            _logger.LogInformation("Investor AML updated: {InvestorId} -> {AmlStatus}", request.InvestorId, request.AmlStatus);
            return Result<InvestorDto>.Success(_mapper.Map<InvestorDto>(investor));
        }
    }
}
