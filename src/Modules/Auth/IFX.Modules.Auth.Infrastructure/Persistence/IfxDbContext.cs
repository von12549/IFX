using IFX.Modules.Auth.Domain.Authorization;
using IFX.Modules.Auth.Domain.Common;
using IFX.Modules.Auth.Domain.Identity;
using IFX.Modules.Auth.Domain.Users;
using Microsoft.EntityFrameworkCore;

namespace IFX.Modules.Auth.Infrastructure.Persistence;

public class IfxDbContext : DbContext
{
    public IfxDbContext(DbContextOptions<IfxDbContext> options) : base(options)
    {
    }

    public DbSet<User> Users => Set<User>();
    public DbSet<UserIdentity> UserIdentities => Set<UserIdentity>();
    public DbSet<Role> Roles => Set<Role>();
    public DbSet<Permission> Permissions => Set<Permission>();
    public DbSet<RoleGroup> RoleGroups => Set<RoleGroup>();
    public DbSet<Tenant> Tenants => Set<Tenant>();
    public DbSet<Department> Departments => Set<Department>();
    public DbSet<LoginEvent> LoginEvents => Set<LoginEvent>();
    public DbSet<LogoutEvent> LogoutEvents => Set<LogoutEvent>();
    public DbSet<RegistrationFlowEvent> RegistrationFlowEvents => Set<RegistrationFlowEvent>();
    public DbSet<UserActivityLog> UserActivityLogs => Set<UserActivityLog>();
    public DbSet<Idp> Idps => Set<Idp>();
    public DbSet<EmailVerificationToken> EmailVerificationTokens => Set<EmailVerificationToken>();
    public DbSet<PolicyDefinition> PolicyDefinitions => Set<PolicyDefinition>();
    public DbSet<GlobalRole> GlobalRoles => Set<GlobalRole>();
    public DbSet<UserGlobalRole> UserGlobalRoles => Set<UserGlobalRole>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);
        modelBuilder.HasDefaultSchema(ModuleDatabase.Schema);

        // Apply all entity configurations from assembly
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(IfxDbContext).Assembly);
    }

    public override Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
    {
        // Automatically set CreatedAt/UpdatedAt for auditable entities
        var entries = ChangeTracker.Entries<IAuditableEntity>();

        foreach (var entry in entries)
        {
            if (entry.State == EntityState.Added)
            {
                entry.Entity.CreatedAt = DateTimeOffset.UtcNow;
                entry.Entity.UpdatedAt = DateTimeOffset.UtcNow;
            }
            else if (entry.State == EntityState.Modified)
            {
                entry.Entity.UpdatedAt = DateTimeOffset.UtcNow;
            }
        }

        return base.SaveChangesAsync(cancellationToken);
    }
}
