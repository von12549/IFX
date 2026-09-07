using IFX.BuildingBlocks.Domain;
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
        modelBuilder.HasDefaultSchema(ModuleDatabase.Schema);
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(HoldingsDbContext).Assembly);
    }

    public override Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
    {
        var entries = ChangeTracker.Entries<IAuditableEntity>();
        foreach (var entry in entries)
        {
            if (entry.State == EntityState.Added) { entry.Entity.CreatedAt = DateTimeOffset.UtcNow; entry.Entity.UpdatedAt = DateTimeOffset.UtcNow; }
            else if (entry.State == EntityState.Modified) { entry.Entity.UpdatedAt = DateTimeOffset.UtcNow; }
        }
        return base.SaveChangesAsync(cancellationToken);
    }
}
