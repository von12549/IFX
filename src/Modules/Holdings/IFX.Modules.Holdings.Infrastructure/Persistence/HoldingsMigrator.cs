using App.Abstractions;
using Microsoft.Extensions.DependencyInjection;

namespace IFX.Modules.Holdings.Infrastructure.Persistence;

public sealed class HoldingsMigrator : IAppMigrator
{
    public string Name => "Holdings";

    public async Task MigrateAsync(IServiceProvider sp, CancellationToken ct = default)
    {
        var context = sp.GetRequiredService<HoldingsDbContext>();
        await context.Database.EnsureCreatedAsync(ct);
    }
}
