using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Common.Authorization;
using IFX.Modules.Auth.Application.Identity.DTOs;
using IFX.Modules.Auth.Application.Identity.Interfaces;
using IFX.Modules.Auth.Application.Interfaces;
using IFX.Modules.Auth.Domain.Identity;
using IFX.Modules.Auth.Domain.Users;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Identity.Commands.CreateIdp;

public class CreateIdpCommandHandler : IRequestHandler<CreateIdpCommand, Result<IdpDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ILogger<CreateIdpCommandHandler> _logger;

    public CreateIdpCommandHandler(
        IUnitOfWork unitOfWork,
        IMapper mapper,
        ICurrentUser currentUser,
        IResourceAuthorizationService authorizationService,
        ILogger<CreateIdpCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _logger = logger;
    }

    public async Task<Result<IdpDto>> Handle(
        CreateIdpCommand request,
        CancellationToken cancellationToken)
    {
        try
        {
            await _authorizationService.AuthorizeWithResolvedPolicyAsync(
                "idp", "create",
                new TenantScopeResourceAttributes(_currentUser.TenantId),
                ct: cancellationToken);

            // Check if Issuer already exists
            var issuerExists = await _unitOfWork.Idps.IssuerExistsAsync(
                request.Issuer,
                cancellationToken);

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
            var idp = Idp.Create(
                request.Name,
                request.Issuer,
                request.Authority,
                request.Description,
                request.LoginUrl,
                request.IdpType,
                request.IsPrimary,
                request.Enabled,
                request.AutoProvisionEnabled,
                request.ExpectedAudiences,
                request.AllowedAlgs,
                request.RequiredScopes,
                request.ClaimMapping,
                request.ClockSkewSeconds);

            idp.CreatedBy = _currentUser.UserId;
            await _unitOfWork.Idps.AddAsync(idp, cancellationToken);
            await _unitOfWork.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("Created new Identity Provider: {Name} ({Issuer})", request.Name, request.Issuer);

            var idpDto = _mapper.Map<IdpDto>(idp);
            return Result<IdpDto>.Success(idpDto);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error creating Identity Provider {Name}", request.Name);
            return Result<IdpDto>.Failure("An error occurred while creating the Identity Provider");
        }
    }
}
