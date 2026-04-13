using IFX.Modules.CRM.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace IFX.Modules.CRM.Infrastructure.Persistence.Configurations;

public class AdvisorInvestmentAccountLinkConfiguration : IEntityTypeConfiguration<AdvisorInvestmentAccountLink>
{
    public void Configure(EntityTypeBuilder<AdvisorInvestmentAccountLink> builder)
    {
        builder.ToTable("AdvisorInvestmentAccountLinks", "crm");

        builder.HasKey(l => l.Id);

        builder.Property(l => l.TenantId).IsRequired();

        builder.HasOne(l => l.AdvisorParty)
            .WithMany()
            .HasForeignKey(l => l.AdvisorPartyId);

        builder.Property(l => l.RebateRate)
            .HasPrecision(5, 2)
            .IsRequired();

        builder.Property(l => l.EffectiveDate).IsRequired();
        builder.Property(l => l.ExpiryDate);

        builder.Property(l => l.CreatedBy);
        builder.Property(l => l.UpdatedBy);
        builder.Property(l => l.CreatedAt).IsRequired();
        builder.Property(l => l.UpdatedAt).IsRequired();

        builder.HasIndex(l => new { l.TenantId, l.InvestmentAccountId, l.AdvisorPartyId })
            .HasDatabaseName("IX_AdvisorInvestmentAccountLinks_TenantId_AccountId_AdvisorPartyId");
    }
}
