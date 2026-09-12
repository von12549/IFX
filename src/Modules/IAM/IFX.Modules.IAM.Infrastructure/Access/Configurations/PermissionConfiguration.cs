using IFX.Modules.IAM.Domain.Access;
using IFX.Modules.IAM.Domain.Tenancy;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace IFX.Modules.IAM.Infrastructure.Access.Configurations;

public class PermissionConfiguration : IEntityTypeConfiguration<Permission>
{
    public void Configure(EntityTypeBuilder<Permission> builder)
    {
        builder.ToTable("Permissions", ModuleDatabase.Schema);

        builder.HasKey(p => p.Id);

        builder.Property(p => p.Name)
            .IsRequired()
            .HasMaxLength(100);

        builder.HasIndex(p => p.Name)
            .HasDatabaseName("IX_Permissions_Name")
            .IsUnique();

        builder.Property(p => p.Description)
            .IsRequired()
            .HasMaxLength(255);

        builder.Property(p => p.CreatedAt).IsRequired();
        builder.Property(p => p.UpdatedAt).IsRequired();
    }
}
