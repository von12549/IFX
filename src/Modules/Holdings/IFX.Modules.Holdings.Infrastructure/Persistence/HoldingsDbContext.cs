using IFX.Modules.Holdings.Domain.Common;
using IFX.Modules.Holdings.Domain.Entities;
using Microsoft.EntityFrameworkCore;

namespace IFX.Modules.Holdings.Infrastructure.Persistence;

public class HoldingsDbContext : DbContext
{
    public HoldingsDbContext(DbContextOptions<HoldingsDbContext> options) : base(options) { }

    public DbSet<Holding> Holdings => Set<Holding>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(HoldingsDbContext).Assembly);
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
