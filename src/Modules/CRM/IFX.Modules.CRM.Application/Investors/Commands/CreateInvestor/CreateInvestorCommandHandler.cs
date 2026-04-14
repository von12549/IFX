using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.Modules.CRM.Abstractions.Events;
using IFX.Modules.CRM.Application.Common;
using IFX.Modules.CRM.Application.Common.Authorization;
using IFX.Modules.CRM.Application.Interfaces;
using IFX.Modules.CRM.Application.Investors.DTOs;
using IFX.Modules.CRM.Domain.Entities;
using IFX.Platform.Messaging.Abstractions;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.CRM.Application.Investors.Commands.CreateInvestor;

public class CreateInvestorCommandHandler : IRequestHandler<CreateInvestorCommand, Result<InvestorDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly IIntegrationEventBus _eventBus;
    private readonly ILogger<CreateInvestorCommandHandler> _logger;

    public CreateInvestorCommandHandler(
        IUnitOfWork unitOfWork,
        IMapper mapper,
        ICurrentUser currentUser,
        IResourceAuthorizationService authorizationService,
        IIntegrationEventBus eventBus,
        ILogger<CreateInvestorCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _eventBus = eventBus;
        _logger = logger;
    }

    public async Task<Result<InvestorDto>> Handle(CreateInvestorCommand request, CancellationToken cancellationToken)
    {
        try
        {
            await _authorizationService.AuthorizeWithResolvedPolicyAsync(
                "investor", "create",
                new TenantScopeResourceAttributes(_currentUser.TenantId),
                ct: cancellationToken);

            if (_currentUser.TenantId == null)
                return Result<InvestorDto>.Failure("Tenant context is required.");

            if (await _unitOfWork.Investors.CodeExistsAsync(request.InvestorCode, _currentUser.TenantId.Value, cancellationToken))
                return Result<InvestorDto>.Failure($"Investor code '{request.InvestorCode}' already exists in this tenant.");

            var investor = Investor.Create(_currentUser.TenantId.Value, request.InvestorCode, request.Name, request.LegalStructure, request.TaxResidencyCountry, request.PartyId);
            investor.CreatedBy = _currentUser.UserId;

            await _unitOfWork.Investors.AddAsync(investor, cancellationToken);
            await _unitOfWork.SaveChangesAsync(cancellationToken);

            await _eventBus.PublishAsync(new InvestorCreatedEvent(investor.Id, investor.TenantId, investor.InvestorCode, investor.Name), cancellationToken);

            _logger.LogInformation("Investor created: {InvestorCode} in tenant {TenantId}", investor.InvestorCode, investor.TenantId);
            return Result<InvestorDto>.Success(_mapper.Map<InvestorDto>(investor));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error creating investor {InvestorCode}", request.InvestorCode);
            return Result<InvestorDto>.Failure("An error occurred while creating the investor.");
        }
    }
}
