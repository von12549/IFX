using IFX.Modules.Auth.Domain.Authorization;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace IFX.Modules.Auth.Infrastructure.Authorization.Configurations;

public class RoleConfiguration : IEntityTypeConfiguration<Role>
{
    public void Configure(EntityTypeBuilder<Role> builder)
    {
        builder.ToTable("Roles", "auth");

        builder.HasKey(r => r.Id);

        builder.Property(r => r.Name)
            .IsRequired()
            .HasMaxLength(50);

        builder.HasIndex(r => r.Name)
            .HasDatabaseName("IX_Roles_Name")
            .IsUnique();

        builder.Property(r => r.Description)
            .IsRequired()
            .HasMaxLength(255);

        builder.Property(r => r.CreatedAt).IsRequired();
        builder.Property(r => r.UpdatedAt).IsRequired();

        builder.HasMany(r => r.Permissions)
            .WithMany()
            .UsingEntity(j => j.ToTable("RolePermissions", "auth"));
    }
}
