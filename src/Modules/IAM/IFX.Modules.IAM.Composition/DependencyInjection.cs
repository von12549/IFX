using IFX.BuildingBlocks.Composition;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace IFX.Modules.IAM.Composition
{
    /// <summary>
    /// Extension methods for registering the IAM module.
    /// </summary>
    public static class DependencyInjection
    {
        private static readonly IamModuleInstaller _installer = new();

        /// <summary>
        /// Registers all IAM module services and the module installer.
        /// </summary>
        public static IServiceCollection AddIamModule(
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
        /// Maps IAM endpoints through the module installer.
        /// Note: Prefer using IModuleInstaller.MapEndpoints() via the discovery pattern.
        /// </summary>
        public static IEndpointRouteBuilder MapIamModuleEndpoints(this IEndpointRouteBuilder builder)
        {
            return _installer.MapEndpoints(builder);
        }
    }
}
