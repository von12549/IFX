using AutoMapper;
using IFX.Modules.Auth.Application.Authorization.DTOs;
using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Authorization.Commands.UpdateRoleGroup;

public class UpdateRoleGroupCommandHandler : IRequestHandler<UpdateRoleGroupCommand, Result<RoleGroupDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ILogger<UpdateRoleGroupCommandHandler> _logger;

    public UpdateRoleGroupCommandHandler(IUnitOfWork unitOfWork, IMapper mapper, ILogger<UpdateRoleGroupCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _logger = logger;
    }

    public async Task<Result<RoleGroupDto>> Handle(UpdateRoleGroupCommand request, CancellationToken cancellationToken)
    {
        try
        {
            var group = await _unitOfWork.RoleGroups.GetByIdAsync(request.RoleGroupId, cancellationToken);
            if (group == null)
                return Result<RoleGroupDto>.Failure("Role group not found");

            if (group.Name != request.Name &&
                await _unitOfWork.RoleGroups.NameExistsAsync(request.Name, request.TenantId, request.RoleGroupId, cancellationToken))
                return Result<RoleGroupDto>.Failure($"Role group '{request.Name}' already exists in this tenant");

            group.Update(request.Name, request.Description);
            await _unitOfWork.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("Role group {RoleGroupId} updated: {Name}", request.RoleGroupId, request.Name);
            return Result<RoleGroupDto>.Success(_mapper.Map<RoleGroupDto>(group));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error updating role group {RoleGroupId}", request.RoleGroupId);
            return Result<RoleGroupDto>.Failure("An error occurred while updating the role group");
        }
    }
}
