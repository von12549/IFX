using IFX.BuildingBlocks.Security.Authorization;
using IFX.Modules.IAM.Application.Common;
using IFX.Modules.IAM.Application.Users.Authorization;
using IFX.Modules.IAM.Application.Users.DTOs;
using IFX.Modules.IAM.Application.Interfaces;
using AutoMapper;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.IAM.Application.Users.Queries.GetUserProfile;

public class GetUserProfileQueryHandler : IRequestHandler<GetUserProfileQuery, Result<UserProfileDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ILogger<GetUserProfileQueryHandler> _logger;

    public GetUserProfileQueryHandler(
        IUnitOfWork unitOfWork,
        IMapper mapper,
        ICurrentUser currentUser,
        IResourceAuthorizationService authorizationService,
        ILogger<GetUserProfileQueryHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _logger = logger;
    }

    public async Task<Result<UserProfileDto>> Handle(
        GetUserProfileQuery request,
        CancellationToken cancellationToken)
    {
        try
        {
            var user = await _unitOfWork.Users.GetByIssuerAndSubjectWithPermissionsAsync(request.Issuer, request.Subject, cancellationToken);
            if (user == null)
            {
                return Result<UserProfileDto>.Failure("User not found");
            }

            // ABAC: resolved policy for user/read (tenant override → static fallback).
            // Use the caller's active tenant (ICurrentUser.TenantId) as the resource tenant,
            // not user.PrimaryTenantId — a user may read their profile from any tenant they
            // belong to, and CurrentUser.TenantId is already validated against their memberships.
            var resourceAttributes = new UserResourceAttributes(user.Id, _currentUser.TenantId);
            await _authorizationService.AuthorizeWithResolvedPolicyAsync(
                "user", "read",
                resourceAttributes,
                ct: cancellationToken);

            var userProfile = _mapper.Map<UserProfileDto>(user);
            return Result<UserProfileDto>.Success(userProfile);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving user profile for {Issuer}/{Subject}", request.Issuer, request.Subject);
            return Result<UserProfileDto>.Failure("An error occurred while retrieving user profile");
        }
    }
}
