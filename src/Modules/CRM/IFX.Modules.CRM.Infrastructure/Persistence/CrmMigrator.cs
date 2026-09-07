using App.Abstractions;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Serilog;

namespace IFX.Modules.CRM.Infrastructure.Persistence;

public sealed class CrmMigrator : IAppMigrator
{
    public string Name => "CRM";
    public async Task MigrateAsync(IServiceProvider sp, CancellationToken ct = default)
    {
        Log.Information("[{Module}] Starting database migration...", Name);
        var db = sp.GetRequiredService<CrmDbContext>();
        var pending = await db.Database.GetPendingMigrationsAsync(ct);
        var count = pending.Count();
        if (count > 0)
            Log.Information("[{Module}] Applying {Count} pending migration(s)...", Name, count);
        else
            Log.Information("[{Module}] No pending migrations.", Name);
        await db.Database.MigrateAsync(ct);
        Log.Information("[{Module}] Migration completed.", Name);
    }
}
