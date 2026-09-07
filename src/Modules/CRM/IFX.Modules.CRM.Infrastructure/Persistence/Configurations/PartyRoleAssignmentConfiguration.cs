using IFX.Modules.CRM.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace IFX.Modules.CRM.Infrastructure.Persistence.Configurations;

public class PartyRoleAssignmentConfiguration : IEntityTypeConfiguration<PartyRoleAssignment>
{
    public void Configure(EntityTypeBuilder<PartyRoleAssignment> builder)
    {
        builder.ToTable("PartyRoleAssignments", ModuleDatabase.Schema);

        builder.HasKey(r => r.Id);

        builder.Property(r => r.TenantId).IsRequired();

        builder.Property(r => r.PartyId).IsRequired();

        builder.Property(r => r.Role)
            .IsRequired()
            .HasConversion<int>();

        builder.Property(r => r.AssignedAt).IsRequired();

        builder.Property(r => r.AssignedBy).IsRequired();

        builder.Property(r => r.CreatedBy);
        builder.Property(r => r.UpdatedBy);
        builder.Property(r => r.CreatedAt).IsRequired();
        builder.Property(r => r.UpdatedAt).IsRequired();

        builder.HasIndex(r => new { r.TenantId, r.PartyId, r.Role })
            .HasDatabaseName("IX_PartyRoleAssignments_TenantId_PartyId_Role")
            .IsUnique();
    }
}
