using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.Modules.CRM.Abstractions.Events;
using IFX.Modules.CRM.Application.Common;
using IFX.Modules.CRM.Application.Common.Authorization;
using IFX.Modules.CRM.Application.Interfaces;
using IFX.Modules.CRM.Application.Investors.DTOs;
using IFX.Platform.Messaging.Abstractions;
using MediatR;
using Microsoft.Extensions.Logging;
using IFX.BuildingBlocks.Application.Events;

namespace IFX.Modules.CRM.Application.Investors.Commands.UpdateInvestorKyc;
public class UpdateInvestorKycCommandHandler : IRequestHandler<UpdateInvestorKycCommand, Result<InvestorDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ICommittedEventBuffer _eventBuffer;
    private readonly ILogger<UpdateInvestorKycCommandHandler> _logger;
    public UpdateInvestorKycCommandHandler(IUnitOfWork unitOfWork, IMapper mapper, ICurrentUser currentUser, IResourceAuthorizationService authorizationService, ICommittedEventBuffer eventBuffer, ILogger<UpdateInvestorKycCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _eventBuffer = eventBuffer;
        _logger = logger;
    }

    public async Task<Result<InvestorDto>> Handle(UpdateInvestorKycCommand request, CancellationToken cancellationToken)
    {
        {
            if (_currentUser.TenantId == null)
                return Result<InvestorDto>.Failure("Tenant context is required.");
            var investor = await _unitOfWork.Investors.GetByIdAsync(request.InvestorId, _currentUser.TenantId.Value, cancellationToken);
            if (investor == null)
                return Result<InvestorDto>.Failure("Investor not found.");
            var resourceAttributes = new TenantScopeResourceAttributes(_currentUser.TenantId);
            await _authorizationService.AuthorizeWithResolvedPolicyAsync("investor", "update", resourceAttributes, ct: cancellationToken);
            var oldStatus = investor.KycStatus.ToString();
            investor.UpdateKyc(request.KycStatus);
            _eventBuffer.Add(new InvestorKycStatusChangedEvent(investor.Id, investor.TenantId, oldStatus, investor.KycStatus.ToString()));
            _logger.LogInformation("Investor KYC updated: {InvestorId} -> {KycStatus}", request.InvestorId, request.KycStatus);
            return Result<InvestorDto>.Success(_mapper.Map<InvestorDto>(investor));
        }
    }
}
