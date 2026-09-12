using IFX.Modules.IAM.Application.Common;
using IFX.Modules.IAM.Application.Identity.DTOs;
using IFX.Modules.IAM.Application.Users.DTOs;
using IFX.Modules.IAM.Application.Identity.Interfaces;
using IFX.Modules.IAM.Application.Interfaces;
using IFX.Modules.IAM.Domain.Users;
using AutoMapper;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.IAM.Application.Identity.Commands.SyncUser;
public class SyncUserCommandHandler : IRequestHandler<SyncUserCommand, Result<UserProfileDto>>
{
    private readonly IExternalAccountService _identityProvider;
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ILogger<SyncUserCommandHandler> _logger;
    public SyncUserCommandHandler(IExternalAccountService identityProvider, IUnitOfWork unitOfWork, IMapper mapper, ILogger<SyncUserCommandHandler> logger)
    {
        _identityProvider = identityProvider;
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _logger = logger;
    }

    public async Task<Result<UserProfileDto>> Handle(SyncUserCommand request, CancellationToken cancellationToken)
    {
        {
            // Get user from local DB
            var user = await _unitOfWork.Users.GetByIssuerAndSubjectAsync(request.Issuer, request.Subject, cancellationToken);
            if (user == null)
            {
                return Result<UserProfileDto>.Failure("User not found");
            }

            // Get the specific UserIdentity for this Issuer+Subject
            var identity = user.Identities.FirstOrDefault(i => i.Issuer == request.Issuer && i.Subject.Value == request.Subject);
            if (identity == null)
            {
                return Result<UserProfileDto>.Failure("User identity not found");
            }

            // TODO: This would need an access token to fetch from Cognito
            // In production, you'd either:
            // 1. Pass the access token from the controller
            // 2. Use Admin API with service credentials
            // 3. Extract access token from Authorization header in the controller
            // For now, we'll just return the current profile without syncing
            // var providerUserInfo = await _identityProvider.GetUserAsync(accessToken);
            // identity.UpdateFromIdp(EmailAddress.Create(cognitoUserInfo.Email), ...);
            // await _unitOfWork.UserIdentities.UpdateAsync(identity, cancellationToken);
            // await _unitOfWork.SaveChangesAsync(cancellationToken);
            _logger.LogInformation("User {Issuer}/{Subject} sync requested (implementation pending)", request.Issuer, request.Subject);
            var userProfile = _mapper.Map<UserProfileDto>(user);
            return Result<UserProfileDto>.Success(userProfile);
        }
    }
}
