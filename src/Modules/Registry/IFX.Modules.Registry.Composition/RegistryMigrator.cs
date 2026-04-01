using App.Abstractions;
using IFX.Modules.Registry.Infrastructure.Persistence;
using Microsoft.Extensions.DependencyInjection;
using Serilog;

namespace IFX.Modules.Registry.Composition;

public sealed class RegistryMigrator : IAppMigrator
{
    public string Name => "Registry";

    public async Task MigrateAsync(IServiceProvider sp, CancellationToken ct = default)
    {
        Log.Information("[{Module}] Starting database migration...", Name);

        var context = sp.GetRequiredService<RegistryDbContext>();
        await context.Database.EnsureCreatedAsync(ct);

        Log.Information("[{Module}] Database migration completed successfully", Name);
    }
}
