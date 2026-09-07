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

        var migrationIds = context.GetService<IMigrationsAssembly>()
            .Migrations
            .Keys
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

        return new ModuleMigrationCatalog(module, schema, order, migrationIds, tables);
    }
}
