using AuthSamples.Modules.Auth.Domain.Common;

namespace AuthSamples.Modules.Auth.Domain.Entities;

public class Idp : BaseEntity, IAuditableEntity
{
    public string Name { get; private set; } = string.Empty;
    public string Issuer { get; private set; } = string.Empty;
    public string Description { get; private set; } = string.Empty;
    public string LoginUrl { get; private set; } = string.Empty;
    public bool Enabled { get; private set; } = true;
    public bool AutoProvisionEnabled { get; private set; } = true;
    public string Authority { get; private set; } = string.Empty;
    public string ExpectedAudiences { get; private set; } = "[]"; // JSON array
    public string AllowedAlgs { get; private set; } = "[]"; // JSON array
    public string RequiredScopes { get; private set; } = "[]"; // JSON array
    public string ClaimMapping { get; private set; } = "{}"; // JSON object
    public int ClockSkewSeconds { get; private set; } = 300; // 5 minutes default
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    private Idp() { } // For EF Core

    public static Idp Create(
        string name,
        string issuer,
        string authority,
        string description,
        string loginUrl,
        bool enabled = true,
        bool autoProvisionEnabled = true,
        string? expectedAudiences = null,
        string? allowedAlgs = null,
        string? requiredScopes = null,
        string? claimMapping = null,
        int clockSkewSeconds = 300)
    {
        if (string.IsNullOrWhiteSpace(name))
            throw new ArgumentException("IdP name cannot be empty", nameof(name));

        if (string.IsNullOrWhiteSpace(issuer))
            throw new ArgumentException("Issuer cannot be empty", nameof(issuer));

        if (string.IsNullOrWhiteSpace(authority))
            throw new ArgumentException("Authority cannot be empty", nameof(authority));

        var idp = new Idp
        {
            Name = name.Trim(),
            Issuer = issuer.Trim(),
            Authority = authority.Trim(),
            Description = description?.Trim() ?? string.Empty,
            LoginUrl = loginUrl?.Trim() ?? string.Empty,
            Enabled = enabled,
            AutoProvisionEnabled = autoProvisionEnabled,
            ExpectedAudiences = expectedAudiences ?? "[]",
            AllowedAlgs = allowedAlgs ?? "[]",
            RequiredScopes = requiredScopes ?? "[]",
            ClaimMapping = claimMapping ?? "{}",
            ClockSkewSeconds = clockSkewSeconds
        };

        return idp;
    }

    public void Update(
        string name,
        string issuer,
        string authority,
        string description,
        string loginUrl,
        bool enabled,
        bool autoProvisionEnabled,
        string expectedAudiences,
        string allowedAlgs,
        string requiredScopes,
        string claimMapping,
        int clockSkewSeconds)
    {
        if (string.IsNullOrWhiteSpace(name))
            throw new ArgumentException("IdP name cannot be empty", nameof(name));

        if (string.IsNullOrWhiteSpace(issuer))
            throw new ArgumentException("Issuer cannot be empty", nameof(issuer));

        if (string.IsNullOrWhiteSpace(authority))
            throw new ArgumentException("Authority cannot be empty", nameof(authority));

        Name = name.Trim();
        Issuer = issuer.Trim();
        Authority = authority.Trim();
        Description = description?.Trim() ?? string.Empty;
        LoginUrl = loginUrl?.Trim() ?? string.Empty;
        Enabled = enabled;
        AutoProvisionEnabled = autoProvisionEnabled;
        ExpectedAudiences = expectedAudiences;
        AllowedAlgs = allowedAlgs;
        RequiredScopes = requiredScopes;
        ClaimMapping = claimMapping;
        ClockSkewSeconds = clockSkewSeconds;
    }

    public void Disable() => Enabled = false;
    public void Enable() => Enabled = true;
}
