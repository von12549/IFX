using AuthSamples.Modules.Auth.Application.Common;
using AuthSamples.Modules.Auth.Application.DTOs;
using AuthSamples.Modules.Auth.Domain.Enums;
using MediatR;

namespace AuthSamples.Modules.Auth.Application.Queries.GetOrProvisionUser;

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
