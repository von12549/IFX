using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization;
using IFX.Modules.Registry.Application.Common;
using IFX.Modules.Registry.Application.Common.Authorization;
using IFX.Modules.Registry.Application.Funds.DTOs;
using IFX.Modules.Registry.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;
using IFX.BuildingBlocks.Application.Events;

namespace IFX.Modules.Registry.Application.Funds.Commands.DeleteFund;
public class DeleteFundCommandHandler : IRequestHandler<DeleteFundCommand, Result<FundDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ICommittedEventBuffer _eventBuffer;
    private readonly ILogger<DeleteFundCommandHandler> _logger;
    public DeleteFundCommandHandler(IUnitOfWork unitOfWork, IMapper mapper, ICurrentUser currentUser, IResourceAuthorizationService authorizationService, ICommittedEventBuffer eventBuffer, ILogger<DeleteFundCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _eventBuffer = eventBuffer;
        _logger = logger;
    }

    public async Task<Result<FundDto>> Handle(DeleteFundCommand request, CancellationToken cancellationToken)
    {
        {
            var tenantId = _currentUser.TenantId;
            if (tenantId == null)
                return Result<FundDto>.Failure("Tenant context is required.");
            await _authorizationService.AuthorizeWithResolvedPolicyAsync("fund", "delete", new TenantScopeResourceAttributes(tenantId), ct: cancellationToken);
            var fund = await _unitOfWork.Funds.GetByIdAsync(request.FundId, tenantId.Value, cancellationToken);
            if (fund == null)
                return Result<FundDto>.Failure("Fund not found.");
            var oldStatus = fund.Status.ToString();
            fund.Close();
            _logger.LogInformation("Fund closed: {FundId}", fund.Id);
            return Result<FundDto>.Success(_mapper.Map<FundDto>(fund));
        }
    }
}
