using FluentAssertions;
using IFX.BuildingBlocks.EntityFrameworkCore.Configuration;
using IFX.BuildingBlocks.EntityFrameworkCore.Migrations;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Metadata;
using Microsoft.EntityFrameworkCore.Migrations;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Xunit;
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

namespace IFX.DatabaseBoundary.Tests;

public sealed class ModuleDatabaseBoundaryTests
{
    private const string TestConnection =
        "Server=localhost;Database=BoundaryTest;Integrated Security=true;TrustServerCertificate=true;";

    public static TheoryData<string, Func<DbContext>> ModelCases => new()
    {
        { AuthDatabase.Schema, () => CreateContext<AuthDbContext>() },
        { CrmDatabase.Schema, () => CreateContext<CrmDbContext>() },
        { RegistryDatabase.Schema, () => CreateContext<RegistryDbContext>() },
        { HoldingsDatabase.Schema, () => CreateContext<HoldingsDbContext>() },
        { TransactionDatabase.Schema, () => CreateContext<TransactionDbContext>() }
    };

    public static TheoryData<string, string, int, Func<DbContext>> CatalogCases => new()
    {
        { "Auth", AuthDatabase.Schema, 10, () => CreateContext<AuthDbContext>() },
        { "CRM", CrmDatabase.Schema, 20, () => CreateContext<CrmDbContext>() },
        { "Registry", RegistryDatabase.Schema, 30, () => CreateContext<RegistryDbContext>() },
        { "Holdings", HoldingsDatabase.Schema, 40, () => CreateContext<HoldingsDbContext>() },
        { "Transaction", TransactionDatabase.Schema, 50, () => CreateContext<TransactionDbContext>() }
    };

    public static TheoryData<string, Type, Action<IServiceCollection, IConfiguration>> RegistrationCases => new()
    {
        { AuthDatabase.ConnectionStringName, typeof(AuthDbContext), (services, configuration) => { IFX.Modules.IAM.Infrastructure.DependencyInjection.AddInfrastructureServices(services, configuration); } },
        { CrmDatabase.ConnectionStringName, typeof(CrmDbContext), (services, configuration) => { IFX.Modules.CRM.Infrastructure.DependencyInjection.AddInfrastructureServices(services, configuration); } },
        { RegistryDatabase.ConnectionStringName, typeof(RegistryDbContext), (services, configuration) => { IFX.Modules.Registry.Infrastructure.DependencyInjection.AddInfrastructureServices(services, configuration); } },
        { HoldingsDatabase.ConnectionStringName, typeof(HoldingsDbContext), (services, configuration) => { IFX.Modules.Holdings.Infrastructure.DependencyInjection.AddInfrastructureServices(services, configuration); } },
        { TransactionDatabase.ConnectionStringName, typeof(TransactionDbContext), (services, configuration) => { IFX.Modules.Transaction.Infrastructure.DependencyInjection.AddInfrastructureServices(services, configuration); } }
    };

    public static TheoryData<string, string, Type, Action<IServiceCollection, IConfiguration>> HistoryCases => new()
    {
        { AuthDatabase.Schema, AuthDatabase.ConnectionStringName, typeof(AuthDbContext), (services, configuration) => { IFX.Modules.IAM.Infrastructure.DependencyInjection.AddInfrastructureServices(services, configuration); } },
        { CrmDatabase.Schema, CrmDatabase.ConnectionStringName, typeof(CrmDbContext), (services, configuration) => { IFX.Modules.CRM.Infrastructure.DependencyInjection.AddInfrastructureServices(services, configuration); } },
        { RegistryDatabase.Schema, RegistryDatabase.ConnectionStringName, typeof(RegistryDbContext), (services, configuration) => { IFX.Modules.Registry.Infrastructure.DependencyInjection.AddInfrastructureServices(services, configuration); } },
        { HoldingsDatabase.Schema, HoldingsDatabase.ConnectionStringName, typeof(HoldingsDbContext), (services, configuration) => { IFX.Modules.Holdings.Infrastructure.DependencyInjection.AddInfrastructureServices(services, configuration); } },
        { TransactionDatabase.Schema, TransactionDatabase.ConnectionStringName, typeof(TransactionDbContext), (services, configuration) => { IFX.Modules.Transaction.Infrastructure.DependencyInjection.AddInfrastructureServices(services, configuration); } }
    };

    [Theory]
    [MemberData(nameof(ModelCases))]
    public void Model_is_owned_entirely_by_its_module_schema(
        string expectedSchema,
        Func<DbContext> contextFactory)
    {
        using var context = contextFactory();
        var model = context.GetService<IDesignTimeModel>().Model;

        model.GetDefaultSchema().Should().Be(expectedSchema);
        model.GetEntityTypes()
            .Where(entity => entity.GetTableName() is not null)
            .All(entity => entity.GetSchema() == expectedSchema)
            .Should().BeTrue();
        model.GetEntityTypes()
            .SelectMany(entity => entity.GetForeignKeys())
            .All(foreignKey => foreignKey.PrincipalEntityType.GetSchema() == expectedSchema)
            .Should().BeTrue();
        model.GetSequences()
            .All(sequence => sequence.Schema == expectedSchema)
            .Should().BeTrue();
    }

