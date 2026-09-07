using App.Abstractions;
using IFX.Modules.Auth.Application;
using IFX.Modules.Auth.Infrastructure;
using IFX.Modules.Auth.Infrastructure.IdentityProviders.Auth0;
using IFX.Modules.Auth.Infrastructure.IdentityProviders.Cognito;
using IFX.Modules.Auth.Presentation.Authorization.Endpoints;

using IFX.Modules.Auth.Presentation.Identity.Endpoints;
using IFX.Modules.Auth.Presentation.Users.Endpoints;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Serilog;

namespace IFX.Modules.Auth.Composition
{
    /// <summary>
    /// Auth module installer - registers all Auth module services and endpoints.
    /// </summary>
    public sealed class AuthModuleInstaller : IModuleInstaller
    {
        public string ModuleName => "Auth";

        public IServiceCollection InstallServices(IServiceCollection services, IConfiguration configuration)
        {
            Log.Information("[{Module}] Registering module services...", ModuleName);

            services.AddApplicationServices();
            services.AddInfrastructureServices(configuration);

            var provider = configuration["Authentication:Provider"] ?? "Cognito";
            switch (provider.ToLowerInvariant())
            {
                case "cognito":
                    services.AddCognitoProvider(configuration);
                    break;
                case "auth0":
                    services.AddAuth0Provider(configuration);
                    break;
                default:
                    throw new InvalidOperationException(
                        $"Unknown identity provider '{provider}'. Valid values: Cognito, Auth0.");
            }

            Log.Information("[{Module}] Identity provider: {Provider}", ModuleName, provider);

            Log.Information("[{Module}] Module services registered successfully", ModuleName);
            return services;
        }

        public IEndpointRouteBuilder MapEndpoints(IEndpointRouteBuilder builder)
        {
            Log.Information("[{Module}] Mapping module endpoints...", ModuleName);

            builder.MapAuthEndpoints();              // 6 endpoints: register, confirm, login, refresh, revoke, logout
            builder.MapOAuthEndpoints();             // 5 endpoints: authorize, callback, userinfo, logout, logout-callback
            builder.MapUserEndpoints();              // 5 endpoints: profile (GET/PUT), login-history, activity-log, sync
            builder.MapUserManagementEndpoints();    // 3 endpoints: users (GET/PUT), send-test-email
            builder.MapRoleEndpoints();              // 6 endpoints: roles (GET/POST/PUT/DELETE + permissions)
            builder.MapPermissionEndpoints();        // 4 endpoints: permissions (GET/POST/PUT/DELETE)
            builder.MapRoleGroupEndpoints();         // 6 endpoints: role groups (GET/POST/PUT/DELETE + roles)
            builder.MapTenantEndpoints();            // 5 endpoints: tenants (GET/GET-by-id/POST/PUT/DELETE)
            builder.MapDepartmentEndpoints();        // 5 endpoints: departments (GET/GET-by-id/POST/PUT/DELETE)
            builder.MapIdpEndpoints();               // 3 endpoints: idps (GET/POST/PUT)
            builder.MapEmailVerificationEndpoints(); // 4 endpoints: verify, send-verification, resend-verification, verification-status
            builder.MapPolicyEndpoints();            // 5 endpoints: policies (GET/POST/PUT/DELETE + templates)
            builder.MapPlatformPolicyEndpoints();    // 4 endpoints: platform policies (GET/POST/PUT/DELETE)
            builder.MapGlobalRoleEndpoints();        // 4 endpoints: global roles (GET/GET-by-user/POST/DELETE)

            Log.Information("[{Module}] Module endpoints mapped: 69 total (6 Auth, 5 OAuth, 5 User, 7 UserManagement, 6 Role, 4 Permission, 6 RoleGroup, 5 Tenant, 5 Department, 3 Idp, 4 EmailVerification, 5 Policy, 4 Platform Policy, 4 GlobalRole)", ModuleName);
            return builder;
        }
    }
}
