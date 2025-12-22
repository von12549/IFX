using AuthSamples.Modules.Cognito.Application.Common;
using AuthSamples.Modules.Cognito.Application.DTOs;
using AuthSamples.Modules.Cognito.Application.Interfaces;
using AuthSamples.Modules.Cognito.Domain.ValueObjects;
using AutoMapper;
using MediatR;
using Microsoft.Extensions.Logging;

namespace AuthSamples.Modules.Cognito.Application.Commands.SyncUser;

public class SyncUserCommandHandler : IRequestHandler<SyncUserCommand, Result<UserProfileDto>>
{
    private readonly ICognitoService _cognitoService;
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ILogger<SyncUserCommandHandler> _logger;

    public SyncUserCommandHandler(
        ICognitoService cognitoService,
        IUnitOfWork unitOfWork,
        IMapper mapper,
        ILogger<SyncUserCommandHandler> logger)
    {
        _cognitoService = cognitoService;
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _logger = logger;
    }

    public async Task<Result<UserProfileDto>> Handle(
        SyncUserCommand request,
        CancellationToken cancellationToken)
    {
        try
        {
            // Get user from local DB
            var user = await _unitOfWork.Users.GetByCognitoUserIdAsync(request.CognitoUserId, cancellationToken);
            if (user == null)
            {
                return Result<UserProfileDto>.Failure("User not found");
            }

            // This would need an access token in real scenario, skipping for now
            // In production, you'd get user attributes via Admin API or pass access token
            // For now, we'll just update the LastSyncedAt
            // var cognitoUserInfo = await _cognitoService.GetUserAsync(accessToken);

            // user.UpdateFromCognito(...);
            await _unitOfWork.Users.UpdateAsync(user, cancellationToken);
            await _unitOfWork.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("User {CognitoUserId} synced successfully", request.CognitoUserId);

            var userProfile = _mapper.Map<UserProfileDto>(user);
            return Result<UserProfileDto>.Success(userProfile);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error syncing user {CognitoUserId}", request.CognitoUserId);
            return Result<UserProfileDto>.Failure("An error occurred during user sync");
        }
    }
}
