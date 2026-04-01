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

namespace IFX.Modules.CRM.Application.Investors.Commands.UpdateInvestorKyc;

public class UpdateInvestorKycCommandHandler : IRequestHandler<UpdateInvestorKycCommand, Result<InvestorDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly IIntegrationEventBus _eventBus;
    private readonly ILogger<UpdateInvestorKycCommandHandler> _logger;

    public UpdateInvestorKycCommandHandler(
        IUnitOfWork unitOfWork,
        IMapper mapper,
        ICurrentUser currentUser,
        IResourceAuthorizationService authorizationService,
        IIntegrationEventBus eventBus,
        ILogger<UpdateInvestorKycCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _eventBus = eventBus;
        _logger = logger;
    }

    public async Task<Result<InvestorDto>> Handle(UpdateInvestorKycCommand request, CancellationToken cancellationToken)
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
                "investor", "update",
                resourceAttributes,
                ct: cancellationToken);

            var oldStatus = investor.KycStatus.ToString();
            investor.UpdateKyc(request.KycStatus);
            await _unitOfWork.SaveChangesAsync(cancellationToken);

            await _eventBus.PublishAsync(new InvestorKycStatusChangedEvent(investor.Id, investor.TenantId, oldStatus, investor.KycStatus.ToString()), cancellationToken);

            _logger.LogInformation("Investor KYC updated: {InvestorId} -> {KycStatus}", request.InvestorId, request.KycStatus);
            return Result<InvestorDto>.Success(_mapper.Map<InvestorDto>(investor));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error updating KYC for investor {InvestorId}", request.InvestorId);
            return Result<InvestorDto>.Failure("An error occurred while updating investor KYC.");
        }
    }
}
