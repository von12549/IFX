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


namespace AuthSamples.Modules.Auth.Composition
{
    public static class DependencyInjection
    {
        public static IServiceCollection AddAuthModuleServices(
        this IServiceCollection services,
        IConfiguration configuration)
        {
            services.AddApplicationServices();
            services.AddInfrastructureServices(configuration);
            return services;
        }

        /// <summary>
        /// Maps all Auth module endpoints (19 total: 6 Auth, 5 User, 2 UserManagement, 3 Role, 3 Idp)
        /// </summary>
        /// <param name="builder">The endpoint route builder</param>
        /// <returns>The endpoint route builder for chaining</returns>
        public static IEndpointRouteBuilder MapAuthModuleEndpoints(this IEndpointRouteBuilder builder)
        {
            builder.MapAuthEndpoints();          // 6 endpoints: register, confirm, login, refresh, revoke, logout
            builder.MapUserEndpoints();          // 5 endpoints: profile (GET/PUT), login-history, activity-log, sync
            builder.MapUserManagementEndpoints(); // 2 endpoints: users (GET/PUT) - Admin only
            builder.MapRoleEndpoints();          // 3 endpoints: roles (GET/POST/PUT) - Admin only
            builder.MapIdpEndpoints();           // 3 endpoints: idps (GET/POST/PUT) - Admin only
            return builder;
        }

    }
}
