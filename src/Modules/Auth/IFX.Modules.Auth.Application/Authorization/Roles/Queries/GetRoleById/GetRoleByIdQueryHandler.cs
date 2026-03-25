using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.Modules.Auth.Application.Authorization.Roles.Authorization;
using IFX.Modules.Auth.Application.Authorization.Roles.DTOs;
using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Interfaces;
using MediatR;

namespace IFX.Modules.Auth.Application.Authorization.Roles.Queries.GetRoleById;

public class GetRoleByIdQueryHandler : IRequestHandler<GetRoleByIdQuery, Result<RoleDetailDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly IResourceAuthorizationService _authorizationService;

    public GetRoleByIdQueryHandler(IUnitOfWork unitOfWork, IMapper mapper, IResourceAuthorizationService authorizationService)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _authorizationService = authorizationService;
    }

    public async Task<Result<RoleDetailDto>> Handle(GetRoleByIdQuery request, CancellationToken cancellationToken)
    {
        var role = await _unitOfWork.Roles.GetByIdWithPermissionsAsync(request.RoleId, cancellationToken);

        if (role == null)
            return Result<RoleDetailDto>.Failure("Role not found");

        await _authorizationService.AuthorizeWithResolvedPolicyAsync(
            "role", "read",
            new RoleResourceAttributes(role.Id, role.TenantId, role.CreatedBy),
            ct: cancellationToken);

        return Result<RoleDetailDto>.Success(_mapper.Map<RoleDetailDto>(role));
    }
}
