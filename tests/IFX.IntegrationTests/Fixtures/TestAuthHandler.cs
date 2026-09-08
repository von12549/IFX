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
    public const string TenantsHeader = "X-Test-Tenants";
    public static readonly Guid DefaultUserId = Guid.Parse("10000000-0000-4000-8000-000000000001");
    public static readonly Guid DefaultTenantId = Guid.Parse("20000000-0000-4000-8000-000000000001");

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
            new("user_id", DefaultUserId.ToString("D")),
            new("tenant_id", DefaultTenantId.ToString("D")),
            new("tenant", DefaultTenantId.ToString("D"))
        };

        foreach (var tenant in Request.Headers[TenantsHeader].ToString()
                     .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
        {
            if (Guid.TryParseExact(tenant, "D", out var tenantId) && tenantId != Guid.Empty)
            {
                claims.Add(new Claim("tenant", tenantId.ToString("D")));
            }
        }

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
