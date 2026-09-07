using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Identity.Authorization;
using IFX.Modules.Auth.Application.Identity.DTOs;
using IFX.Modules.Auth.Application.Identity.Interfaces;
using IFX.Modules.Auth.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Identity.Commands.UpdateIdp;
public class UpdateIdpCommandHandler : IRequestHandler<UpdateIdpCommand, Result<IdpDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ILogger<UpdateIdpCommandHandler> _logger;
    public UpdateIdpCommandHandler(IUnitOfWork unitOfWork, IMapper mapper, IResourceAuthorizationService authorizationService, ILogger<UpdateIdpCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _authorizationService = authorizationService;
        _logger = logger;
    }

    public async Task<Result<IdpDto>> Handle(UpdateIdpCommand request, CancellationToken cancellationToken)
    {
        {
            // Fetch existing IdP
            var idp = await _unitOfWork.Idps.GetByIdAsync(request.IdpId, cancellationToken);
            if (idp == null)
            {
                return Result<IdpDto>.Failure("Identity Provider not found");
            }

            await _authorizationService.AuthorizeWithResolvedPolicyAsync("idp", "update", new IdpResourceAttributes(idp.Id, idp.TenantId, idp.CreatedBy), ct: cancellationToken);
            // Check for Issuer conflicts (only if Issuer changed)
            if (idp.Issuer != request.Issuer)
            {
                var issuerExists = await _unitOfWork.Idps.IssuerExistsAsync(request.Issuer, request.IdpId, // Exclude current IdP from check
 cancellationToken);
                if (issuerExists)
                {
                    return Result<IdpDto>.Failure($"Identity Provider with Issuer '{request.Issuer}' already exists");
                }
            }

            // If setting as primary and not already primary, clear existing primary flag
            if (request.IsPrimary && !idp.IsPrimary)
            {
                await _unitOfWork.Idps.ClearPrimaryFlagAsync(cancellationToken);
            }

            // Update via domain method
            idp.Update(request.Name, request.Issuer, request.Authority, request.Description, request.LoginUrl, request.IdpType, request.IsPrimary, request.Enabled, request.AutoProvisionEnabled, request.ExpectedAudiences, request.AllowedAlgs, request.RequiredScopes, request.ClaimMapping, request.ClockSkewSeconds);
            _logger.LogInformation("Updated Identity Provider {IdpId}: {Name}", request.IdpId, request.Name);
            var idpDto = _mapper.Map<IdpDto>(idp);
            return Result<IdpDto>.Success(idpDto);
        }
    }
}
