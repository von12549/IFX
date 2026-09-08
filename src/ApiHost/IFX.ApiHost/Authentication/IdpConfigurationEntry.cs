using Microsoft.IdentityModel.Protocols;
using Microsoft.IdentityModel.Protocols.OpenIdConnect;

namespace IFX.ApiHost.Authentication;

public class IdpConfigurationEntry
{
    public Guid IdpId { get; init; }
    public string Issuer { get; init; } = string.Empty;
    public string Authority { get; init; } = string.Empty;
    public string IdpType { get; init; } = string.Empty;
    public bool AutoProvisionEnabled { get; init; }
    public List<string> ExpectedAudiences { get; init; } = new();
    public List<string> AllowedAlgorithms { get; init; } = new();
    public int ClockSkewSeconds { get; init; }
    public Dictionary<string, string> ClaimMapping { get; init; } = new();
    public ConfigurationManager<OpenIdConnectConfiguration>? ConfigurationManager { get; set; }
}
