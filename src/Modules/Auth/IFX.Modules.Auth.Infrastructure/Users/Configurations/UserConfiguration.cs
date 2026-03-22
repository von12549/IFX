using IFX.Modules.Auth.Domain.Users;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace IFX.Modules.Auth.Infrastructure.Users.Configurations;

public class UserConfiguration : IEntityTypeConfiguration<User>
{
    public void Configure(EntityTypeBuilder<User> builder)
    {
        builder.ToTable("Users", "auth");

        builder.HasKey(u => u.Id);

        builder.Property(u => u.IsActive).IsRequired();

        builder.Property(u => u.DisplayName)
            .IsRequired()
            .HasMaxLength(200);

        builder.Property(u => u.CreatedAt).IsRequired();
        builder.Property(u => u.UpdatedAt).IsRequired();

        // Many-to-many: User ↔ Role
        builder.HasMany(u => u.Roles)
            .WithMany()
            .UsingEntity(j => j.ToTable("UserRoles", "auth"));

        // Many-to-many: User ↔ RoleGroup
        builder.HasMany(u => u.RoleGroups)
            .WithMany()
            .UsingEntity(j => j.ToTable("UserRoleGroups", "auth"));

        // Many-to-many: User ↔ Tenant
        builder.HasMany(u => u.Tenants)
            .WithMany()
            .UsingEntity(j => j.ToTable("UserTenants", "auth"));

        // Many-to-many: User ↔ Department
        builder.HasMany(u => u.Departments)
            .WithMany()
            .UsingEntity(j => j.ToTable("UserDepartments", "auth"));

        // Primary tenant (nullable FK)
        builder.Property(u => u.PrimaryTenantId);

        builder.HasOne<IFX.Modules.Auth.Domain.Authorization.Tenant>()
            .WithMany()
            .HasForeignKey(u => u.PrimaryTenantId)
            .IsRequired(false)
            .OnDelete(DeleteBehavior.SetNull);

        // Identities (inverse of UserIdentity.User)
        builder.HasMany(u => u.Identities)
            .WithOne(ui => ui.User)
            .HasForeignKey(ui => ui.UserId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.Ignore(u => u.LoginEvents);
    }
}
