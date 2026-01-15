using System.IdentityModel.Tokens.Jwt;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;

namespace AuthSamples.ApiHost.Authentication;

public class DynamicJwtBearerEvents : JwtBearerEvents
{
    private readonly IIdpConfigurationService _idpConfigService;
    private readonly ILogger<DynamicJwtBearerEvents> _logger;

    public DynamicJwtBearerEvents(
        IIdpConfigurationService idpConfigService,
        ILogger<DynamicJwtBearerEvents> logger)
    {
        _idpConfigService = idpConfigService;
        _logger = logger;
    }

    public override async Task MessageReceived(MessageReceivedContext context)
    {
        var token = context.Request.Headers.Authorization.FirstOrDefault()?.Replace("Bearer ", "");
        if (string.IsNullOrEmpty(token))
            return;

        try
        {
            // Read unvalidated JWT to get issuer
            var handler = new JwtSecurityTokenHandler();
            var jwtToken = handler.ReadJwtToken(token);
            var issuer = jwtToken.Issuer;

            // Look up IdP by issuer
            var idpConfig = await _idpConfigService.GetByIssuerAsync(issuer, context.HttpContext.RequestAborted);
            if (idpConfig == null)
            {
                _logger.LogWarning("Token from unknown or disabled issuer: {Issuer}", issuer);
                context.Fail("Unknown or disabled identity provider");
                return;
            }

            // Get OIDC configuration
            var openIdConfig = await idpConfig.ConfigurationManager!.GetConfigurationAsync(context.HttpContext.RequestAborted);

            // Configure dynamic validation parameters
            context.Options.MapInboundClaims = false;
            context.Options.TokenValidationParameters = new TokenValidationParameters
            {
                ValidateIssuer = true,
                ValidIssuer = idpConfig.Issuer,
                ValidateAudience = idpConfig.ExpectedAudiences.Count > 0,
                ValidAudiences = idpConfig.ExpectedAudiences,
                ValidAlgorithms = idpConfig.AllowedAlgorithms.Count > 0 ? idpConfig.AllowedAlgorithms : null,
                ClockSkew = TimeSpan.FromSeconds(idpConfig.ClockSkewSeconds),
                ValidateIssuerSigningKey = true,
                IssuerSigningKeys = openIdConfig.SigningKeys,
                ValidateLifetime = true,
                NameClaimType = "sub"
            };

            // Store IdP config for later use in claims transformation
            context.HttpContext.Items["IdpConfiguration"] = idpConfig;

            // Store access token for userinfo endpoint call during auto-provisioning
            context.HttpContext.Items["AccessToken"] = token;

            _logger.LogDebug("Configured token validation for issuer: {Issuer}", issuer);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error processing JWT token");
            context.Fail("Invalid token format");
        }
    }

    public override Task TokenValidated(TokenValidatedContext context)
    {
        var issuer = context.Principal?.FindFirst("iss")?.Value;
        var subject = context.Principal?.FindFirst("sub")?.Value;
        _logger.LogDebug("Token validated for {Issuer}/{Subject}", issuer, subject);
        return Task.CompletedTask;
    }

    public override Task AuthenticationFailed(AuthenticationFailedContext context)
    {
        _logger.LogWarning(context.Exception, "Authentication failed");
        return Task.CompletedTask;
    }
}
