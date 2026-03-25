using AutoMapper;
using IFX.Modules.Auth.Application.Authorization.Permissions.DTOs;
using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Authorization.Permissions.Queries.GetAllPermissions;

public class GetAllPermissionsQueryHandler : IRequestHandler<GetAllPermissionsQuery, Result<List<PermissionDto>>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ILogger<GetAllPermissionsQueryHandler> _logger;

    public GetAllPermissionsQueryHandler(IUnitOfWork unitOfWork, IMapper mapper, ILogger<GetAllPermissionsQueryHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _logger = logger;
    }

    public async Task<Result<List<PermissionDto>>> Handle(GetAllPermissionsQuery request, CancellationToken cancellationToken)
    {
        try
        {
            var permissions = await _unitOfWork.Permissions.GetAllAsync(cancellationToken);
            var dtos = _mapper.Map<List<PermissionDto>>(permissions);
            _logger.LogInformation("Retrieved {Count} permissions", dtos.Count);
            return Result<List<PermissionDto>>.Success(dtos);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving permissions");
            return Result<List<PermissionDto>>.Failure("An error occurred while retrieving permissions");
        }
    }
}
