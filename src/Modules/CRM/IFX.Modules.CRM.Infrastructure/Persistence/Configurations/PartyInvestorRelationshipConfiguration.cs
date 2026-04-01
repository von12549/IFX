using IFX.Modules.CRM.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace IFX.Modules.CRM.Infrastructure.Persistence.Configurations;

public class PartyInvestorRelationshipConfiguration : IEntityTypeConfiguration<PartyInvestorRelationship>
{
    public void Configure(EntityTypeBuilder<PartyInvestorRelationship> builder)
    {
        builder.ToTable("PartyInvestorRelationships", "crm");

        // Composite PK: (PartyId, InvestorId, RelationshipType)
        builder.HasKey(r => new { r.PartyId, r.InvestorId, r.RelationshipType });

        builder.Property(r => r.PartyId).IsRequired();
        builder.Property(r => r.InvestorId).IsRequired();
        builder.Property(r => r.TenantId).IsRequired();

        builder.Property(r => r.RelationshipType)
            .IsRequired()
            .HasConversion<int>();

        builder.Property(r => r.EffectiveDate).IsRequired();
        builder.Property(r => r.ExpiryDate);

        // No FK constraints to Party/Investor — cross-module boundary
    }
}
