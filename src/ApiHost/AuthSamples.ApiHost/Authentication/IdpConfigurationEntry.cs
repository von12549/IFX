using AuthSamples.Modules.Auth.Domain.Enums;
using Microsoft.IdentityModel.Protocols;
using Microsoft.IdentityModel.Protocols.OpenIdConnect;

namespace AuthSamples.ApiHost.Authentication;

public class IdpConfigurationEntry
{
    public Guid IdpId { get; init; }
    public string Issuer { get; init; } = string.Empty;
    public string Authority { get; init; } = string.Empty;
    public IdpType IdpType { get; init; }
    public bool AutoProvisionEnabled { get; init; }
    public List<string> ExpectedAudiences { get; init; } = new();
    public List<string> AllowedAlgorithms { get; init; } = new();
    public int ClockSkewSeconds { get; init; }
    public Dictionary<string, string> ClaimMapping { get; init; } = new();
    public ConfigurationManager<OpenIdConnectConfiguration>? ConfigurationManager { get; set; }
}
