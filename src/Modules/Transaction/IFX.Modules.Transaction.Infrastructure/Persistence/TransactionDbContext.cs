using IFX.BuildingBlocks.Domain;
using Microsoft.EntityFrameworkCore;
using TxEntity = IFX.Modules.Transaction.Domain.Entities.Transaction;

namespace IFX.Modules.Transaction.Infrastructure.Persistence;

public class TransactionDbContext : DbContext
{
    public TransactionDbContext(DbContextOptions<TransactionDbContext> options) : base(options) { }

    public DbSet<TxEntity> Transactions => Set<TxEntity>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(TransactionDbContext).Assembly);
    }

    public override Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
    {
        var entries = ChangeTracker.Entries<IAuditableEntity>();
        foreach (var entry in entries)
        {
            if (entry.State == EntityState.Added) { entry.Entity.CreatedAt = DateTime.UtcNow; entry.Entity.UpdatedAt = DateTime.UtcNow; }
            else if (entry.State == EntityState.Modified) { entry.Entity.UpdatedAt = DateTime.UtcNow; }
        }
        return base.SaveChangesAsync(cancellationToken);
    }
}
