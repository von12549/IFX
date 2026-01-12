using AuthSamples.Modules.Auth.Application.Common;
using AuthSamples.Modules.Auth.Application.DTOs;
using AuthSamples.Modules.Auth.Application.Interfaces;
using AutoMapper;
using MediatR;
using Microsoft.Extensions.Logging;

namespace AuthSamples.Modules.Auth.Application.Commands.UpdateRole;

public class UpdateRoleCommandHandler : IRequestHandler<UpdateRoleCommand, Result<UserRoleDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ILogger<UpdateRoleCommandHandler> _logger;

    public UpdateRoleCommandHandler(
        IUnitOfWork unitOfWork,
        IMapper mapper,
        ILogger<UpdateRoleCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _logger = logger;
    }

    public async Task<Result<UserRoleDto>> Handle(
        UpdateRoleCommand request,
        CancellationToken cancellationToken)
    {
        try
        {
            // Get role by RoleId
            var role = await _unitOfWork.UserRoles.GetByIdAsync(request.RoleId, cancellationToken);
            if (role == null)
            {
                return Result<UserRoleDto>.Failure("Role not found");
            }

            // Check if new RoleName conflicts with existing roles (unless unchanged)
            if (role.RoleName != request.RoleName)
            {
                var nameExists = await _unitOfWork.UserRoles.RoleNameExistsAsync(
                    request.RoleName,
                    request.RoleId,
                    cancellationToken);

                if (nameExists)
                {
                    return Result<UserRoleDto>.Failure($"Role name '{request.RoleName}' already exists");
                }
            }

            // Update role via domain method
            role.Update(request.RoleName, request.Description);

            await _unitOfWork.SaveChangesAsync(cancellationToken);

            _logger.LogInformation(
                "Role {RoleId} updated successfully. New name: {RoleName}",
                request.RoleId,
                request.RoleName);

            var roleDto = _mapper.Map<UserRoleDto>(role);
            return Result<UserRoleDto>.Success(roleDto);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error updating role {RoleId}", request.RoleId);
            return Result<UserRoleDto>.Failure("An error occurred while updating the role");
        }
    }
}
