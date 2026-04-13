using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.Modules.Registry.Abstractions.Events;
using IFX.Modules.Registry.Application.Common;
using IFX.Modules.Registry.Application.Common.Authorization;
using IFX.Modules.Registry.Application.Funds.DTOs;
using IFX.Modules.Registry.Application.Interfaces;
using IFX.Modules.Registry.Domain.Entities;
using IFX.Platform.Messaging.Abstractions;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Registry.Application.Funds.Commands.CreateFund;

public class CreateFundCommandHandler : IRequestHandler<CreateFundCommand, Result<FundDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly IIntegrationEventBus _eventBus;
    private readonly ILogger<CreateFundCommandHandler> _logger;

    public CreateFundCommandHandler(
        IUnitOfWork unitOfWork,
        IMapper mapper,
        ICurrentUser currentUser,
        IResourceAuthorizationService authorizationService,
        IIntegrationEventBus eventBus,
        ILogger<CreateFundCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _eventBus = eventBus;
        _logger = logger;
    }

    public async Task<Result<FundDto>> Handle(CreateFundCommand request, CancellationToken cancellationToken)
    {
        try
        {
            var tenantId = _currentUser.TenantId;
            if (tenantId == null)
                return Result<FundDto>.Failure("Tenant context is required.");

            await _authorizationService.AuthorizeWithResolvedPolicyAsync(
                "fund", "create",
                new TenantScopeResourceAttributes(tenantId),
                ct: cancellationToken);

            if (await _unitOfWork.Funds.CodeExistsAsync(request.FundCode, tenantId.Value, cancellationToken))
                return Result<FundDto>.Failure($"Fund code '{request.FundCode}' already exists in this tenant.");

            var fund = Fund.Create(
                tenantId.Value,
                request.FundCode,
                request.FundName,
                request.FundType,
                request.BaseCurrency,
                request.InceptionDate);

            if (request.ProductId.HasValue)
                fund.SetProduct(request.ProductId.Value);

            fund.CreatedBy = _currentUser.UserId;
            await _unitOfWork.Funds.AddAsync(fund, cancellationToken);
            await _unitOfWork.SaveChangesAsync(cancellationToken);

            await _eventBus.PublishAsync(new FundCreatedEvent(fund.Id, fund.TenantId, fund.FundCode, fund.FundName), cancellationToken);

            _logger.LogInformation("Fund created: {FundCode} in tenant {TenantId}", fund.FundCode, fund.TenantId);
            return Result<FundDto>.Success(_mapper.Map<FundDto>(fund));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error creating fund {FundCode}", request.FundCode);
            return Result<FundDto>.Failure("An error occurred while creating the fund.");
        }
    }
}