    [Theory]
    [MemberData(nameof(CatalogCases))]
    public void Bootstrap_catalog_is_generated_from_the_current_ef_assembly_and_model(
        string module,
        string schema,
        int order,
        Func<DbContext> contextFactory)
    {
        using var context = contextFactory();

        var catalog = EfModuleMigrationCatalog.Create(context, module, schema, order);

        catalog.Module.Should().Be(module);
        catalog.Schema.Should().Be(schema);
        catalog.Order.Should().Be(order);
        catalog.MigrationIds.Should().Equal(context.Database.GetMigrations());
        catalog.MigrationIds.Should().NotBeEmpty().And.OnlyHaveUniqueItems();
        catalog.RequiredTables.Should().NotBeEmpty().And.OnlyHaveUniqueItems();
    }

    [Theory]
    [MemberData(nameof(RegistrationCases))]
    public void Registration_requires_the_dedicated_module_connection(
        string connectionName,
        Type _,
        Action<IServiceCollection, IConfiguration> register)
    {
        var configuration = Configuration(new Dictionary<string, string?>
        {
            ["ConnectionStrings:DefaultConnection"] = TestConnection
        });

        var action = () => register(new ServiceCollection(), configuration);

        action.Should().Throw<InvalidOperationException>()
            .WithMessage($"*'{connectionName}'*missing or blank*");
    }

    [Theory]
    [MemberData(nameof(RegistrationCases))]
    public void Registration_uses_only_its_dedicated_connection(
        string connectionName,
        Type contextType,
        Action<IServiceCollection, IConfiguration> register)
    {
        var expected = TestConnection.Replace("BoundaryTest", $"{connectionName}Db", StringComparison.Ordinal);
        var configuration = Configuration(new Dictionary<string, string?>
        {
            [$"ConnectionStrings:{connectionName}"] = expected,
            ["ConnectionStrings:DefaultConnection"] = TestConnection
        });
        var services = new ServiceCollection();

        register(services, configuration);

        using var provider = services.BuildServiceProvider();
        using var context = (DbContext)provider.GetRequiredService(contextType);
        context.Database.GetConnectionString().Should().Be(expected);
    }

    [Theory]
    [MemberData(nameof(HistoryCases))]
    public void Registration_uses_a_history_table_in_the_module_schema(
        string schema,
        string connectionName,
        Type contextType,
        Action<IServiceCollection, IConfiguration> register)
    {
        var configuration = Configuration(new Dictionary<string, string?>
        {
            [$"ConnectionStrings:{connectionName}"] = TestConnection
        });
        var services = new ServiceCollection();
        register(services, configuration);

        using var provider = services.BuildServiceProvider();
        using var context = (DbContext)provider.GetRequiredService(contextType);
        var createScript = context.GetService<IHistoryRepository>().GetCreateScript();

        createScript.Should().Contain($"[{schema}].[__EFMigrationsHistory]");
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    public void Required_connection_rejects_missing_or_blank_values(string? value)
    {
        var configuration = Configuration(new Dictionary<string, string?>
        {
            ["ConnectionStrings:Module"] = value
        });

        var action = () => RequiredConnectionString.Get(configuration, "Module");

        action.Should().Throw<InvalidOperationException>()
            .WithMessage("*'Module'*missing or blank*");
    }

    [Fact]
    public void Invalid_connection_error_never_echoes_the_connection_or_secret()
    {
        const string invalid = "Server=localhost;Password=phase-one-secret;Broken";
        var configuration = Configuration(new Dictionary<string, string?>
        {
            ["ConnectionStrings:Module"] = invalid
        });

        var action = () => RequiredConnectionString.Get(configuration, "Module");

        var exception = action.Should().Throw<InvalidOperationException>().Which;
        exception.Message.Should().Be("Required connection string 'Module' is invalid.");
        exception.ToString().Should().NotContain("phase-one-secret");
    }

    [Fact]
    public void Module_schema_and_connection_names_are_unique()
    {
        new[]
        {
            AuthDatabase.Schema,
            CrmDatabase.Schema,
            RegistryDatabase.Schema,
            HoldingsDatabase.Schema,
            TransactionDatabase.Schema
        }.Should().OnlyHaveUniqueItems();

        new[]
        {
            AuthDatabase.ConnectionStringName,
            CrmDatabase.ConnectionStringName,
            RegistryDatabase.ConnectionStringName,
            HoldingsDatabase.ConnectionStringName,
            TransactionDatabase.ConnectionStringName
        }.Should().OnlyHaveUniqueItems();
    }

    private static TContext CreateContext<TContext>() where TContext : DbContext
    {
        var options = new DbContextOptionsBuilder<TContext>()
            .UseSqlServer(TestConnection)
            .Options;
        return (TContext)Activator.CreateInstance(typeof(TContext), options)!;
    }

    private static IConfiguration Configuration(Dictionary<string, string?> values) =>
        new ConfigurationBuilder().AddInMemoryCollection(values).Build();
}
