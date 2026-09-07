using AutoMapper;
using IFX.Modules.Auth.Application.Authorization.Permissions.DTOs;
using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Interfaces;
using IFX.Modules.Auth.Domain.Authorization;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Authorization.Permissions.Commands.CreatePermission;
public class CreatePermissionCommandHandler : IRequestHandler<CreatePermissionCommand, Result<PermissionDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ILogger<CreatePermissionCommandHandler> _logger;
    public CreatePermissionCommandHandler(IUnitOfWork unitOfWork, IMapper mapper, ILogger<CreatePermissionCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _logger = logger;
    }

    public async Task<Result<PermissionDto>> Handle(CreatePermissionCommand request, CancellationToken cancellationToken)
    {
        {
            if (await _unitOfWork.Permissions.NameExistsAsync(request.Name, cancellationToken))
                return Result<PermissionDto>.Failure($"Permission '{request.Name}' already exists");
            var permission = Permission.Create(request.Name, request.Description);
            await _unitOfWork.Permissions.AddAsync(permission, cancellationToken);
            _logger.LogInformation("Permission created: {Name}", request.Name);
            return Result<PermissionDto>.Success(_mapper.Map<PermissionDto>(permission));
        }
    }
}
