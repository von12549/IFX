using System.IdentityModel.Tokens.Jwt;
using System.Net.Http.Headers;
using System.Security.Claims;
using IFX.Platform.Authentication.Composition;
using Microsoft.AspNetCore.Authentication.JwtBearer;

namespace IFX.ApiHost.Authentication;

public sealed class DynamicJwtBearerEvents(
    IIdpConfigurationService configurations,
    IHostTokenValidation validation,
    ILogger<DynamicJwtBearerEvents> logger) : JwtBearerEvents
{
    public override async Task MessageReceived(MessageReceivedContext context)
    {
        var header = context.Request.Headers.Authorization.ToString();
        if (string.IsNullOrWhiteSpace(header)) { context.NoResult(); return; }
        if (!AuthenticationHeaderValue.TryParse(header, out var authorization) ||
            !string.Equals(authorization.Scheme, "Bearer", StringComparison.OrdinalIgnoreCase) ||
            string.IsNullOrWhiteSpace(authorization.Parameter) || authorization.Parameter.Length > 32768)
        {
            context.Fail("Invalid bearer header");
            return;
        }
        try
        {
            var token = authorization.Parameter;
            // Unverified issuer is only a lookup key. IAM decides whether it is trusted.
            var issuer = new JwtSecurityTokenHandler().ReadJwtToken(token).Issuer;
            var configuration = await configurations.GetByIssuerAsync(issuer, context.HttpContext.RequestAborted);
            if (configuration is null) { context.Fail("Unknown or disabled identity provider"); return; }
            var result = await validation.ValidateAsync(token, configuration.Issuer, configuration.Authority,
                configuration.ExpectedAudiences, configuration.AllowedAlgorithms, configuration.ClockSkewSeconds,
                context.HttpContext.RequestAborted, configuration.AudienceClaim, configuration.RequiredTokenUse);
            if (result.Subject is null) { context.Fail(result.Reason); return; }
            // External role/user_id claims cannot masquerade as local IAM authorization facts.
            context.Principal = new ClaimsPrincipal(new ClaimsIdentity(
                [new Claim("iss", issuer), new Claim("sub", result.Subject)], context.Scheme.Name, "sub", "role"));
            context.HttpContext.Items["IdpConfiguration"] = configuration;
            context.HttpContext.Items["AccessToken"] = token;
            context.Success();
        }
        catch (OperationCanceledException) when (context.HttpContext.RequestAborted.IsCancellationRequested) { throw; }
        catch (Exception exception)
        {
            logger.LogWarning("Bearer validation failed with {FailureType}", exception.GetType().Name);
            context.Fail("Bearer validation failed");
        }
    }
}
