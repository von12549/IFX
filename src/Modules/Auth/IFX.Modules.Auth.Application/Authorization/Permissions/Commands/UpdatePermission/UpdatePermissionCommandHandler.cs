using AutoMapper;
using IFX.Modules.Auth.Application.Authorization.Permissions.DTOs;
using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Authorization.Permissions.Commands.UpdatePermission;
public class UpdatePermissionCommandHandler : IRequestHandler<UpdatePermissionCommand, Result<PermissionDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ILogger<UpdatePermissionCommandHandler> _logger;
    public UpdatePermissionCommandHandler(IUnitOfWork unitOfWork, IMapper mapper, ILogger<UpdatePermissionCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _logger = logger;
    }

    public async Task<Result<PermissionDto>> Handle(UpdatePermissionCommand request, CancellationToken cancellationToken)
    {
        {
            var permission = await _unitOfWork.Permissions.GetByIdAsync(request.PermissionId, cancellationToken);
            if (permission == null)
                return Result<PermissionDto>.Failure("Permission not found");
            if (permission.Name != request.Name && await _unitOfWork.Permissions.NameExistsAsync(request.Name, request.PermissionId, cancellationToken))
                return Result<PermissionDto>.Failure($"Permission '{request.Name}' already exists");
            permission.Update(request.Name, request.Description);
            _logger.LogInformation("Permission {PermissionId} updated: {Name}", request.PermissionId, request.Name);
            return Result<PermissionDto>.Success(_mapper.Map<PermissionDto>(permission));
        }
    }
}
