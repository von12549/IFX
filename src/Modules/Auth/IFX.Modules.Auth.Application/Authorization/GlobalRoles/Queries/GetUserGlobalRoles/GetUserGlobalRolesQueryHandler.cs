using IFX.Modules.Auth.Application.Authorization.GlobalRoles.DTOs;
using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Authorization.GlobalRoles.Queries.GetUserGlobalRoles;

public class GetUserGlobalRolesQueryHandler : IRequestHandler<GetUserGlobalRolesQuery, Result<List<GlobalRoleDto>>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly ILogger<GetUserGlobalRolesQueryHandler> _logger;

    public GetUserGlobalRolesQueryHandler(IUnitOfWork unitOfWork, ILogger<GetUserGlobalRolesQueryHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _logger = logger;
    }

    public async Task<Result<List<GlobalRoleDto>>> Handle(
        GetUserGlobalRolesQuery request, CancellationToken cancellationToken)
    {
        try
        {
            var roles = await _unitOfWork.GlobalRoles.GetByUserIdAsync(request.UserId, cancellationToken);
            return Result<List<GlobalRoleDto>>.Success(
                roles.Select(r => new GlobalRoleDto(r.Id, r.Name, r.Description)).ToList());
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving global roles for user {UserId}", request.UserId);
            return Result<List<GlobalRoleDto>>.Failure("An error occurred while retrieving user global roles.");
        }
    }
}
