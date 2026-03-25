using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Identity.Authorization;
using IFX.Modules.Auth.Application.Identity.DTOs;
using IFX.Modules.Auth.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Identity.Queries.GetIdpById;

public class GetIdpByIdQueryHandler : IRequestHandler<GetIdpByIdQuery, Result<IdpDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ILogger<GetIdpByIdQueryHandler> _logger;

    public GetIdpByIdQueryHandler(IUnitOfWork unitOfWork, IMapper mapper, IResourceAuthorizationService authorizationService, ILogger<GetIdpByIdQueryHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _authorizationService = authorizationService;
        _logger = logger;
    }

    public async Task<Result<IdpDto>> Handle(GetIdpByIdQuery request, CancellationToken cancellationToken)
    {
        try
        {
            var idp = await _unitOfWork.Idps.GetByIdAsync(request.IdpId, cancellationToken);

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
