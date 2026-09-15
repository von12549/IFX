using IFX.Modules.CRM.Application.Ports.Authorization;
using IFX.BuildingBlocks.Security.Authorization;
using IFX.BuildingBlocks.Application.Transactions;
using IFX.Modules.CRM.Application.Interfaces;
using IFX.Modules.CRM.Application.Ports;
using IFX.Modules.CRM.Application.Transactions;
using IFX.Modules.CRM.Domain.Repositories;
using IFX.Modules.CRM.Infrastructure.Persistence;
using IFX.Modules.CRM.Infrastructure.Repositories;
using IFX.Modules.CRM.Infrastructure.Integrations.Outbound.IAM;
using IFX.Modules.CRM.Infrastructure.Integrations.Outbound.Persistence;
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

        var connectionString = IFX.BuildingBlocks.EntityFrameworkCore.Configuration.RequiredConnectionString.Get(
            configuration,
            ModuleDatabase.ConnectionStringName);
        services.AddDbContext<CrmDbContext>(options =>
        {
            options.UseSqlServer(connectionString, sqlOptions =>
            {
                sqlOptions.MigrationsAssembly(typeof(CrmDbContext).Assembly.FullName);
                sqlOptions.MigrationsHistoryTable(ModuleDatabase.HistoryTable, ModuleDatabase.Schema);
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

        services.AddScoped<IAccountComplianceDataPort, AccountComplianceDataAdapter>();

        // Authorization
        services.AddHttpContextAccessor();
        services.AddScoped<IResourceAuthorizationService, ResourceAuthorizationAdapter>();
        return services;
    }
}
