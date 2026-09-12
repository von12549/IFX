using IFX.Modules.IAM.Domain.Users;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
namespace IFX.Modules.IAM.Infrastructure.Access.Configurations;
public sealed class UserAssignmentsConfiguration : IEntityTypeConfiguration<User>
{
    public void Configure(EntityTypeBuilder<User> builder)
    {
        // Many-to-many: User ↔ Role
        builder.HasMany(u => u.Roles)
            .WithMany()
            .UsingEntity(j => j.ToTable("UserRoles", ModuleDatabase.Schema));

        // Many-to-many: User ↔ RoleGroup
        builder.HasMany(u => u.RoleGroups)
            .WithMany()
            .UsingEntity(j => j.ToTable("UserRoleGroups", ModuleDatabase.Schema));

    }
}
