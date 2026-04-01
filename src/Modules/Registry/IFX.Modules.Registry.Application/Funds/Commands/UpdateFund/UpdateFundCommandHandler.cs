using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.Modules.Registry.Application.Common;
using IFX.Modules.Registry.Application.Common.Authorization;
using IFX.Modules.Registry.Application.Funds.DTOs;
using IFX.Modules.Registry.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Registry.Application.Funds.Commands.UpdateFund;

public class UpdateFundCommandHandler : IRequestHandler<UpdateFundCommand, Result<FundDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ILogger<UpdateFundCommandHandler> _logger;

    public UpdateFundCommandHandler(
        IUnitOfWork unitOfWork,
        IMapper mapper,
        ICurrentUser currentUser,
        IResourceAuthorizationService authorizationService,
        ILogger<UpdateFundCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _logger = logger;
    }

    public async Task<Result<FundDto>> Handle(UpdateFundCommand request, CancellationToken cancellationToken)
    {
        try
        {
            var tenantId = _currentUser.TenantId;
            if (tenantId == null)
                return Result<FundDto>.Failure("Tenant context is required.");

            await _authorizationService.AuthorizeWithResolvedPolicyAsync(
                "fund", "update",
                new TenantScopeResourceAttributes(tenantId),
                ct: cancellationToken);

            var fund = await _unitOfWork.Funds.GetByIdAsync(request.FundId, tenantId.Value, cancellationToken);
            if (fund == null)
                return Result<FundDto>.Failure("Fund not found.");

            fund.Update(request.FundName, request.FundType, request.BaseCurrency);
            await _unitOfWork.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("Fund updated: {FundId}", fund.Id);
            return Result<FundDto>.Success(_mapper.Map<FundDto>(fund));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error updating fund {FundId}", request.FundId);
            return Result<FundDto>.Failure("An error occurred while updating the fund.");
        }
    }
}
