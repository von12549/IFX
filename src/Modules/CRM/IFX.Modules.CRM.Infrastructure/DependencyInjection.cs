using IFX.BuildingBlocks.Security.Authorization;
using IFX.BuildingBlocks.Security.Authorization.Abac.Engine;
using IFX.BuildingBlocks.Application.Transactions;
using IFX.BuildingBlocks.Security.Authorization.Abac.Registry;
using IFX.BuildingBlocks.Security.Authorization.Abac.Resolver;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.Modules.CRM.Abstractions.Interfaces;
using IFX.Modules.CRM.Application.Interfaces;
using IFX.Modules.CRM.Application.Transactions;
using IFX.Modules.CRM.Domain.Repositories;
using IFX.Modules.CRM.Infrastructure.Authorization;
using IFX.Modules.CRM.Infrastructure.Persistence;
using IFX.Modules.CRM.Infrastructure.Repositories;
using IFX.Modules.CRM.Infrastructure.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace IFX.Modules.CRM.Infrastructure;

public static class DependencyInjection
{
    public static IServiceCollection AddInfrastructureServices(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        services.AddMemoryCache();

        var connectionString = configuration.GetConnectionString("CrmDatabase")
            ?? configuration.GetConnectionString("DefaultConnection");
        services.AddDbContext<CrmDbContext>(options =>
        {
            options.UseSqlServer(connectionString, sqlOptions =>
            {
                sqlOptions.MigrationsAssembly(typeof(CrmDbContext).Assembly.FullName);
            });
        });

        // Repositories
        services.AddScoped<IPartyRepository, EfPartyRepository>();
        services.AddScoped<IInvestorRepository, EfInvestorRepository>();
        services.AddScoped<IPartyRoleAssignmentRepository, EfPartyRoleAssignmentRepository>();
        services.AddScoped<IInvestmentAccountRepository, EfInvestmentAccountRepository>();
        services.AddScoped<IPartyInvestmentAccountLinkRepository, EfPartyInvestmentAccountLinkRepository>();
        services.AddScoped<IPartyRelationshipRepository, EfPartyRelationshipRepository>();
        services.AddScoped<IAdvisorInvestmentAccountLinkRepository, EfAdvisorInvestmentAccountLinkRepository>();
        services.AddScoped<IInvestorDocumentRepository, EfInvestorDocumentRepository>();
        services.AddScoped<IUserPartyLinkRepository, EfUserPartyLinkRepository>();
        services.AddScoped<IIndividualInvestorProfileRepository, EfIndividualInvestorProfileRepository>();
        services.AddScoped<ICorporateInvestorProfileRepository, EfCorporateInvestorProfileRepository>();
        services.AddScoped<ITrustInvestorProfileRepository, EfTrustInvestorProfileRepository>();

        // Unit of Work
        services.AddScoped<IUnitOfWork, CrmUnitOfWork>();
        services.AddKeyedScoped<ITransactionExecutor, CrmTransactionExecutor>(typeof(CrmTransactionOwner));

        // CrmReader (cross-module read service)
        services.AddScoped<ICrmReader, CrmReader>();

        // Authorization
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
