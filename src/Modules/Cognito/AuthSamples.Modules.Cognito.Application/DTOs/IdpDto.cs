namespace AuthSamples.Modules.Cognito.Application.DTOs;

public class IdpDto
{
    public Guid Id { get; init; }
    public string Name { get; init; } = string.Empty;
    public string Issuer { get; init; } = string.Empty;
    public string Description { get; init; } = string.Empty;
    public string LoginUrl { get; init; } = string.Empty;
    public bool Enabled { get; init; }
    public bool AutoProvisionEnabled { get; init; }
    public string Authority { get; init; } = string.Empty;
    public string ExpectedAudiences { get; init; } = string.Empty;
    public string AllowedAlgs { get; init; } = string.Empty;
    public string RequiredScopes { get; init; } = string.Empty;
    public string ClaimMapping { get; init; } = string.Empty;
    public int ClockSkewSeconds { get; init; }
}
