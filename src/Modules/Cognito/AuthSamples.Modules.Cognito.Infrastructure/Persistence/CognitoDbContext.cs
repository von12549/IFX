using AuthSamples.Modules.Cognito.Domain.Common;
using AuthSamples.Modules.Cognito.Domain.Entities;
using Microsoft.EntityFrameworkCore;

namespace AuthSamples.Modules.Cognito.Infrastructure.Persistence;

public class CognitoDbContext : DbContext
{
    public CognitoDbContext(DbContextOptions<CognitoDbContext> options) : base(options)
    {
    }

    public DbSet<User> Users => Set<User>();
    public DbSet<LoginEvent> LoginEvents => Set<LoginEvent>();
    public DbSet<LogoutEvent> LogoutEvents => Set<LogoutEvent>();
    public DbSet<RegistrationFlowEvent> RegistrationFlowEvents => Set<RegistrationFlowEvent>();
    public DbSet<UserActivityLog> UserActivityLogs => Set<UserActivityLog>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        // Apply all entity configurations from assembly
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(CognitoDbContext).Assembly);
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
