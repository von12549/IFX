using Microsoft.AspNetCore.Authentication;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using System.Security.Claims;
using System.Text.Encodings.Web;

namespace IFX.IntegrationTests.Fixtures;

/// <summary>
/// Fake authentication handler for integration tests.
/// Reads permissions from X-Test-Permissions header.
/// If header is absent → not authenticated (401).
/// If header is present (even empty) → authenticated with those permission claims.
/// </summary>
public class TestAuthHandler : AuthenticationHandler<AuthenticationSchemeOptions>
{
    public const string SchemeName = "Test";
    public const string PermissionsHeader = "X-Test-Permissions";

    /// <summary>Sentinel sent when the client is authenticated but has no permissions.</summary>
    private const string NoPermissionsMarker = "-";

    public TestAuthHandler(
        IOptionsMonitor<AuthenticationSchemeOptions> options,
        ILoggerFactory logger,
        UrlEncoder encoder)
        : base(options, logger, encoder) { }

    protected override Task<AuthenticateResult> HandleAuthenticateAsync()
    {
        if (!Request.Headers.ContainsKey(PermissionsHeader))
            return Task.FromResult(AuthenticateResult.NoResult());

        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, "test-user-id"),
            new(ClaimTypes.Name, "testuser"),
        };

        var permissionsValue = Request.Headers[PermissionsHeader].ToString();
        foreach (var perm in permissionsValue.Split(',', StringSplitOptions.RemoveEmptyEntries))
        {
            var trimmed = perm.Trim();
            if (trimmed != NoPermissionsMarker)
                claims.Add(new Claim("permission", trimmed));
        }

        var identity = new ClaimsIdentity(claims, SchemeName);
        var ticket = new AuthenticationTicket(new ClaimsPrincipal(identity), SchemeName);
        return Task.FromResult(AuthenticateResult.Success(ticket));
    }
}
