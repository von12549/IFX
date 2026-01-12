using AuthSamples.Modules.Auth.Application.Common;
using AuthSamples.Modules.Auth.Application.DTOs;
using AuthSamples.Modules.Auth.Application.Interfaces;
using AutoMapper;
using MediatR;
using Microsoft.Extensions.Logging;

namespace AuthSamples.Modules.Auth.Application.Commands.UpdateIdp;

public class UpdateIdpCommandHandler : IRequestHandler<UpdateIdpCommand, Result<IdpDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ILogger<UpdateIdpCommandHandler> _logger;

    public UpdateIdpCommandHandler(
        IUnitOfWork unitOfWork,
        IMapper mapper,
        ILogger<UpdateIdpCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _logger = logger;
    }

    public async Task<Result<IdpDto>> Handle(
        UpdateIdpCommand request,
        CancellationToken cancellationToken)
    {
        try
        {
            // Fetch existing IdP
            var idp = await _unitOfWork.Idps.GetByIdAsync(request.IdpId, cancellationToken);
            if (idp == null)
            {
                return Result<IdpDto>.Failure("Identity Provider not found");
            }

            // Check for Issuer conflicts (only if Issuer changed)
            if (idp.Issuer != request.Issuer)
            {
                var issuerExists = await _unitOfWork.Idps.IssuerExistsAsync(
                    request.Issuer,
                    request.IdpId, // Exclude current IdP from check
                    cancellationToken);

                if (issuerExists)
                {
                    return Result<IdpDto>.Failure($"Identity Provider with Issuer '{request.Issuer}' already exists");
                }
            }

            // Update via domain method
            idp.Update(
                request.Name,
                request.Issuer,
                request.Authority,
                request.Description,
                request.LoginUrl,
                request.Enabled,
                request.AutoProvisionEnabled,
                request.ExpectedAudiences,
                request.AllowedAlgs,
                request.RequiredScopes,
                request.ClaimMapping,
                request.ClockSkewSeconds);

            await _unitOfWork.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("Updated Identity Provider {IdpId}: {Name}", request.IdpId, request.Name);

            var idpDto = _mapper.Map<IdpDto>(idp);
            return Result<IdpDto>.Success(idpDto);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error updating Identity Provider {IdpId}", request.IdpId);
            return Result<IdpDto>.Failure("An error occurred while updating the Identity Provider");
        }
    }
}
