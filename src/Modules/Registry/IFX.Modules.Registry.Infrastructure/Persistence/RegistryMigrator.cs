using App.Abstractions;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Serilog;

namespace IFX.Modules.Registry.Infrastructure.Persistence;

public sealed class RegistryMigrator : IAppMigrator
{
    public string Name => "Registry";
    private const string InitialCreateId = "20260413120300_InitialCreate";
    private const string EfProductVersion = "8.0.0";

    public async Task MigrateAsync(IServiceProvider sp, CancellationToken ct = default)
    {
        Log.Information("[{Module}] Starting database migration...", Name);
        var db = sp.GetRequiredService<RegistryDbContext>();
        await StampIfEnsureCreatedDatabaseAsync(db, ct);
        var pending = await db.Database.GetPendingMigrationsAsync(ct);
        var count = pending.Count();
        if (count > 0)
            Log.Information("[{Module}] Applying {Count} pending migration(s)...", Name, count);
        else
            Log.Information("[{Module}] No pending migrations.", Name);
        await db.Database.MigrateAsync(ct);
        Log.Information("[{Module}] Migration completed.", Name);
    }

    private async Task StampIfEnsureCreatedDatabaseAsync(RegistryDbContext db, CancellationToken ct)
    {
        var applied = (await db.Database.GetAppliedMigrationsAsync(ct)).ToHashSet();
        if (applied.Contains(InitialCreateId)) return;
        var exists = (await db.Database.SqlQueryRaw<int>(
            "SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES " +
            "WHERE TABLE_SCHEMA = 'registry' AND TABLE_NAME = 'Funds'").ToListAsync(ct)).FirstOrDefault() > 0;
        if (!exists) return;
        Log.Warning("[{Module}] Detected EnsureCreatedAsync database. Stamping '{Id}'...", Name, InitialCreateId);
        await db.Database.ExecuteSqlRawAsync(
            "INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion]) VALUES ({0}, {1})",
            [InitialCreateId, EfProductVersion], ct);
        Log.Information("[{Module}] Stamp complete.", Name);
    }
}
