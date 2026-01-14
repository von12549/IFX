using AuthSamples.Modules.Auth.Application.Common;
using AuthSamples.Modules.Auth.Application.DTOs;
using AuthSamples.Modules.Auth.Application.Interfaces;
using AuthSamples.Modules.Auth.Domain.Entities;
using AutoMapper;
using MediatR;
using Microsoft.Extensions.Logging;

namespace AuthSamples.Modules.Auth.Application.Commands.CreateIdp;

public class CreateIdpCommandHandler : IRequestHandler<CreateIdpCommand, Result<IdpDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ILogger<CreateIdpCommandHandler> _logger;

    public CreateIdpCommandHandler(
        IUnitOfWork unitOfWork,
        IMapper mapper,
        ILogger<CreateIdpCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _logger = logger;
    }

    public async Task<Result<IdpDto>> Handle(
        CreateIdpCommand request,
        CancellationToken cancellationToken)
    {
        try
        {
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
