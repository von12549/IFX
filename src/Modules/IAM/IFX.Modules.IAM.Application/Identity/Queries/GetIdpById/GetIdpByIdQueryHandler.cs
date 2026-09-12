using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization;
using IFX.Modules.IAM.Application.Common;
using IFX.Modules.IAM.Application.Identity.Authorization;
using IFX.Modules.IAM.Application.Identity.DTOs;
using IFX.Modules.IAM.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.IAM.Application.Identity.Queries.GetIdpById;

public class GetIdpByIdQueryHandler : IRequestHandler<GetIdpByIdQuery, Result<IdpDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ICurrentUser _currentUser;
    private readonly ILogger<GetIdpByIdQueryHandler> _logger;

    public GetIdpByIdQueryHandler(IUnitOfWork unitOfWork, IMapper mapper, ICurrentUser currentUser, IResourceAuthorizationService authorizationService, ILogger<GetIdpByIdQueryHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _logger = logger;
    }

    public async Task<Result<IdpDto>> Handle(GetIdpByIdQuery request, CancellationToken cancellationToken)
    {
        try
        {
            var tenantId = TenantAccessGuard.RequireTenant(_currentUser);
            var idp = await _unitOfWork.Idps.GetByIdAsync(request.IdpId, tenantId, cancellationToken);

            if (idp == null)
                return Result<IdpDto>.Failure("Identity Provider not found");

            await _authorizationService.AuthorizeWithResolvedPolicyAsync(
                "idp", "read",
                new IdpResourceAttributes(idp.Id, idp.TenantId, idp.CreatedBy),
                ct: cancellationToken);

            return Result<IdpDto>.Success(_mapper.Map<IdpDto>(idp));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving IdP {IdpId}", request.IdpId);
            return Result<IdpDto>.Failure("An error occurred while retrieving the Identity Provider");
        }
    }
}
