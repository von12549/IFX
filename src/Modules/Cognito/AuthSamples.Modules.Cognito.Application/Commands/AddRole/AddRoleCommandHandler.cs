using AuthSamples.Modules.Cognito.Application.Common;
using AuthSamples.Modules.Cognito.Application.DTOs;
using AuthSamples.Modules.Cognito.Application.Interfaces;
using AuthSamples.Modules.Cognito.Domain.Entities;
using AutoMapper;
using MediatR;
using Microsoft.Extensions.Logging;

namespace AuthSamples.Modules.Cognito.Application.Commands.AddRole;

public class AddRoleCommandHandler : IRequestHandler<AddRoleCommand, Result<UserRoleDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ILogger<AddRoleCommandHandler> _logger;

    public AddRoleCommandHandler(
        IUnitOfWork unitOfWork,
        IMapper mapper,
        ILogger<AddRoleCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _logger = logger;
    }

    public async Task<Result<UserRoleDto>> Handle(
        AddRoleCommand request,
        CancellationToken cancellationToken)
    {
        try
        {
            // Check if role name already exists
            var nameExists = await _unitOfWork.UserRoles.RoleNameExistsAsync(
                request.RoleName,
                cancellationToken);

            if (nameExists)
            {
                return Result<UserRoleDto>.Failure($"Role name '{request.RoleName}' already exists");
            }

            // Create new UserRole via factory method
            var role = UserRole.Create(request.RoleName, request.Description);

            // Add via repository
            await _unitOfWork.UserRoles.AddAsync(role, cancellationToken);
            await _unitOfWork.SaveChangesAsync(cancellationToken);

            _logger.LogInformation(
                "New role created: {RoleName}",
                request.RoleName);

            var roleDto = _mapper.Map<UserRoleDto>(role);
            return Result<UserRoleDto>.Success(roleDto);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error creating role {RoleName}", request.RoleName);
            return Result<UserRoleDto>.Failure("An error occurred while creating the role");
        }
    }
}
