using AutoMapper;
using IFX.Modules.Auth.Application.Authorization.DTOs;
using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Authorization.Queries.GetAllRoles;

public class GetAllRolesQueryHandler : IRequestHandler<GetAllRolesQuery, Result<List<RoleDto>>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ILogger<GetAllRolesQueryHandler> _logger;

    public GetAllRolesQueryHandler(IUnitOfWork unitOfWork, IMapper mapper, ILogger<GetAllRolesQueryHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _logger = logger;
    }

    public async Task<Result<List<RoleDto>>> Handle(GetAllRolesQuery request, CancellationToken cancellationToken)
    {
        try
        {
            if (!request.TenantId.HasValue)
                return Result<List<RoleDto>>.Success([]);

            var roles = await _unitOfWork.Roles.GetByTenantIdAsync(request.TenantId.Value, cancellationToken);
            var roleDtos = _mapper.Map<List<RoleDto>>(roles);
            _logger.LogInformation("Retrieved {Count} roles", roleDtos.Count);
            return Result<List<RoleDto>>.Success(roleDtos);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving roles");
            return Result<List<RoleDto>>.Failure("An error occurred while retrieving roles");
        }
    }
}
