using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Identity.DTOs;
using IFX.Modules.Auth.Domain.Identity;
using MediatR;

namespace IFX.Modules.Auth.Application.Identity.Queries.GetOrProvisionUser;

/// <summary>
/// Query to get an existing user by issuer/subject or auto-provision a new user if enabled.
/// Used during authentication to resolve user identity and role for claims transformation.
/// User info (email, name) will be fetched from OIDC userinfo endpoint using the access token.
/// </summary>
public record GetOrProvisionUserQuery(
    string Issuer,
    string Subject,
    string AccessToken,
    bool AutoProvisionEnabled,
    Guid? IdpId = null,
    IdpType? IdpType = null,
    string? IpAddress = null) : IRequest<Result<UserAuthResult>>;
