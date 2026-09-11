using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization;
using IFX.Modules.Registry.Application.Common;
using IFX.Modules.Registry.Application.Common.Authorization;
using IFX.Modules.Registry.Application.Funds.DTOs;
using IFX.Modules.Registry.Application.Interfaces;
using IFX.Modules.Registry.Domain.Entities;
using MediatR;
using Microsoft.Extensions.Logging;
using IFX.BuildingBlocks.Application.Events;

namespace IFX.Modules.Registry.Application.Funds.Commands.CreateFund;
public class CreateFundCommandHandler : IRequestHandler<CreateFundCommand, Result<FundDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ICommittedEventBuffer _eventBuffer;
    private readonly ILogger<CreateFundCommandHandler> _logger;
    public CreateFundCommandHandler(IUnitOfWork unitOfWork, IMapper mapper, ICurrentUser currentUser, IResourceAuthorizationService authorizationService, ICommittedEventBuffer eventBuffer, ILogger<CreateFundCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _eventBuffer = eventBuffer;
        _logger = logger;
    }

    public async Task<Result<FundDto>> Handle(CreateFundCommand request, CancellationToken cancellationToken)
    {
        {
            var tenantId = _currentUser.TenantId;
            if (tenantId == null)
                return Result<FundDto>.Failure("Tenant context is required.");
            await _authorizationService.AuthorizeWithResolvedPolicyAsync("fund", "create", new TenantScopeResourceAttributes(tenantId), ct: cancellationToken);
            if (await _unitOfWork.Funds.CodeExistsAsync(request.FundCode, tenantId.Value, cancellationToken))
                return Result<FundDto>.Failure($"Fund code '{request.FundCode}' already exists in this tenant.");
            var fund = Fund.Create(tenantId.Value, request.FundCode, request.FundName, request.FundType, request.BaseCurrency, request.InceptionDate);
            if (request.ProductId.HasValue)
                fund.SetProduct(request.ProductId.Value);
            fund.CreatedBy = _currentUser.UserId;
            await _unitOfWork.Funds.AddAsync(fund, cancellationToken);
            _logger.LogInformation("Fund created: {FundCode} in tenant {TenantId}", fund.FundCode, fund.TenantId);
            return Result<FundDto>.Success(_mapper.Map<FundDto>(fund));
        }
    }
}
