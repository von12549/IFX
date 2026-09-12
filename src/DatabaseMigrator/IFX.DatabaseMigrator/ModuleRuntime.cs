using IFX.BuildingBlocks.EntityFrameworkCore.Migrations;
using IFX.Modules.IAM.Infrastructure.Persistence.Migrations.Legacy;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using AuthDatabase = IFX.Modules.IAM.Infrastructure.ModuleDatabase;
using AuthDbContext = IFX.Modules.IAM.Infrastructure.Persistence.IfxDbContext;
using CrmDatabase = IFX.Modules.CRM.Infrastructure.ModuleDatabase;
using CrmDbContext = IFX.Modules.CRM.Infrastructure.Persistence.CrmDbContext;
using HoldingsDatabase = IFX.Modules.Holdings.Infrastructure.ModuleDatabase;
using HoldingsDbContext = IFX.Modules.Holdings.Infrastructure.Persistence.HoldingsDbContext;
using RegistryDatabase = IFX.Modules.Registry.Infrastructure.ModuleDatabase;
using RegistryDbContext = IFX.Modules.Registry.Infrastructure.Persistence.RegistryDbContext;
using TransactionDatabase = IFX.Modules.Transaction.Infrastructure.ModuleDatabase;
using TransactionDbContext = IFX.Modules.Transaction.Infrastructure.Persistence.TransactionDbContext;

namespace IFX.DatabaseMigrator;

public sealed record ModuleRuntime(
    string ModuleName,
    string Schema,
    string HistoryTable,
    string ConnectionKey,
    int Order,
    Type DbContextType,
    Func<string, DbContext> CreateContext)
{
    public static IReadOnlyList<ModuleRuntime> All { get; } =
    [
        Create<AuthDbContext>("Auth", AuthDatabase.Schema, AuthDatabase.HistoryTable, AuthDatabase.ConnectionStringName, 10),
        Create<CrmDbContext>("CRM", CrmDatabase.Schema, CrmDatabase.HistoryTable, CrmDatabase.ConnectionStringName, 20),
        Create<RegistryDbContext>("Registry", RegistryDatabase.Schema, RegistryDatabase.HistoryTable, RegistryDatabase.ConnectionStringName, 30),
        Create<HoldingsDbContext>("Holdings", HoldingsDatabase.Schema, HoldingsDatabase.HistoryTable, HoldingsDatabase.ConnectionStringName, 40),
        Create<TransactionDbContext>("Transaction", TransactionDatabase.Schema, TransactionDatabase.HistoryTable, TransactionDatabase.ConnectionStringName, 50)
    ];

    public ModuleMigrationCatalog CreateCatalog(DbContext context)
    {
        var catalog = EfModuleMigrationCatalog.Create(context, ModuleName, Schema, Order);
        return ModuleName == "Auth"
            ? catalog with { LegacyMigrationIds = AuthLegacyMigrationManifest.AllLegacyIds }
            : catalog;
    }

    public IReadOnlyList<MigrationHistoryRow> CurrentMigrationRows(DbContext context)
    {
        var assembly = context.GetService<IMigrationsAssembly>();
        return assembly.Migrations
            .OrderBy(pair => pair.Key, StringComparer.Ordinal)
            .Select(pair => new MigrationHistoryRow(
                pair.Key,
                assembly.CreateMigration(pair.Value, context.Database.ProviderName!)
                    .TargetModel.GetProductVersion() ?? "<missing>"))
            .ToArray();
    }

    private static ModuleRuntime Create<TContext>(
        string module,
        string schema,
        string historyTable,
        string connectionKey,
        int order)
        where TContext : DbContext
    {
        return new ModuleRuntime(
            module,
            schema,
            historyTable,
            connectionKey,
            order,
            typeof(TContext),
            connectionString =>
            {
                var options = new DbContextOptionsBuilder<TContext>()
                    .UseSqlServer(connectionString, sql =>
                    {
                        sql.MigrationsAssembly(typeof(TContext).Assembly.FullName);
                        sql.MigrationsHistoryTable(historyTable, schema);
                    })
                    .Options;
                return (TContext)Activator.CreateInstance(typeof(TContext), options)!;
            });
    }
}
