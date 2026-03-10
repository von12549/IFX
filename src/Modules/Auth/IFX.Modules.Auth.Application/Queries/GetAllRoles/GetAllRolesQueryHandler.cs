using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.DTOs;
using IFX.Modules.Auth.Application.Interfaces;
using AutoMapper;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Queries.GetAllRoles;

public class GetAllRolesQueryHandler : IRequestHandler<GetAllRolesQuery, Result<List<UserRoleDto>>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ILogger<GetAllRolesQueryHandler> _logger;

    public GetAllRolesQueryHandler(
        IUnitOfWork unitOfWork,
        IMapper mapper,
        ILogger<GetAllRolesQueryHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _logger = logger;
    }

    public async Task<Result<List<UserRoleDto>>> Handle(
        GetAllRolesQuery request,
        CancellationToken cancellationToken)
    {
        try
        {
            var roles = await _unitOfWork.UserRoles.GetAllAsync(cancellationToken);
            var roleDtos = _mapper.Map<List<UserRoleDto>>(roles);

            _logger.LogInformation("Retrieved {Count} roles", roleDtos.Count);

            return Result<List<UserRoleDto>>.Success(roleDtos);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving roles");
            return Result<List<UserRoleDto>>.Failure("An error occurred while retrieving roles");
        }
    }
}
