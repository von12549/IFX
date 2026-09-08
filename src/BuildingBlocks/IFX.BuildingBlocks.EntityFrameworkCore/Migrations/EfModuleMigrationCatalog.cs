using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Metadata;
using Microsoft.EntityFrameworkCore.Migrations;

namespace IFX.BuildingBlocks.EntityFrameworkCore.Migrations;

public static class EfModuleMigrationCatalog
{
    public static ModuleMigrationCatalog Create(
        DbContext context,
        string module,
        string schema,
        int order)
    {
        ArgumentNullException.ThrowIfNull(context);

        var assembly = context.GetService<IMigrationsAssembly>();
        var migrations = assembly.Migrations.OrderBy(pair => pair.Key, StringComparer.Ordinal).ToArray();
        var migrationIds = migrations
            .Select(pair => pair.Key)
            .Order(StringComparer.Ordinal)
            .ToArray();
        var tables = context.GetService<IDesignTimeModel>()
            .Model
            .GetEntityTypes()
            .Where(entity => entity.GetTableName() is not null && entity.GetSchema() == schema)
            .Select(entity => entity.GetTableName()!)
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .Order(StringComparer.OrdinalIgnoreCase)
            .ToArray();

        var tablesByMigration = migrations.ToDictionary(
            pair => pair.Key,
            pair => (IReadOnlyList<string>)assembly.CreateMigration(pair.Value, context.Database.ProviderName!)
                .TargetModel
                .GetEntityTypes()
                .Where(entity => entity.GetTableName() is not null && entity.GetSchema() == schema)
                .Select(entity => entity.GetTableName()!)
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .Order(StringComparer.OrdinalIgnoreCase)
                .ToArray(),
            StringComparer.Ordinal);

        return new ModuleMigrationCatalog(module, schema, order, migrationIds, tables, RequiredTablesByMigration: tablesByMigration);
    }
}
