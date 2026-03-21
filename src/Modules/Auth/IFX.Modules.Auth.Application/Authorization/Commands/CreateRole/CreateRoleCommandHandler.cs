using AutoMapper;
using IFX.Modules.Auth.Application.Authorization.DTOs;
using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Interfaces;
using IFX.Modules.Auth.Domain.Authorization;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Authorization.Commands.CreateRole;

public class CreateRoleCommandHandler : IRequestHandler<CreateRoleCommand, Result<RoleDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ILogger<CreateRoleCommandHandler> _logger;

    public CreateRoleCommandHandler(IUnitOfWork unitOfWork, IMapper mapper, ILogger<CreateRoleCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _logger = logger;
    }

    public async Task<Result<RoleDto>> Handle(CreateRoleCommand request, CancellationToken cancellationToken)
    {
        try
        {
            if (await _unitOfWork.Roles.NameExistsAsync(request.Name, cancellationToken))
                return Result<RoleDto>.Failure($"Role name '{request.Name}' already exists");

            var role = Role.Create(request.Name, request.Description);
            await _unitOfWork.Roles.AddAsync(role, cancellationToken);
            await _unitOfWork.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("New role created: {Name}", request.Name);
            return Result<RoleDto>.Success(_mapper.Map<RoleDto>(role));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error creating role {Name}", request.Name);
            return Result<RoleDto>.Failure("An error occurred while creating the role");
        }
    }
}
