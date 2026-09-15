using IFX.BuildingBlocks.Composition;
using IFX.Modules.CRM.Application;
using IFX.Modules.CRM.Application.AccountCompliance;
using IFX.Modules.CRM.Contracts.V1;
using IFX.Modules.CRM.Infrastructure;
using IFX.Modules.CRM.Infrastructure.Integrations.Inbound;
using IFX.Modules.CRM.Infrastructure.Persistence;
using IFX.Modules.CRM.Presentation.Extensions;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Serilog;

namespace IFX.Modules.CRM.Composition;

/// <summary>
/// CRM module installer — registers all CRM module services and endpoints.
/// </summary>
public sealed class CrmModuleInstaller : IModuleInstaller
{
    public string ModuleName => "CRM";

    public IServiceCollection InstallServices(IServiceCollection services, IConfiguration configuration)
    {
        Log.Information("[{Module}] Registering module services...", ModuleName);

        services.AddApplicationServices();
        services.AddInfrastructureServices(configuration);
        services.AddScoped<IAccountComplianceUseCase, AccountComplianceUseCase>();
        services.AddScoped<IAccountComplianceContract, AccountComplianceInboundAdapter>();

        Log.Information("[{Module}] Module services registered successfully", ModuleName);
        return services;
    }

    public IEndpointRouteBuilder MapEndpoints(IEndpointRouteBuilder builder)
    {
        Log.Information("[{Module}] Mapping module endpoints...", ModuleName);

        builder.MapPartyEndpoints();
        builder.MapInvestorEndpoints();
        builder.MapInvestmentAccountEndpoints();

        Log.Information("[{Module}] Module endpoints mapped", ModuleName);
        return builder;
    }
}
