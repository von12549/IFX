using App.Abstractions;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace AuthSamples.Modules.Auth.Composition
{
    /// <summary>
    /// Extension methods for registering the Auth module.
    /// </summary>
    public static class DependencyInjection
    {
        private static readonly AuthModuleInstaller _installer = new();

        /// <summary>
        /// Registers all Auth module services and the module installer.
        /// </summary>
        public static IServiceCollection AddAuthModule(
            this IServiceCollection services,
            IConfiguration configuration)
        {
            // Register the module installer for discovery
            services.AddSingleton<IModuleInstaller>(_installer);

            // Install module services
            _installer.InstallServices(services, configuration);

            return services;
        }

        /// <summary>
        /// Maps all Auth module endpoints (19 total: 6 Auth, 5 User, 2 UserManagement, 3 Role, 3 Idp).
        /// Note: Prefer using IModuleInstaller.MapEndpoints() via the discovery pattern.
        /// </summary>
        public static IEndpointRouteBuilder MapAuthModuleEndpoints(this IEndpointRouteBuilder builder)
        {
            return _installer.MapEndpoints(builder);
        }
    }
}
