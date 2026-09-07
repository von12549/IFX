using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.Modules.Auth.Application.Authorization.Roles.DTOs;
using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Common.Authorization;
using IFX.Modules.Auth.Application.Interfaces;
using IFX.Modules.Auth.Domain.Authorization;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Authorization.Roles.Commands.CreateRole;
public class CreateRoleCommandHandler : IRequestHandler<CreateRoleCommand, Result<RoleDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ILogger<CreateRoleCommandHandler> _logger;
    public CreateRoleCommandHandler(IUnitOfWork unitOfWork, IMapper mapper, ICurrentUser currentUser, IResourceAuthorizationService authorizationService, ILogger<CreateRoleCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _logger = logger;
    }

    public async Task<Result<RoleDto>> Handle(CreateRoleCommand request, CancellationToken cancellationToken)
    {
        {
            await _authorizationService.AuthorizeWithResolvedPolicyAsync("role", "create", new TenantScopeResourceAttributes(_currentUser.TenantId), ct: cancellationToken);
            if (await _unitOfWork.Roles.NameExistsAsync(request.Name, request.TenantId, cancellationToken))
                return Result<RoleDto>.Failure($"Role name '{request.Name}' already exists in this tenant");
            var role = Role.Create(request.Name, request.Description, request.TenantId);
            role.CreatedBy = _currentUser.UserId;
            await _unitOfWork.Roles.AddAsync(role, cancellationToken);
            _logger.LogInformation("New role created: {Name}", request.Name);
            return Result<RoleDto>.Success(_mapper.Map<RoleDto>(role));
        }
    }
}
