using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.Modules.Auth.Application.Authorization.RoleGroups.DTOs;
using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Common.Authorization;
using IFX.Modules.Auth.Application.Interfaces;
using IFX.Modules.Auth.Domain.Authorization;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Authorization.RoleGroups.Commands.CreateRoleGroup;
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
