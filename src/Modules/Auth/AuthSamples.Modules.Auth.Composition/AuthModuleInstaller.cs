using App.Abstractions;
using AuthSamples.Modules.Auth.Application;
using AuthSamples.Modules.Auth.Infrastructure;
using AuthSamples.Modules.Auth.Presentation.Endpoints.Auth;
using AuthSamples.Modules.Auth.Presentation.Endpoints.Idp;
using AuthSamples.Modules.Auth.Presentation.Endpoints.Role;
using AuthSamples.Modules.Auth.Presentation.Endpoints.User;
using AuthSamples.Modules.Auth.Presentation.Endpoints.UserManagement;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Serilog;

namespace AuthSamples.Modules.Auth.Composition
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
            builder.MapUserEndpoints();           // 5 endpoints: profile (GET/PUT), login-history, activity-log, sync
            builder.MapUserManagementEndpoints(); // 2 endpoints: users (GET/PUT) - Admin only
            builder.MapRoleEndpoints();           // 3 endpoints: roles (GET/POST/PUT) - Admin only
            builder.MapIdpEndpoints();            // 3 endpoints: idps (GET/POST/PUT) - Admin only

            Log.Information("[{Module}] Module endpoints mapped: 19 total (6 Auth, 5 User, 2 UserManagement, 3 Role, 3 Idp)", ModuleName);
            return builder;
        }
    }
}
