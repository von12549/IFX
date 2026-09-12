using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization;
using IFX.Modules.IAM.Application.Common;
using IFX.Modules.IAM.Application.Common.Authorization;
using IFX.Modules.IAM.Application.Identity.DTOs;
using IFX.Modules.IAM.Application.Identity.Interfaces;
using IFX.Modules.IAM.Application.Interfaces;
using IFX.Modules.IAM.Domain.Identity;
using IFX.Modules.IAM.Domain.Users;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.IAM.Application.Identity.Commands.CreateIdp;
public class CreateIdpCommandHandler : IRequestHandler<CreateIdpCommand, Result<IdpDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ILogger<CreateIdpCommandHandler> _logger;
    public CreateIdpCommandHandler(IUnitOfWork unitOfWork, IMapper mapper, ICurrentUser currentUser, IResourceAuthorizationService authorizationService, ILogger<CreateIdpCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _logger = logger;
    }

    public async Task<Result<IdpDto>> Handle(CreateIdpCommand request, CancellationToken cancellationToken)
    {
        {
            await _authorizationService.AuthorizeWithResolvedPolicyAsync("idp", "create", new TenantScopeResourceAttributes(_currentUser.TenantId), ct: cancellationToken);
            // Check if Issuer already exists
            var issuerExists = await _unitOfWork.Idps.IssuerExistsAsync(request.Issuer, cancellationToken);
            if (issuerExists)
            {
                return Result<IdpDto>.Failure($"Identity Provider with Issuer '{request.Issuer}' already exists");
            }

            // If setting as primary, clear existing primary flag
            if (request.IsPrimary)
            {
                await _unitOfWork.Idps.ClearPrimaryFlagAsync(cancellationToken);
            }

            // Create entity via factory method
            var idp = Idp.Create(request.Name, request.Issuer, request.Authority, request.Description, request.LoginUrl, request.IdpType, request.IsPrimary, request.Enabled, request.AutoProvisionEnabled, request.ExpectedAudiences, request.AllowedAlgs, request.RequiredScopes, request.ClaimMapping, request.ClockSkewSeconds);
            idp.CreatedBy = _currentUser.UserId;
            await _unitOfWork.Idps.AddAsync(idp, cancellationToken);
            _logger.LogInformation("Created new Identity Provider: {Name} ({Issuer})", request.Name, request.Issuer);
            var idpDto = _mapper.Map<IdpDto>(idp);
            return Result<IdpDto>.Success(idpDto);
        }
    }
}
