using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.Modules.Registry.Application.Common;
using IFX.Modules.Registry.Application.Common.Authorization;
using IFX.Modules.Registry.Application.FundClasses.DTOs;
using IFX.Modules.Registry.Application.Interfaces;
using IFX.Modules.Registry.Domain.Entities;
using MediatR;
using Microsoft.Extensions.Logging;
using IFX.BuildingBlocks.Application.Events;

namespace IFX.Modules.Registry.Application.FundClasses.Commands.CreateClass;
public class CreateClassCommandHandler : IRequestHandler<CreateClassCommand, Result<FundClassDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ICommittedEventBuffer _eventBuffer;
    private readonly ILogger<CreateClassCommandHandler> _logger;
    public CreateClassCommandHandler(IUnitOfWork unitOfWork, IMapper mapper, ICurrentUser currentUser, IResourceAuthorizationService authorizationService, ICommittedEventBuffer eventBuffer, ILogger<CreateClassCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _eventBuffer = eventBuffer;
        _logger = logger;
    }

    public async Task<Result<FundClassDto>> Handle(CreateClassCommand request, CancellationToken cancellationToken)
    {
        {
            var tenantId = _currentUser.TenantId;
            if (tenantId == null)
                return Result<FundClassDto>.Failure("Tenant context is required.");
            await _authorizationService.AuthorizeWithResolvedPolicyAsync("fundclass", "create", new TenantScopeResourceAttributes(tenantId), ct: cancellationToken);
            var fund = await _unitOfWork.Funds.GetByIdAsync(request.FundId, tenantId.Value, cancellationToken);
            if (fund == null)
                return Result<FundClassDto>.Failure("Fund not found.");
            if (await _unitOfWork.FundClasses.CodeExistsAsync(request.ClassCode, request.FundId, cancellationToken))
                return Result<FundClassDto>.Failure($"Class code '{request.ClassCode}' already exists for this fund.");
            var fundClass = FundClass.Create(request.FundId, tenantId.Value, request.ClassCode, request.ClassName, request.Currency, request.NavFrequency);
            // Apply optional fee fields via Update (keeps fee logic in domain entity)
            if (request.MinInitialInvestment.HasValue || request.ManagementFeeRate.HasValue || request.PerformanceFeeRate.HasValue)
            {
                fundClass.Update(request.ClassName, request.Currency, request.MinInitialInvestment, request.ManagementFeeRate, request.PerformanceFeeRate, request.NavFrequency);
            }

            fundClass.CreatedBy = _currentUser.UserId;
            await _unitOfWork.FundClasses.AddAsync(fundClass, cancellationToken);
            _logger.LogInformation("FundClass created: {ClassCode} for fund {FundId}", fundClass.ClassCode, fundClass.FundId);
            return Result<FundClassDto>.Success(_mapper.Map<FundClassDto>(fundClass));
        }
    }
}
