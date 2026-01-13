using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace App.Abstractions
{
    /// <summary>
    /// Interface for module installers that register services and map endpoints.
    /// Implement this interface in each module's Composition layer.
    /// </summary>
    public interface IModuleInstaller
    {
        /// <summary>
        /// Gets the module name for logging and identification.
        /// </summary>
        string ModuleName { get; }

        /// <summary>
        /// Registers module services with the dependency injection container.
        /// </summary>
        /// <param name="services">The service collection.</param>
        /// <param name="configuration">The application configuration.</param>
        /// <returns>The service collection for chaining.</returns>
        IServiceCollection InstallServices(IServiceCollection services, IConfiguration configuration);

        /// <summary>
        /// Maps module endpoints to the application.
        /// </summary>
        /// <param name="builder">The endpoint route builder.</param>
        /// <returns>The endpoint route builder for chaining.</returns>
        IEndpointRouteBuilder MapEndpoints(IEndpointRouteBuilder builder);
    }
}
