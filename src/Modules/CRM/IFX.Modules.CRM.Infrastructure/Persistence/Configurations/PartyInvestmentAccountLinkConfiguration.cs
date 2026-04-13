using IFX.Modules.CRM.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace IFX.Modules.CRM.Infrastructure.Persistence.Configurations;

public class PartyInvestmentAccountLinkConfiguration : IEntityTypeConfiguration<PartyInvestmentAccountLink>
{
    public void Configure(EntityTypeBuilder<PartyInvestmentAccountLink> builder)
    {
        builder.ToTable("PartyInvestmentAccountLinks", "crm");

        builder.HasKey(l => l.Id);

        builder.Property(l => l.TenantId).IsRequired();

        builder.HasOne(l => l.Party)
            .WithMany()
            .HasForeignKey(l => l.PartyId);

        builder.Property(l => l.RelationshipType)
            .IsRequired()
            .HasConversion<int>();

        builder.Property(l => l.OwnershipPercentage)
            .HasPrecision(5, 2);

        builder.Property(l => l.LinkOrder).IsRequired();

        builder.Property(l => l.EffectiveDate).IsRequired();

        builder.Property(l => l.ExpiryDate);

        builder.Property(l => l.CreatedBy);
        builder.Property(l => l.UpdatedBy);
        builder.Property(l => l.CreatedAt).IsRequired();
        builder.Property(l => l.UpdatedAt).IsRequired();

        builder.HasIndex(l => new { l.TenantId, l.InvestmentAccountId, l.PartyId })
            .HasDatabaseName("IX_PartyInvestmentAccountLinks_TenantId_AccountId_PartyId");
    }
}
