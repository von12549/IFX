using System.Collections.Concurrent;
using System.Text.Json;
using IFX.Modules.IAM.Composition;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.IdentityModel.Protocols;
using Microsoft.IdentityModel.Protocols.OpenIdConnect;

namespace IFX.ApiHost.Authentication;

public class IdpConfigurationService : IIdpConfigurationService
{
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly IAuthIdpCacheVersion _cacheVersion;
    private readonly IMemoryCache _cache;
    private readonly ILogger<IdpConfigurationService> _logger;
    private readonly ConcurrentDictionary<string, ConfigurationManager<OpenIdConnectConfiguration>> _configManagers = new();
    private const string CacheKey = "EnabledIdpConfigurations";
    private static readonly TimeSpan CacheDuration = TimeSpan.FromMinutes(5);
    private long _observedVersion = -1;

    public IdpConfigurationService(
        IServiceScopeFactory scopeFactory,
        IAuthIdpCacheVersion cacheVersion,
        IMemoryCache cache,
        ILogger<IdpConfigurationService> logger)
    {
        _scopeFactory = scopeFactory;
        _cacheVersion = cacheVersion;
        _cache = cache;
        _logger = logger;
    }

    public async Task<IdpConfigurationEntry?> GetByIssuerAsync(string issuer, CancellationToken ct = default)
    {
        var all = await GetAllEnabledAsync(ct);
        var entry = all.FirstOrDefault(x => x.Issuer == issuer);

        if (entry != null)
        {
            entry.ConfigurationManager = GetOrCreateConfigurationManager(entry);
        }

        return entry;
    }

    public async Task<IReadOnlyList<IdpConfigurationEntry>> GetAllEnabledAsync(CancellationToken ct = default)
    {
        var currentVersion = _cacheVersion.Version;
        if (Interlocked.Read(ref _observedVersion) != currentVersion)
        {
            _cache.Remove(CacheKey);
            Interlocked.Exchange(ref _observedVersion, currentVersion);
        }

        if (_cache.TryGetValue(CacheKey, out IReadOnlyList<IdpConfigurationEntry>? cached) && cached != null)
            return cached;

        using var scope = _scopeFactory.CreateScope();
        var reader = scope.ServiceProvider.GetRequiredService<IAuthIdpConfigurationReader>();
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
            ClaimMapping = DeserializeJsonObject(idp.ClaimMapping)
        }).ToList();

        _cache.Set(CacheKey, (IReadOnlyList<IdpConfigurationEntry>)entries,
            new MemoryCacheEntryOptions().SetSlidingExpiration(CacheDuration));

        _logger.LogDebug("Loaded {Count} enabled IdP configurations into cache", entries.Count);

        return entries;
    }

    public void InvalidateCache()
    {
        _cache.Remove(CacheKey);
        Interlocked.Exchange(ref _observedVersion, _cacheVersion.Version);
        _logger.LogInformation("IdP configuration cache invalidated");
    }

    private ConfigurationManager<OpenIdConnectConfiguration> GetOrCreateConfigurationManager(IdpConfigurationEntry entry)
    {
        return _configManagers.GetOrAdd(entry.Issuer, _ =>
        {
            var metadataAddress = $"{entry.Authority.TrimEnd('/')}/.well-known/openid-configuration";
            _logger.LogDebug("Creating OIDC ConfigurationManager for {Issuer} at {MetadataAddress}",
                entry.Issuer, metadataAddress);

            return new ConfigurationManager<OpenIdConnectConfiguration>(
                metadataAddress,
                new OpenIdConnectConfigurationRetriever(),
                new HttpDocumentRetriever());
        });
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
