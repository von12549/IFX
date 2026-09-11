using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization;
using IFX.Modules.Registry.Application.Common;
using IFX.Modules.Registry.Application.Common.Authorization;
using IFX.Modules.Registry.Application.FundClasses.DTOs;
using IFX.Modules.Registry.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Registry.Application.FundClasses.Commands.UpdateClass;
public class UpdateClassCommandHandler : IRequestHandler<UpdateClassCommand, Result<FundClassDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ILogger<UpdateClassCommandHandler> _logger;
    public UpdateClassCommandHandler(IUnitOfWork unitOfWork, IMapper mapper, ICurrentUser currentUser, IResourceAuthorizationService authorizationService, ILogger<UpdateClassCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _logger = logger;
    }

    public async Task<Result<FundClassDto>> Handle(UpdateClassCommand request, CancellationToken cancellationToken)
    {
        {
            var tenantId = _currentUser.TenantId;
            if (tenantId == null)
                return Result<FundClassDto>.Failure("Tenant context is required.");
            await _authorizationService.AuthorizeWithResolvedPolicyAsync("fundclass", "update", new TenantScopeResourceAttributes(tenantId), ct: cancellationToken);
            var fundClass = await _unitOfWork.FundClasses.GetByIdAsync(request.ClassId, tenantId.Value, cancellationToken);
            if (fundClass == null)
                return Result<FundClassDto>.Failure("Fund class not found.");
            if (fundClass.FundId != request.FundId)
                return Result<FundClassDto>.Failure("Fund class does not belong to the specified fund.");
            fundClass.Update(request.ClassName, request.Currency, request.MinInitialInvestment, request.ManagementFeeRate, request.PerformanceFeeRate, request.NavFrequency);
            _logger.LogInformation("FundClass updated: {ClassId}", fundClass.Id);
            return Result<FundClassDto>.Success(_mapper.Map<FundClassDto>(fundClass));
        }
    }
}
