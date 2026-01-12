using AuthSamples.ApiHost.Authorization;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;

namespace AuthSamples.ApiHost.Configuration;

public static class AuthenticationConfiguration
{
    /// <summary>
    /// Configures JWT Bearer authentication with AWS Cognito and role claims transformation
    /// </summary>
    public static IServiceCollection AddAuthAuthentication(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        var cognitoSettings = configuration.GetSection("CognitoSettings");
        var region = cognitoSettings["Region"];
        var userPoolId = cognitoSettings["UserPoolId"];
        var authority = $"https://cognito-idp.{region}.amazonaws.com/{userPoolId}";

        // Configure JWT Bearer authentication
        services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
            .AddJwtBearer(options =>
            {
                options.Authority = authority;
                options.MapInboundClaims = false;
                options.TokenValidationParameters = new TokenValidationParameters
                {
                    ValidateIssuerSigningKey = true,
                    ValidateIssuer = true,
                    ValidateLifetime = true,
                    ValidateAudience = false,
                    NameClaimType = "sub"
                };
            });

        // Add claims transformation to inject role from database into JWT claims
        services.AddTransient<IClaimsTransformation, UserRoleClaimsTransformation>();

        return services;
    }
}
