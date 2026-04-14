using Microsoft.AspNetCore.Routing;
using Microsoft.OpenApi.Models;

namespace IFX.ApiHost.Configuration;

public static class SwaggerConfiguration
{
    private static readonly Dictionary<string, string[]> ModuleTags = new()
    {
        ["auth"] =
        [
            "Authentication", "OAuth", "User", "User Management",
            "Role", "RoleGroup", "Permission", "Tenant", "Department",
            "Identity Provider", "Email Verification",
            "Policy", "Platform Policy", "Platform GlobalRoles"
        ],
        ["crm"]         = ["Party", "Investor", "InvestmentAccount"],
        ["registry"]    = ["Product", "Fund", "FundClass"],
        ["holdings"]    = ["Holdings"],
        ["transaction"] = ["Transactions"],
    };

    public static IServiceCollection AddAuthSwagger(this IServiceCollection services)
    {
        services.AddEndpointsApiExplorer();
        services.AddSwaggerGen(options =>
        {
            options.SwaggerDoc("auth", new OpenApiInfo
            {
                Title = "Auth",
                Version = "v1",
                Description = "Authentication, users, roles, tenants, and ABAC policies."
            });
            options.SwaggerDoc("crm", new OpenApiInfo
            {
                Title = "CRM",
                Version = "v1",
                Description = "Parties, investors, and investment accounts."
            });
            options.SwaggerDoc("registry", new OpenApiInfo
            {
                Title = "Registry",
                Version = "v1",
                Description = "Funds and fund classes."
            });
            options.SwaggerDoc("holdings", new OpenApiInfo
            {
                Title = "Holdings",
                Version = "v1",
                Description = "Unit holdings ledger (read-only)."
            });
            options.SwaggerDoc("transaction", new OpenApiInfo
            {
                Title = "Transaction",
                Version = "v1",
                Description = "Subscriptions, redemptions, transfers, and switches."
            });

            options.DocInclusionPredicate((docName, apiDesc) =>
            {
                if (!ModuleTags.TryGetValue(docName, out var tags))
                    return false;

                var endpointTags = apiDesc.ActionDescriptor.EndpointMetadata
                    .OfType<TagsAttribute>()
                    .SelectMany(t => t.Tags)
                    .ToHashSet();

                return tags.Any(endpointTags.Contains);
            });

            // JWT Bearer
            options.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
            {
                Description = "JWT Authorization header using the Bearer scheme. Enter 'Bearer' [space] and then your token.",
                Name = "Authorization",
                In = ParameterLocation.Header,
                Type = SecuritySchemeType.Http,
                Scheme = "Bearer",
                BearerFormat = "JWT"
            });

            options.AddSecurityRequirement(new OpenApiSecurityRequirement
            {
                {
                    new OpenApiSecurityScheme
                    {
                        Reference = new OpenApiReference
                        {
                            Type = ReferenceType.SecurityScheme,
                            Id = "Bearer"
                        }
                    },
                    Array.Empty<string>()
                }
            });
        });

        return services;
    }
}
