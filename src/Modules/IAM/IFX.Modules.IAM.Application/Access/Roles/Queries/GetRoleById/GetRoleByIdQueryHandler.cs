using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization;
using IFX.Modules.IAM.Application.Access.Roles.Authorization;
using IFX.Modules.IAM.Application.Access.Roles.DTOs;
using IFX.Modules.IAM.Application.Common;
using IFX.Modules.IAM.Application.Interfaces;
using MediatR;

namespace IFX.Modules.IAM.Application.Access.Roles.Queries.GetRoleById;

public class GetRoleByIdQueryHandler : IRequestHandler<GetRoleByIdQuery, Result<RoleDetailDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ICurrentUser _currentUser;

    public GetRoleByIdQueryHandler(IUnitOfWork unitOfWork, IMapper mapper, ICurrentUser currentUser, IResourceAuthorizationService authorizationService)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
    }

    public async Task<Result<RoleDetailDto>> Handle(GetRoleByIdQuery request, CancellationToken cancellationToken)
    {
        var tenantId = TenantAccessGuard.RequireTenant(_currentUser);
        var role = await _unitOfWork.Roles.GetByIdWithPermissionsAsync(request.RoleId, tenantId, cancellationToken);

        if (role == null)
            return Result<RoleDetailDto>.Failure("Role not found");

        await _authorizationService.AuthorizeWithResolvedPolicyAsync(
            "role", "read",
            new RoleResourceAttributes(role.Id, role.TenantId, role.CreatedBy),
            ct: cancellationToken);

        return Result<RoleDetailDto>.Success(_mapper.Map<RoleDetailDto>(role));
    }
}
