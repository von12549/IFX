using App.Abstractions;
using IFX.Modules.Auth.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Serilog;

namespace IFX.Modules.Auth.Composition
{
    public sealed class AuthMigrator : IAppMigrator
    {
        public string Name => "Auth";

        public async Task MigrateAsync(IServiceProvider sp, CancellationToken ct = default)
        {
            Log.Information("[{Module}] Starting database migration...", Name);

            var db = sp.GetRequiredService<AuthDbContext>();
            var pendingMigrations = await db.Database.GetPendingMigrationsAsync(ct);
            var pendingCount = pendingMigrations.Count();

            if (pendingCount > 0)
            {
                Log.Information("[{Module}] Applying {Count} pending migration(s)...", Name, pendingCount);
                foreach (var migration in pendingMigrations)
                {
                    Log.Debug("[{Module}] Pending migration: {Migration}", Name, migration);
                }
            }
            else
            {
                Log.Information("[{Module}] No pending migrations", Name);
            }

            await db.Database.MigrateAsync(ct);

            Log.Information("[{Module}] Database migration completed successfully", Name);
        }
    }
}
