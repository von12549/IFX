using IFX.ApiHost.Authentication;
using IFX.ApiHost.Authorization;
using IFX.Platform.Authentication.Composition;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;

namespace IFX.ApiHost.Configuration;

public static class AuthenticationConfiguration
{
    /// <summary>
    /// Configures JWT Bearer authentication with dynamic multi-IdP support and role claims transformation
    /// </summary>
    public static IServiceCollection AddAuthAuthentication(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        services.AddPlatformAuthentication();
        // IAM selects trusted providers; the platform executes token validation.
        services.AddMemoryCache();
        services.AddSingleton<IdpConfigurationService>();
        services.AddSingleton<IIdpConfigurationService>(sp => sp.GetRequiredService<IdpConfigurationService>());
        services.AddScoped<DynamicJwtBearerEvents>();

        // Add HttpContextAccessor for claims transformation
        services.AddHttpContextAccessor();

        // Configure JWT Bearer authentication with dynamic validation
        services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
            .AddJwtBearer(options =>
            {
                // Disable static validation (handled dynamically by DynamicJwtBearerEvents)
                options.TokenValidationParameters = new TokenValidationParameters
                {
                    ValidateIssuer = true,
                    ValidateAudience = true,
                    ValidateIssuerSigningKey = true,
                    ValidateLifetime = true,
                    NameClaimType = "sub"
                };

                // Use dynamic events for multi-IdP token validation
                options.EventsType = typeof(DynamicJwtBearerEvents);
            });

        // Add claims transformation to inject permissions from database into JWT claims
        services.AddTransient<IClaimsTransformation, UserPermissionClaimsTransformation>();

        return services;
    }
}
