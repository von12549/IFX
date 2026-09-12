using System.Collections.Concurrent;
using System.IdentityModel.Tokens.Jwt;
using IFX.Platform.Authentication.Contracts.V1;
using Microsoft.IdentityModel.Protocols;
using Microsoft.IdentityModel.Protocols.OpenIdConnect;
using Microsoft.IdentityModel.Tokens;

namespace IFX.Platform.Authentication.Runtime;

public sealed class TokenValidationService : ITokenValidationContract
{
    private readonly Func<string, IConfigurationManager<OpenIdConnectConfiguration>> _createManager;
    private readonly ConcurrentDictionary<string, IConfigurationManager<OpenIdConnectConfiguration>> _managers = new(StringComparer.Ordinal);

    public TokenValidationService() : this(authority => new ConfigurationManager<OpenIdConnectConfiguration>(
        authority.TrimEnd('/') + "/.well-known/openid-configuration",
        new OpenIdConnectConfigurationRetriever(), new HttpDocumentRetriever { RequireHttps = true })) { }

    public TokenValidationService(Func<string, IConfigurationManager<OpenIdConnectConfiguration>> createManager)
        => _createManager = createManager;

    public async Task<TokenValidationResponse> ValidateAsync(string token, IssuerValidationOptions trustedIssuer,
        string? expectedNonce = null, CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(token) || token.Length > 32768 ||
            !Uri.TryCreate(trustedIssuer.Authority, UriKind.Absolute, out var authority) || authority.Scheme != "https" ||
            string.IsNullOrWhiteSpace(trustedIssuer.Issuer) || trustedIssuer.Audiences.Count == 0 ||
            trustedIssuer.Algorithms.Count == 0 || trustedIssuer.Algorithms.Any(algorithm => algorithm is "none" or "HS256" or "HS384" or "HS512") ||
            trustedIssuer.ClockSkewSeconds is < 0 or > 300 || trustedIssuer.AudienceClaim is not ("aud" or "client_id"))
            return new(null, "invalid_validation_configuration");

        try
        {
            var manager = _managers.GetOrAdd(trustedIssuer.Authority, _createManager);
            for (var attempt = 0; attempt < 2; attempt++)
            {
                var metadata = await manager.GetConfigurationAsync(cancellationToken);
                if (!string.Equals(metadata.Issuer, trustedIssuer.Issuer, StringComparison.Ordinal))
                    return new(null, "metadata_issuer_mismatch");

                // Every operation has its own parameters and handler. No request changes shared options.
                var parameters = new TokenValidationParameters
                {
                    ValidateIssuer = true, ValidIssuer = trustedIssuer.Issuer,
                    ValidateAudience = true, ValidAudiences = trustedIssuer.Audiences.ToArray(),
                    ValidAlgorithms = trustedIssuer.Algorithms.ToArray(),
                    ValidateIssuerSigningKey = true, IssuerSigningKeys = metadata.SigningKeys.ToArray(),
                    RequireSignedTokens = true, RequireExpirationTime = true, ValidateLifetime = true,
                    ClockSkew = TimeSpan.FromSeconds(trustedIssuer.ClockSkewSeconds)
                };
                if (trustedIssuer.AudienceClaim == "client_id")
                    parameters.AudienceValidator = (_, tokenValue, _) => tokenValue is JwtSecurityToken jwt &&
                        jwt.Claims.Any(claim => claim.Type == "client_id" && trustedIssuer.Audiences.Contains(claim.Value, StringComparer.Ordinal));
                try
                {
                    var handler = new JwtSecurityTokenHandler { MapInboundClaims = false };
                    var principal = handler.ValidateToken(token, parameters, out _);
                    var subject = principal.FindFirst("sub")?.Value;
                    if (string.IsNullOrWhiteSpace(subject)) return new(null, "missing_subject");
                    if (trustedIssuer.RequiredTokenUse is not null && principal.FindFirst("token_use")?.Value != trustedIssuer.RequiredTokenUse)
                        return new(null, "token_use_mismatch");
                    if (expectedNonce is not null && !string.Equals(principal.FindFirst("nonce")?.Value, expectedNonce, StringComparison.Ordinal))
                        return new(null, "nonce_mismatch");
                    return new(new(trustedIssuer.Issuer, subject), "validated");
                }
                catch (SecurityTokenSignatureKeyNotFoundException) when (attempt == 0)
                {
                    manager.RequestRefresh();
                }
            }
            return new(null, "signing_key_unavailable");
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested) { throw; }
        catch (SecurityTokenException) { return new(null, "invalid_token"); }
        catch (ArgumentException) { return new(null, "invalid_token"); }
        catch (Exception) { return new(null, "validation_unavailable"); }
    }
}
