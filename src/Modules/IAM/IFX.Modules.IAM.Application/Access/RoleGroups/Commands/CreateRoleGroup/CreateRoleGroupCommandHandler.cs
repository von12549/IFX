using IFX.Modules.IAM.Application.Ports.Authorization;
using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization;
using IFX.Modules.IAM.Application.Access.RoleGroups.DTOs;
using IFX.Modules.IAM.Application.Common;
using IFX.Modules.IAM.Application.Common.Authorization;
using IFX.Modules.IAM.Application.Interfaces;
using IFX.Modules.IAM.Domain.Access;
using IFX.Modules.IAM.Domain.Tenancy;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.IAM.Application.Access.RoleGroups.Commands.CreateRoleGroup;
public class CreateRoleGroupCommandHandler : IRequestHandler<CreateRoleGroupCommand, Result<RoleGroupDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ILogger<CreateRoleGroupCommandHandler> _logger;
    public CreateRoleGroupCommandHandler(IUnitOfWork unitOfWork, IMapper mapper, ICurrentUser currentUser, IResourceAuthorizationService authorizationService, ILogger<CreateRoleGroupCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _logger = logger;
    }

    public async Task<Result<RoleGroupDto>> Handle(CreateRoleGroupCommand request, CancellationToken cancellationToken)
    {
        {
            await _authorizationService.AuthorizeWithResolvedPolicyAsync("rolegroup", "create", new TenantScopeResourceAttributes(_currentUser.TenantId), ct: cancellationToken);
            if (await _unitOfWork.RoleGroups.NameExistsAsync(request.Name, request.TenantId, cancellationToken))
                return Result<RoleGroupDto>.Failure($"Role group '{request.Name}' already exists in this tenant");
            var group = RoleGroup.Create(request.Name, request.Description, request.TenantId);
            group.CreatedBy = _currentUser.UserId;
            await _unitOfWork.RoleGroups.AddAsync(group, cancellationToken);
            _logger.LogInformation("Role group created: {Name}", request.Name);
            return Result<RoleGroupDto>.Success(_mapper.Map<RoleGroupDto>(group));
        }
    }
}
