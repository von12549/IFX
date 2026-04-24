using IFX.BuildingBlocks.Security.Authorization;
using IFX.BuildingBlocks.Security.Authorization.Abac.Engine;
using IFX.BuildingBlocks.Security.Authorization.Abac.Registry;
using IFX.BuildingBlocks.Security.Authorization.Abac.Resolver;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.Modules.Transaction.Abstractions.Interfaces;
using IFX.Modules.Transaction.Application.Interfaces;
using IFX.Modules.Transaction.Domain.Repositories;
using IFX.Modules.Transaction.Infrastructure.Repositories;
using IFX.Modules.Transaction.Infrastructure.Authorization;
using IFX.Modules.Transaction.Infrastructure.Persistence;
using IFX.Modules.Transaction.Infrastructure.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace IFX.Modules.Transaction.Infrastructure;

public static class DependencyInjection
{
    public static IServiceCollection AddInfrastructureServices(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        services.AddMemoryCache();

        var connectionString = configuration.GetConnectionString("TransactionDatabase")
            ?? configuration.GetConnectionString("DefaultConnection");
        services.AddDbContext<TransactionDbContext>(options =>
            options.UseSqlServer(connectionString, sql =>
                sql.MigrationsAssembly(typeof(TransactionDbContext).Assembly.FullName)));

        services.AddScoped<ITransactionRepository, EfTransactionRepository>();
        services.AddScoped<IOrderRepository, EfOrderRepository>();
        services.AddScoped<IUnitOfWork, TransactionUnitOfWork>();
        services.AddScoped<ITransactionReader, TransactionReader>();

        services.AddHttpContextAccessor();
        services.AddScoped<IResourceAuthorizationService, ResourceAuthorizationService>();

        services.AddSingleton<IAbacTemplateRegistry>(_ =>
        {
            var registry = new AbacTemplateRegistry();
            BuiltInTemplates.Register(registry);
            return registry;
        });
        services.AddScoped<IAbacPolicyEngine, AbacPolicyEngine>();
        services.AddSingleton<StaticAbacPolicyResolver>();
        services.AddScoped<IAbacPolicyResolver>(sp => sp.GetRequiredService<StaticAbacPolicyResolver>());
        services.AddScoped<IAbacPolicyCache, NoOpAbacPolicyCache>();

        return services;
    }
}
