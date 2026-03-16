using App.Abstractions;
using IFX.Modules.Auth.Application;
using IFX.Modules.Auth.Infrastructure;
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
            services.AddScoped<IAppMigrator, AuthMigrator>();

            Log.Information("[{Module}] Module services registered successfully", ModuleName);
            return services;
        }

        public IEndpointRouteBuilder MapEndpoints(IEndpointRouteBuilder builder)
        {
            Log.Information("[{Module}] Mapping module endpoints...", ModuleName);

            builder.MapAuthEndpoints();           // 6 endpoints: register, confirm, login, refresh, revoke, logout
            builder.MapOAuthEndpoints();          // 5 endpoints: authorize, callback, userinfo, logout, logout-callback
            builder.MapUserEndpoints();           // 5 endpoints: profile (GET/PUT), login-history, activity-log, sync
            builder.MapUserManagementEndpoints(); // 3 endpoints: users (GET/PUT), send-test-email - Admin only
            builder.MapRoleEndpoints();           // 3 endpoints: roles (GET/POST/PUT) - Admin only
            builder.MapIdpEndpoints();            // 3 endpoints: idps (GET/POST/PUT) - Admin only
            builder.MapEmailVerificationEndpoints(); // 4 endpoints: verify, send-verification, resend-verification, verification-status

            Log.Information("[{Module}] Module endpoints mapped: 29 total (6 Auth, 5 OAuth, 5 User, 3 UserManagement, 3 Role, 3 Idp, 4 EmailVerification)", ModuleName);
            return builder;
        }
    }
}
