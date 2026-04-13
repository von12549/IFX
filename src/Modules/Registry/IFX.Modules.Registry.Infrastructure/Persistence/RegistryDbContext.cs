using IFX.BuildingBlocks.Domain;
using IFX.Modules.Registry.Domain.Entities;
using Microsoft.EntityFrameworkCore;

namespace IFX.Modules.Registry.Infrastructure.Persistence;

public class RegistryDbContext : DbContext
{
    public RegistryDbContext(DbContextOptions<RegistryDbContext> options) : base(options)
    {
    }

    public DbSet<Product> Products => Set<Product>();
    public DbSet<Fund> Funds => Set<Fund>();
    public DbSet<FundClass> FundClasses => Set<FundClass>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        // Apply all entity configurations from assembly
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(RegistryDbContext).Assembly);
    }

    public override Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
    {
        // Automatically set CreatedAt/UpdatedAt for auditable entities
        var entries = ChangeTracker.Entries<IAuditableEntity>();

        foreach (var entry in entries)
        {
            if (entry.State == EntityState.Added)
            {
                entry.Entity.CreatedAt = DateTime.UtcNow;
                entry.Entity.UpdatedAt = DateTime.UtcNow;
            }
            else if (entry.State == EntityState.Modified)
            {
                entry.Entity.UpdatedAt = DateTime.UtcNow;
            }
        }

        return base.SaveChangesAsync(cancellationToken);
    }
}
