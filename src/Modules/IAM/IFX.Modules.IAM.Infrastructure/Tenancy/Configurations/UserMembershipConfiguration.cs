using IFX.Modules.IAM.Domain.Users;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
namespace IFX.Modules.IAM.Infrastructure.Tenancy.Configurations;
public sealed class UserMembershipConfiguration : IEntityTypeConfiguration<User>
{
    public void Configure(EntityTypeBuilder<User> builder)
    {
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

    }
}
