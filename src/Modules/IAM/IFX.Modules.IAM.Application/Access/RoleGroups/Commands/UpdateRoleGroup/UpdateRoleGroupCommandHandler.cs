using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization;
using IFX.Modules.IAM.Application.Access.RoleGroups.Authorization;
using IFX.Modules.IAM.Application.Access.RoleGroups.DTOs;
using IFX.Modules.IAM.Application.Common;
using IFX.Modules.IAM.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.IAM.Application.Access.RoleGroups.Commands.UpdateRoleGroup;
public class UpdateRoleGroupCommandHandler : IRequestHandler<UpdateRoleGroupCommand, Result<RoleGroupDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ILogger<UpdateRoleGroupCommandHandler> _logger;
    public UpdateRoleGroupCommandHandler(IUnitOfWork unitOfWork, IMapper mapper, IResourceAuthorizationService authorizationService, ILogger<UpdateRoleGroupCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _authorizationService = authorizationService;
        _logger = logger;
    }

    public async Task<Result<RoleGroupDto>> Handle(UpdateRoleGroupCommand request, CancellationToken cancellationToken)
    {
        {
            var group = await _unitOfWork.RoleGroups.GetByIdAsync(request.RoleGroupId, request.TenantId, cancellationToken);
            if (group == null)
                return Result<RoleGroupDto>.Failure("Role group not found");
            await _authorizationService.AuthorizeWithResolvedPolicyAsync("rolegroup", "update", new RoleGroupResourceAttributes(group.Id, group.TenantId, group.CreatedBy), ct: cancellationToken);
            if (group.Name != request.Name && await _unitOfWork.RoleGroups.NameExistsAsync(request.Name, request.TenantId, request.RoleGroupId, cancellationToken))
                return Result<RoleGroupDto>.Failure($"Role group '{request.Name}' already exists in this tenant");
            group.Update(request.Name, request.Description);
            _logger.LogInformation("Role group {RoleGroupId} updated: {Name}", request.RoleGroupId, request.Name);
            return Result<RoleGroupDto>.Success(_mapper.Map<RoleGroupDto>(group));
        }
    }
}
