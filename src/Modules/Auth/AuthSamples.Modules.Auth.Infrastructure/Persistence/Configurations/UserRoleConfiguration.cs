using AuthSamples.Modules.Auth.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace AuthSamples.Modules.Auth.Infrastructure.Persistence.Configurations;

public class UserRoleConfiguration : IEntityTypeConfiguration<UserRole>
{
    public void Configure(EntityTypeBuilder<UserRole> builder)
    {
        builder.ToTable("UserRoles", "auth");

        builder.HasKey(r => r.Id);

        builder.Property(r => r.RoleName)
            .IsRequired()
            .HasMaxLength(50);

        builder.HasIndex(r => r.RoleName)
            .HasDatabaseName("IX_UserRoles_RoleName")
            .IsUnique();

        builder.Property(r => r.Description)
            .IsRequired()
            .HasMaxLength(255);

        builder.Property(r => r.CreatedAt)
            .IsRequired();

        builder.Property(r => r.UpdatedAt)
            .IsRequired();
    }
}
