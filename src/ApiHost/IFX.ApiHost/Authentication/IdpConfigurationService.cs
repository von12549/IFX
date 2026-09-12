using System.Text.Json;
using IFX.Modules.IAM.Composition;

namespace IFX.ApiHost.Authentication;

public class IdpConfigurationService : IIdpConfigurationService
{
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<IdpConfigurationService> _logger;

    public IdpConfigurationService(
        IServiceScopeFactory scopeFactory,
        ILogger<IdpConfigurationService> logger)
    {
        _scopeFactory = scopeFactory;
        _logger = logger;
    }

    public async Task<IdpConfigurationEntry?> GetByIssuerAsync(string issuer, CancellationToken ct = default)
    {
        var all = await GetAllEnabledAsync(ct);
        var entry = all.FirstOrDefault(x => x.Issuer == issuer);

        return entry;
    }

    public async Task<IReadOnlyList<IdpConfigurationEntry>> GetAllEnabledAsync(CancellationToken ct = default)
    {
        // Read IAM trust on each attempt so revocation also works across instances.

        using var scope = _scopeFactory.CreateScope();
        var reader = scope.ServiceProvider.GetRequiredService<IIdentityProviderConfigurationReader>();
        var idps = await reader.ReadEnabledAsync(ct);

        var entries = idps.Select(idp => new IdpConfigurationEntry
        {
            IdpId = idp.IdpId,
            Issuer = idp.Issuer,
            Authority = idp.Authority,
            IdpType = idp.IdpType,
            AutoProvisionEnabled = idp.AutoProvisionEnabled,
            ExpectedAudiences = DeserializeJsonArray(idp.ExpectedAudiences),
            AllowedAlgorithms = DeserializeJsonArray(idp.AllowedAlgorithms),
            ClockSkewSeconds = idp.ClockSkewSeconds,
            AudienceClaim = idp.AudienceClaim,
            RequiredTokenUse = idp.RequiredTokenUse,
            ClaimMapping = DeserializeJsonObject(idp.ClaimMapping)
        }).ToList();

        _logger.LogDebug("Loaded {Count} enabled IdP configurations from IAM", entries.Count);

        return entries;
    }

    private static List<string> DeserializeJsonArray(string json)
    {
        if (string.IsNullOrWhiteSpace(json) || json == "[]")
            return new List<string>();

        try
        {
            return JsonSerializer.Deserialize<List<string>>(json) ?? new List<string>();
        }
        catch
        {
            return new List<string>();
        }
    }

    private static Dictionary<string, string> DeserializeJsonObject(string json)
    {
        if (string.IsNullOrWhiteSpace(json) || json == "{}")
            return new Dictionary<string, string>();

        try
        {
            return JsonSerializer.Deserialize<Dictionary<string, string>>(json) ?? new Dictionary<string, string>();
        }
        catch
        {
            return new Dictionary<string, string>();
        }
    }
}
