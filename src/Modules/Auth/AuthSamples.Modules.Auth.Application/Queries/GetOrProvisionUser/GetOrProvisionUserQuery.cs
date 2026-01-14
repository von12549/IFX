using AuthSamples.Modules.Auth.Application.Common;
using AuthSamples.Modules.Auth.Application.DTOs;
using AuthSamples.Modules.Auth.Domain.Enums;
using MediatR;

namespace AuthSamples.Modules.Auth.Application.Queries.GetOrProvisionUser;

/// <summary>
/// Query to get an existing user by issuer/subject or auto-provision a new user if enabled.
/// Used during authentication to resolve user identity and role for claims transformation.
/// </summary>
public record GetOrProvisionUserQuery(
    string Issuer,
    string Subject,
    bool AutoProvisionEnabled,
    Guid? IdpId = null,
    IdpType? IdpType = null,
    string? Email = null,
    string? FirstName = null,
    string? LastName = null,
    bool EmailVerified = false,
    string? IpAddress = null) : IRequest<Result<UserAuthResult>>;
