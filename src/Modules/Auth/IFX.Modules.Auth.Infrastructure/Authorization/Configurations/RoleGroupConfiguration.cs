using IFX.Modules.Auth.Domain.Authorization;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace IFX.Modules.Auth.Infrastructure.Authorization.Configurations;

public class RoleGroupConfiguration : IEntityTypeConfiguration<RoleGroup>
{
    public void Configure(EntityTypeBuilder<RoleGroup> builder)
    {
        builder.ToTable("RoleGroups", ModuleDatabase.Schema);

        builder.HasKey(g => g.Id);

        builder.Property(g => g.Name)
            .IsRequired()
            .HasMaxLength(100);

        builder.Property(g => g.TenantId).IsRequired();

        builder.HasIndex(g => new { g.TenantId, g.Name })
            .HasDatabaseName("IX_RoleGroups_TenantId_Name")
            .IsUnique();

        builder.HasOne(g => g.Tenant)
            .WithMany()
            .HasForeignKey(g => g.TenantId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.Property(g => g.Description)
            .IsRequired()
            .HasMaxLength(255);

        builder.Property(g => g.CreatedBy);
        builder.Property(g => g.CreatedAt).IsRequired();
        builder.Property(g => g.UpdatedAt).IsRequired();

        builder.HasMany(g => g.Roles)
            .WithMany()
            .UsingEntity(j => j.ToTable("RoleGroupRoles", ModuleDatabase.Schema));
    }
}
