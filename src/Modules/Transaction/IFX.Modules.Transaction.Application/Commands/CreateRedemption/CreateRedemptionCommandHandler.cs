using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.Modules.CRM.Abstractions.Interfaces;
using IFX.Modules.Transaction.Abstractions.Events;
using IFX.Modules.Transaction.Application.Common;
using IFX.Modules.Transaction.Application.Common.Authorization;
using IFX.Modules.Transaction.Application.DTOs;
using IFX.Modules.Transaction.Application.Interfaces;
using IFX.Platform.Messaging.Abstractions;
using MediatR;
using Microsoft.Extensions.Logging;
using TxEntity = IFX.Modules.Transaction.Domain.Entities.Transaction;

namespace IFX.Modules.Transaction.Application.Commands.CreateRedemption;

public class CreateRedemptionCommandHandler : IRequestHandler<CreateRedemptionCommand, Result<TransactionDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ICrmReader _crmReader;
    private readonly IIntegrationEventBus _eventBus;
    private readonly ILogger<CreateRedemptionCommandHandler> _logger;

    public CreateRedemptionCommandHandler(
        IUnitOfWork unitOfWork, IMapper mapper, ICurrentUser currentUser,
        IResourceAuthorizationService authorizationService,
        ICrmReader crmReader,
        IIntegrationEventBus eventBus, ILogger<CreateRedemptionCommandHandler> logger)
    {
        _unitOfWork = unitOfWork; _mapper = mapper; _currentUser = currentUser;
        _authorizationService = authorizationService; _crmReader = crmReader;
        _eventBus = eventBus; _logger = logger;
    }

    public async Task<Result<TransactionDto>> Handle(CreateRedemptionCommand request, CancellationToken cancellationToken)
    {
        try
        {
            await _authorizationService.AuthorizeWithResolvedPolicyAsync(
                "transaction", "create", new TenantScopeResourceAttributes(_currentUser.TenantId), ct: cancellationToken);

            if (_currentUser.TenantId == null)
                return Result<TransactionDto>.Failure("Tenant context required.");

            var tenantId = _currentUser.TenantId.Value;

            // Validate KYC — must be approved to redeem
            if (!await _crmReader.IsInvestmentAccountKycApprovedAsync(request.InvestmentAccountId, tenantId, cancellationToken))
                return Result<TransactionDto>.Failure("Investment account KYC is not approved.");

            var tx = TxEntity.CreateRedemption(tenantId, request.InvestmentAccountId, request.FundId, request.ClassId, request.Amount, request.TradeDate);
            tx.CreatedBy = _currentUser.UserId;

            await _unitOfWork.Transactions.AddAsync(tx, cancellationToken);
            await _unitOfWork.SaveChangesAsync(cancellationToken);

            await _eventBus.PublishAsync(new TransactionCreatedEvent(tx.Id, tenantId, tx.Type.ToString(), tx.InvestmentAccountId, tx.ClassId, tx.Amount), cancellationToken);

            _logger.LogInformation("Redemption created: {TransactionId}", tx.Id);
            return Result<TransactionDto>.Success(_mapper.Map<TransactionDto>(tx));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error creating redemption");
            return Result<TransactionDto>.Failure("An error occurred while creating the redemption.");
        }
    }
}
