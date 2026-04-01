using App.Abstractions;
using Microsoft.Extensions.DependencyInjection;

namespace IFX.Modules.CRM.Infrastructure.Persistence;

public sealed class CrmMigrator : IAppMigrator
{
    public string Name => "CRM";

    public async Task MigrateAsync(IServiceProvider sp, CancellationToken ct = default)
    {
        var context = sp.GetRequiredService<CrmDbContext>();
        await context.Database.EnsureCreatedAsync(ct);
    }
}
