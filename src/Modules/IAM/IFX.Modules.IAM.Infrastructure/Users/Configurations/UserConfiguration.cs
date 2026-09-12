using IFX.Modules.IAM.Domain.Users;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace IFX.Modules.IAM.Infrastructure.Users.Configurations;

public class UserConfiguration : IEntityTypeConfiguration<User>
{
    public void Configure(EntityTypeBuilder<User> builder)
    {
        builder.ToTable("Users", ModuleDatabase.Schema);

        builder.HasKey(u => u.Id);

        builder.Property(u => u.IsActive).IsRequired();

        builder.Property(u => u.DisplayName)
            .IsRequired()
            .HasMaxLength(200);

        builder.Property(u => u.CreatedBy);
        builder.Property(u => u.CreatedAt).IsRequired();
        builder.Property(u => u.UpdatedAt).IsRequired();

        // Many-to-many: User ↔ Role
        builder.HasMany(u => u.Roles)
            .WithMany()
            .UsingEntity(j => j.ToTable("UserRoles", ModuleDatabase.Schema));

        // Many-to-many: User ↔ RoleGroup
        builder.HasMany(u => u.RoleGroups)
            .WithMany()
            .UsingEntity(j => j.ToTable("UserRoleGroups", ModuleDatabase.Schema));

        // Many-to-many: User ↔ Tenant
        builder.HasMany(u => u.Tenants)
            .WithMany()
            .UsingEntity(j => j.ToTable("UserTenants", ModuleDatabase.Schema));

        // Many-to-many: User ↔ Department
        builder.HasMany(u => u.Departments)
            .WithMany()
            .UsingEntity(j => j.ToTable("UserDepartments", ModuleDatabase.Schema));

        // Primary tenant (nullable FK)
        builder.Property(u => u.PrimaryTenantId);

        builder.HasOne<IFX.Modules.IAM.Domain.Tenancy.Tenant>()
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
