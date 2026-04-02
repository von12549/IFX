using App.Abstractions;
using Microsoft.Extensions.DependencyInjection;

namespace IFX.Modules.Transaction.Infrastructure.Persistence;

public sealed class TransactionMigrator : IAppMigrator
{
    public string Name => "Transaction";

    public async Task MigrateAsync(IServiceProvider sp, CancellationToken ct = default)
    {
        var context = sp.GetRequiredService<TransactionDbContext>();
        await context.Database.EnsureCreatedAsync(ct);
    }
}
