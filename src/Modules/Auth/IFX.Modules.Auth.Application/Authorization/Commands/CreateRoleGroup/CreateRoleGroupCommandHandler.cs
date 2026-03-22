using AutoMapper;
using IFX.Modules.Auth.Application.Authorization.DTOs;
using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Interfaces;
using IFX.Modules.Auth.Domain.Authorization;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Authorization.Commands.CreateRoleGroup;

public class CreateRoleGroupCommandHandler : IRequestHandler<CreateRoleGroupCommand, Result<RoleGroupDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ILogger<CreateRoleGroupCommandHandler> _logger;

    public CreateRoleGroupCommandHandler(IUnitOfWork unitOfWork, IMapper mapper, ILogger<CreateRoleGroupCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _logger = logger;
    }

    public async Task<Result<RoleGroupDto>> Handle(CreateRoleGroupCommand request, CancellationToken cancellationToken)
    {
        try
        {
            if (await _unitOfWork.RoleGroups.NameExistsAsync(request.Name, request.TenantId, cancellationToken))
                return Result<RoleGroupDto>.Failure($"Role group '{request.Name}' already exists in this tenant");

            var group = RoleGroup.Create(request.Name, request.Description, request.TenantId);
            await _unitOfWork.RoleGroups.AddAsync(group, cancellationToken);
            await _unitOfWork.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("Role group created: {Name}", request.Name);
            return Result<RoleGroupDto>.Success(_mapper.Map<RoleGroupDto>(group));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error creating role group {Name}", request.Name);
            return Result<RoleGroupDto>.Failure("An error occurred while creating the role group");
        }
    }
}
