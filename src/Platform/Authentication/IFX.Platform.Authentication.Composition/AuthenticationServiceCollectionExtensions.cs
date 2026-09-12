using IFX.Platform.Authentication.Contracts.V1;
using IFX.Platform.Authentication.Runtime;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;

namespace IFX.Platform.Authentication.Composition;

public static class AuthenticationServiceCollectionExtensions
{
    public static IServiceCollection AddPlatformAuthentication(this IServiceCollection services)
    {
        services.TryAddSingleton<ITokenValidationContract>(_ => new TokenValidationService());
        services.TryAddSingleton<IOidcProtocolContract, OidcProtocolService>();
        services.AddHttpClient("Authentication.Oidc", client => client.Timeout = TimeSpan.FromSeconds(30))
            .ConfigurePrimaryHttpMessageHandler(() => new HttpClientHandler { AllowAutoRedirect = false });
        services.TryAddSingleton<IHostTokenValidation, HostTokenValidation>();
        return services;
    }
}

// Host-facing composition facade keeps SDK and platform contracts out of host implementation.
public interface IHostTokenValidation
{
    Task<(string? Subject, string Reason)> ValidateAsync(string token, string issuer, string authority,
        IReadOnlyList<string> audiences, IReadOnlyList<string> algorithms, int clockSkewSeconds,
        CancellationToken cancellationToken, string audienceClaim = "aud", string? requiredTokenUse = null);
}

internal sealed class HostTokenValidation(ITokenValidationContract validator) : IHostTokenValidation
{
    public async Task<(string? Subject, string Reason)> ValidateAsync(string token, string issuer, string authority,
        IReadOnlyList<string> audiences, IReadOnlyList<string> algorithms, int clockSkewSeconds,
        CancellationToken cancellationToken, string audienceClaim = "aud", string? requiredTokenUse = null)
    {
        var response = await validator.ValidateAsync(token, new(issuer, authority, audiences, algorithms, clockSkewSeconds, audienceClaim, requiredTokenUse),
            cancellationToken: cancellationToken);
        return (response.Identity?.Subject, response.ReasonCode);
    }
}
