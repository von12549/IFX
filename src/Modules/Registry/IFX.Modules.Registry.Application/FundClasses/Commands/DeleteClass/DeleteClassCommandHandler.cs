using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.Modules.Registry.Abstractions.Events;
using IFX.Modules.Registry.Application.Common;
using IFX.Modules.Registry.Application.Common.Authorization;
using IFX.Modules.Registry.Application.FundClasses.DTOs;
using IFX.Modules.Registry.Application.Interfaces;
using IFX.Platform.Messaging.Abstractions;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Registry.Application.FundClasses.Commands.DeleteClass;

public class DeleteClassCommandHandler : IRequestHandler<DeleteClassCommand, Result<FundClassDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly IIntegrationEventBus _eventBus;
    private readonly ILogger<DeleteClassCommandHandler> _logger;

    public DeleteClassCommandHandler(
        IUnitOfWork unitOfWork,
        IMapper mapper,
        ICurrentUser currentUser,
        IResourceAuthorizationService authorizationService,
        IIntegrationEventBus eventBus,
        ILogger<DeleteClassCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _eventBus = eventBus;
        _logger = logger;
    }

    public async Task<Result<FundClassDto>> Handle(DeleteClassCommand request, CancellationToken cancellationToken)
    {
        try
        {
            var tenantId = _currentUser.TenantId;
            if (tenantId == null)
                return Result<FundClassDto>.Failure("Tenant context is required.");

            await _authorizationService.AuthorizeWithResolvedPolicyAsync(
                "fundclass", "delete",
                new TenantScopeResourceAttributes(tenantId),
                ct: cancellationToken);

            var fundClass = await _unitOfWork.FundClasses.GetByIdAsync(request.ClassId, tenantId.Value, cancellationToken);
            if (fundClass == null)
                return Result<FundClassDto>.Failure("Fund class not found.");

            if (fundClass.FundId != request.FundId)
                return Result<FundClassDto>.Failure("Fund class does not belong to the specified fund.");

            var oldStatus = fundClass.Status.ToString();
            fundClass.Close();
            await _unitOfWork.SaveChangesAsync(cancellationToken);

            await _eventBus.PublishAsync(new ClassStatusChangedEvent(fundClass.Id, fundClass.FundId, fundClass.TenantId, oldStatus, fundClass.Status.ToString()), cancellationToken);

            _logger.LogInformation("FundClass closed: {ClassId}", fundClass.Id);
            return Result<FundClassDto>.Success(_mapper.Map<FundClassDto>(fundClass));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error closing fund class {ClassId}", request.ClassId);
            return Result<FundClassDto>.Failure("An error occurred while closing the fund class.");
        }
    }
}
