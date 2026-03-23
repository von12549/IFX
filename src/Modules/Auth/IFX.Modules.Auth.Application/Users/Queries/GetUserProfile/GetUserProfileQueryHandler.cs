using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Users.Authorization;
using IFX.Modules.Auth.Application.Users.DTOs;
using IFX.Modules.Auth.Application.Interfaces;
using AutoMapper;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Users.Queries.GetUserProfile;

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

            // ABAC: resource-level authorization after loading the resource.
            // No RBAC pre-gate (null) — OPA decides entirely.
            // Policy: allow if same tenant AND (self OR has users.read permission).
            var resourceAttributes = new UserResourceAttributes(user.Id, user.PrimaryTenantId);
            await _authorizationService.AuthorizeAsync(
                requiredPermission: null,
                decisionPath: "authz/auth/read_user",
                resourceAttributes: resourceAttributes,
                action: "read",
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
