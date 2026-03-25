using IFX.Modules.Auth.Domain.Authorization;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace IFX.Modules.Auth.Infrastructure.Authorization.Configurations;

public class PolicyDefinitionConfiguration : IEntityTypeConfiguration<PolicyDefinition>
{
    public void Configure(EntityTypeBuilder<PolicyDefinition> builder)
    {
        builder.ToTable("PolicyDefinitions", "auth");

        builder.HasKey(p => p.Id);

        builder.Property(p => p.Scope)
            .HasConversion<int>()
            .IsRequired();

        builder.Property(p => p.TenantId); // nullable — null for Platform-scoped policies

        builder.Property(p => p.Name)
            .HasMaxLength(200)
            .IsRequired();

        builder.Property(p => p.Description)
            .HasMaxLength(500);

        builder.Property(p => p.ResourceType)
            .HasMaxLength(100)
            .IsRequired();

        builder.Property(p => p.Action)
            .HasMaxLength(100)
            .IsRequired();

        builder.Property(p => p.ConditionsJson)
            .HasColumnType("nvarchar(max)")
            .IsRequired();

        builder.Property(p => p.IsActive).IsRequired();
        builder.Property(p => p.CreatedAt).IsRequired();
        builder.Property(p => p.UpdatedAt).IsRequired();
        builder.Property(p => p.CreatedById);
        builder.Property(p => p.UpdatedById);

        builder.HasIndex(p => new { p.Scope, p.TenantId, p.ResourceType, p.Action })
            .IsUnique()
            .HasDatabaseName("UX_PolicyDefinitions_Scope_Tenant_Resource_Action");

        builder.HasIndex(p => p.TenantId)
            .HasDatabaseName("IX_PolicyDefinitions_TenantId");
    }
}
