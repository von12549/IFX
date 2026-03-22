using AutoMapper;
using IFX.Modules.Auth.Application.Authorization.DTOs;
using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Authorization.Queries.GetAllRoleGroups;

public class GetAllRoleGroupsQueryHandler : IRequestHandler<GetAllRoleGroupsQuery, Result<List<RoleGroupDto>>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ILogger<GetAllRoleGroupsQueryHandler> _logger;

    public GetAllRoleGroupsQueryHandler(IUnitOfWork unitOfWork, IMapper mapper, ILogger<GetAllRoleGroupsQueryHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _logger = logger;
    }

    public async Task<Result<List<RoleGroupDto>>> Handle(GetAllRoleGroupsQuery request, CancellationToken cancellationToken)
    {
        try
        {
            if (!request.TenantId.HasValue)
                return Result<List<RoleGroupDto>>.Success([]);

            var groups = await _unitOfWork.RoleGroups.GetByTenantIdAsync(request.TenantId.Value, cancellationToken);
            var dtos = _mapper.Map<List<RoleGroupDto>>(groups);
            _logger.LogInformation("Retrieved {Count} role groups", dtos.Count);
            return Result<List<RoleGroupDto>>.Success(dtos);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving role groups");
            return Result<List<RoleGroupDto>>.Failure("An error occurred while retrieving role groups");
        }
    }
}
