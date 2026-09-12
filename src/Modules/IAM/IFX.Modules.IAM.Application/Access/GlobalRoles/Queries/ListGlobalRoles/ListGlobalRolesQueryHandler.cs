using IFX.Modules.IAM.Application.Access.GlobalRoles.DTOs;
using IFX.Modules.IAM.Application.Common;
using IFX.Modules.IAM.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.IAM.Application.Access.GlobalRoles.Queries.ListGlobalRoles;

public class ListGlobalRolesQueryHandler : IRequestHandler<ListGlobalRolesQuery, Result<List<GlobalRoleDto>>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly ILogger<ListGlobalRolesQueryHandler> _logger;

    public ListGlobalRolesQueryHandler(IUnitOfWork unitOfWork, ILogger<ListGlobalRolesQueryHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _logger = logger;
    }

    public async Task<Result<List<GlobalRoleDto>>> Handle(
        ListGlobalRolesQuery request, CancellationToken cancellationToken)
    {
        try
        {
            var roles = await _unitOfWork.GlobalRoles.GetAllAsync(cancellationToken);
            return Result<List<GlobalRoleDto>>.Success(
                roles.Select(r => new GlobalRoleDto(r.Id, r.Name, r.Description)).ToList());
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error listing global roles");
            return Result<List<GlobalRoleDto>>.Failure("An error occurred while listing global roles.");
        }
    }
}
