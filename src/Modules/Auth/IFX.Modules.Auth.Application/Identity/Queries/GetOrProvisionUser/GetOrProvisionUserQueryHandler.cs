using System.Net.Http.Headers;
using System.Text.Json;
using System.Text.Json.Serialization;
using IFX.Modules.Auth.Application.Commands.ProvisionSsoUser;
using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.DTOs;
using IFX.Modules.Auth.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Queries.GetOrProvisionUser;

public class GetOrProvisionUserQueryHandler : IRequestHandler<GetOrProvisionUserQuery, Result<UserAuthResult>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMediator _mediator;
    private readonly IOidcDiscoveryService _discoveryService;
    private readonly IHttpClientFactory _httpClientFactory;
    private readonly ILogger<GetOrProvisionUserQueryHandler> _logger;

    public GetOrProvisionUserQueryHandler(
        IUnitOfWork unitOfWork,
        IMediator mediator,
        IOidcDiscoveryService discoveryService,
        IHttpClientFactory httpClientFactory,
        ILogger<GetOrProvisionUserQueryHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mediator = mediator;
        _discoveryService = discoveryService;
        _httpClientFactory = httpClientFactory;
        _logger = logger;
    }

    public async Task<Result<UserAuthResult>> Handle(
        GetOrProvisionUserQuery request,
        CancellationToken cancellationToken)
    {
        try
        {
            // 1. Try to find existing user by issuer/subject
            var user = await _unitOfWork.Users.GetByIssuerAndSubjectAsync(
                request.Issuer, request.Subject, cancellationToken);

            if (user != null)
            {
                // User exists - return their info
                if (user.UserRole == null)
                {
                    _logger.LogWarning(
                        "User {Issuer}/{Subject} has no role assigned",
                        request.Issuer, request.Subject);
                    return Result<UserAuthResult>.Failure("User has no role assigned");
                }

                _logger.LogDebug(
                    "Found existing user {UserId} with role '{RoleName}' for {Issuer}/{Subject}",
                    user.Id, user.UserRole.RoleName, request.Issuer, request.Subject);

                return Result<UserAuthResult>.Success(new UserAuthResult
                {
                    UserId = user.Id,
                    RoleName = user.UserRole.RoleName,
                    WasProvisioned = false
                });
            }

            // 2. User not found - check if auto-provisioning is enabled
            if (!request.AutoProvisionEnabled)
            {
                _logger.LogWarning(
                    "User with Issuer {Issuer} and Subject {Subject} not found and auto-provision disabled",
                    request.Issuer, request.Subject);
                return Result<UserAuthResult>.Failure("User not found");
            }

            // 3. Validate required fields for provisioning
            if (!request.IdpId.HasValue || !request.IdpType.HasValue)
            {
                _logger.LogWarning(
                    "Cannot provision user: IdpId and IdpType are required");
                return Result<UserAuthResult>.Failure("IdP configuration missing for auto-provisioning");
            }

            // 4. Fetch user info from OIDC userinfo endpoint
            string? email = null;
            string? firstName = null;
            string? lastName = null;
            bool emailVerified = false;

            try
            {
                var discoveryDoc = await _discoveryService.GetDiscoveryDocumentAsync(request.Issuer, cancellationToken);

                if (!string.IsNullOrEmpty(discoveryDoc.UserInfoEndpoint))
                {
                    var httpClient = _httpClientFactory.CreateClient("OidcUserInfo");
                    httpClient.DefaultRequestHeaders.Authorization =
                        new AuthenticationHeaderValue("Bearer", request.AccessToken);

                    var response = await httpClient.GetAsync(discoveryDoc.UserInfoEndpoint, cancellationToken);

                    if (response.IsSuccessStatusCode)
                    {
                        var content = await response.Content.ReadAsStringAsync(cancellationToken);
                        var userInfo = JsonSerializer.Deserialize<UserInfoResponse>(content);

                        email = userInfo?.Email;
                        firstName = userInfo?.GivenName;
                        lastName = userInfo?.FamilyName;
                        emailVerified = userInfo?.IsEmailVerified ?? false;

                        _logger.LogInformation(
                            "Retrieved user info for {Subject}: email={Email}",
                            request.Subject, email);
                    }
                    else
                    {
                        _logger.LogWarning(
                            "UserInfo request failed: {StatusCode}",
                            response.StatusCode);
                    }
                }
                else
                {
                    _logger.LogWarning(
                        "No userinfo endpoint available for issuer {Issuer}",
                        request.Issuer);
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex,
                    "Failed to fetch user info from OIDC endpoint for {Issuer}/{Subject}",
                    request.Issuer, request.Subject);
            }

            // 5. Use fallback if userinfo failed
            if (string.IsNullOrEmpty(email))
            {
                _logger.LogWarning(
                    "Using placeholder email for {Issuer}/{Subject} - userinfo unavailable",
                    request.Issuer, request.Subject);
                email = $"{request.Subject}@pending.local";
                emailVerified = false;
            }

            // 6. Auto-provision via existing command
            var provisionCommand = new ProvisionSsoUserCommand(
                IdpId: request.IdpId.Value,
                Issuer: request.Issuer,
                Subject: request.Subject,
                IdpType: request.IdpType.Value,
                Email: email,
                FirstName: firstName,
                LastName: lastName,
                EmailVerified: emailVerified,
                IpAddress: request.IpAddress);

            var provisionResult = await _mediator.Send(provisionCommand, cancellationToken);

            if (!provisionResult.IsSuccess)
            {
                _logger.LogWarning("SSO user provisioning failed: {Error}", provisionResult.Error);
                return Result<UserAuthResult>.Failure(provisionResult.Error!);
            }

            _logger.LogInformation(
                "Auto-provisioned SSO user {UserId} with role '{RoleName}' for {Issuer}/{Subject}",
                provisionResult.Value!.UserId,
                provisionResult.Value.RoleName,
                request.Issuer,
                request.Subject);

            return Result<UserAuthResult>.Success(new UserAuthResult
            {
                UserId = provisionResult.Value.UserId,
                RoleName = provisionResult.Value.RoleName,
                WasProvisioned = provisionResult.Value.WasProvisioned
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex,
                "Error getting or provisioning user for {Issuer}/{Subject}",
                request.Issuer, request.Subject);
            return Result<UserAuthResult>.Failure("An error occurred during user authentication");
        }
    }

    /// <summary>
    /// OIDC UserInfo response model
    /// </summary>
    private class UserInfoResponse
    {
        [JsonPropertyName("sub")]
        public string? Sub { get; set; }

        [JsonPropertyName("email")]
        public string? Email { get; set; }

        [JsonPropertyName("email_verified")]
        public string? EmailVerified { get; set; }

        [JsonPropertyName("given_name")]
        public string? GivenName { get; set; }

        [JsonPropertyName("family_name")]
        public string? FamilyName { get; set; }

        [JsonPropertyName("name")]
        public string? Name { get; set; }

        /// <summary>
        /// Parses email_verified as boolean (handles string "true"/"false" from Cognito)
        /// </summary>
        public bool IsEmailVerified =>
            string.Equals(EmailVerified, "true", StringComparison.OrdinalIgnoreCase);
    }
}
