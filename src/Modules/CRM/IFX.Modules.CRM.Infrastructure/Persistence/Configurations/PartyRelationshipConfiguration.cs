using IFX.Modules.CRM.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace IFX.Modules.CRM.Infrastructure.Persistence.Configurations;

public class PartyRelationshipConfiguration : IEntityTypeConfiguration<PartyRelationship>
{
    public void Configure(EntityTypeBuilder<PartyRelationship> builder)
    {
        builder.ToTable("PartyRelationships", "crm");

        builder.HasKey(r => r.Id);

        builder.Property(r => r.TenantId).IsRequired();

        // Cross-module value references — no FK constraints
        builder.Property(r => r.FromPartyId).IsRequired();
        builder.Property(r => r.ToPartyId).IsRequired();

        builder.Property(r => r.RelationshipType)
            .IsRequired()
            .HasConversion<int>();

        builder.Property(r => r.EffectiveDate).IsRequired();
        builder.Property(r => r.ExpiryDate);

        builder.Property(r => r.CreatedBy);
        builder.Property(r => r.UpdatedBy);
        builder.Property(r => r.CreatedAt).IsRequired();
        builder.Property(r => r.UpdatedAt).IsRequired();

        builder.HasIndex(r => new { r.TenantId, r.FromPartyId, r.RelationshipType })
            .HasDatabaseName("IX_PartyRelationships_TenantId_FromPartyId_Type");
    }
}
