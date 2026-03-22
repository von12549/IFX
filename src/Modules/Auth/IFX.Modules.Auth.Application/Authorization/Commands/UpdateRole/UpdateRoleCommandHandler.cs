using AutoMapper;
using IFX.Modules.Auth.Application.Authorization.DTOs;
using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Authorization.Commands.UpdateRole;

public class UpdateRoleCommandHandler : IRequestHandler<UpdateRoleCommand, Result<RoleDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ILogger<UpdateRoleCommandHandler> _logger;

    public UpdateRoleCommandHandler(IUnitOfWork unitOfWork, IMapper mapper, ILogger<UpdateRoleCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _logger = logger;
    }

    public async Task<Result<RoleDto>> Handle(UpdateRoleCommand request, CancellationToken cancellationToken)
    {
        try
        {
            var role = await _unitOfWork.Roles.GetByIdAsync(request.RoleId, cancellationToken);
            if (role == null)
                return Result<RoleDto>.Failure("Role not found");

            if (role.Name != request.Name)
            {
                if (await _unitOfWork.Roles.NameExistsAsync(request.Name, request.TenantId, request.RoleId, cancellationToken))
                    return Result<RoleDto>.Failure($"Role name '{request.Name}' already exists in this tenant");
            }

            role.Update(request.Name, request.Description);
            await _unitOfWork.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("Role {RoleId} updated: {Name}", request.RoleId, request.Name);
            return Result<RoleDto>.Success(_mapper.Map<RoleDto>(role));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error updating role {RoleId}", request.RoleId);
            return Result<RoleDto>.Failure("An error occurred while updating the role");
        }
    }
}
