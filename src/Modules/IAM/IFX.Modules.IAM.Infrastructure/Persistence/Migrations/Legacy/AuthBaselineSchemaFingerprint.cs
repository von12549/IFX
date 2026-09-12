using IFX.BuildingBlocks.EntityFrameworkCore.Migrations;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

namespace IFX.Modules.IAM.Infrastructure.Persistence.Migrations.Legacy;

public static class AuthBaselineSchemaFingerprint
{
    public static SchemaFingerprint Create(IfxDbContext context)
    {
        ArgumentNullException.ThrowIfNull(context);
        var assembly = context.GetService<IMigrationsAssembly>();
        if (!assembly.Migrations.TryGetValue(
                AuthLegacyMigrationManifest.CanonicalInitialCreateId,
                out var migrationType))
        {
            throw new HistoryBootstrapException("Auth canonical InitialCreate migration is missing.");
        }

        var migration = assembly.CreateMigration(migrationType, context.Database.ProviderName!);
        return SchemaFingerprintBuilder.FromModel(migration.TargetModel, ModuleDatabase.Schema);
    }
}
