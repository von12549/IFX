using System.Security.Claims;

namespace AuthSamples.Modules.Auth.Presentation.Extensions;

public static class ClaimsPrincipalExtensions
{
    /// <summary>
    /// Extract issuer and subject from JWT claims for multi-IdP user identification
    /// </summary>
    /// <param name="principal">The claims principal from the authenticated user</param>
    /// <returns>Tuple of (Issuer, Subject) or (null, null) if not found</returns>
    public static (string? Issuer, string? Subject) GetIssuerAndSubject(this ClaimsPrincipal principal)
    {
        var subject = principal.FindFirst("sub")?.Value;
        var issuer = principal.FindFirst("iss")?.Value;
        return (issuer, subject);
    }
}
