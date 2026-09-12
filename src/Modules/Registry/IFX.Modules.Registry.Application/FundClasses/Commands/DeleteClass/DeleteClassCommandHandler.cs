using IFX.Modules.Registry.Application.Ports.Authorization;
using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization;
using IFX.Modules.Registry.Contracts.V1.Events;
using IFX.Modules.Registry.Application.Common;
using IFX.Modules.Registry.Application.Common.Authorization;
using IFX.Modules.Registry.Application.FundClasses.DTOs;
using IFX.Modules.Registry.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;
using IFX.BuildingBlocks.Application.Events;

namespace IFX.Modules.Registry.Application.FundClasses.Commands.DeleteClass;
public class DeleteClassCommandHandler : IRequestHandler<DeleteClassCommand, Result<FundClassDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ICommittedEventBuffer _eventBuffer;
    private readonly ILogger<DeleteClassCommandHandler> _logger;
    public DeleteClassCommandHandler(IUnitOfWork unitOfWork, IMapper mapper, ICurrentUser currentUser, IResourceAuthorizationService authorizationService, ICommittedEventBuffer eventBuffer, ILogger<DeleteClassCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _eventBuffer = eventBuffer;
        _logger = logger;
    }

    public async Task<Result<FundClassDto>> Handle(DeleteClassCommand request, CancellationToken cancellationToken)
    {
        {
            var tenantId = _currentUser.TenantId;
            if (tenantId == null)
                return Result<FundClassDto>.Failure("Tenant context is required.");
            await _authorizationService.AuthorizeWithResolvedPolicyAsync("fundclass", "delete", new TenantScopeResourceAttributes(tenantId), ct: cancellationToken);
            var fundClass = await _unitOfWork.FundClasses.GetByIdAsync(request.ClassId, tenantId.Value, cancellationToken);
            if (fundClass == null)
                return Result<FundClassDto>.Failure("Fund class not found.");
            if (fundClass.FundId != request.FundId)
                return Result<FundClassDto>.Failure("Fund class does not belong to the specified fund.");
            var oldStatus = fundClass.Status.ToString();
            fundClass.Close();
            _eventBuffer.Add(new ClassStatusChangedV1(fundClass.Id, fundClass.FundId, oldStatus, fundClass.Status.ToString()));
            _logger.LogInformation("FundClass closed: {ClassId}", fundClass.Id);
            return Result<FundClassDto>.Success(_mapper.Map<FundClassDto>(fundClass));
        }
    }
}
