namespace IFX.Platform.Authentication.Contracts.V1;

// This is a synchronous, sensitive protocol boundary. Tokens are never event payloads.
public sealed record IssuerValidationOptions(
    string Issuer, string Authority, IReadOnlyList<string> Audiences,
    IReadOnlyList<string> Algorithms, int ClockSkewSeconds, string AudienceClaim = "aud", string? RequiredTokenUse = null);

public sealed record VerifiedIdentityDto(string Issuer, string Subject);

public sealed record TokenValidationResponse(VerifiedIdentityDto? Identity, string ReasonCode)
{
    public bool IsValid => Identity is not null;
}

public interface ITokenValidationContract
{
    Task<TokenValidationResponse> ValidateAsync(string token, IssuerValidationOptions trustedIssuer,
        string? expectedNonce = null, CancellationToken cancellationToken = default);
}
