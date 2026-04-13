using IFX.Modules.CRM.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace IFX.Modules.CRM.Infrastructure.Persistence.Configurations;

public class InvestorConfiguration : IEntityTypeConfiguration<Investor>
{
    public void Configure(EntityTypeBuilder<Investor> builder)
    {
        builder.ToTable("Investors", "crm");

        builder.HasKey(i => i.Id);

        builder.Property(i => i.TenantId).IsRequired();

        builder.Property(i => i.PartyId);

        builder.Property(i => i.InvestorCode)
            .IsRequired()
            .HasMaxLength(20);

        builder.Property(i => i.Name)
            .IsRequired()
            .HasMaxLength(200);

        builder.Property(i => i.LegalStructure)
            .IsRequired()
            .HasConversion<int>();

        // KYC
        builder.Property(i => i.KycStatus)
            .IsRequired()
            .HasConversion<int>();

        builder.Property(i => i.KycReviewedAt);

        // Tax & Compliance
        builder.Property(i => i.TaxResidencyCountry)
            .HasMaxLength(2);

        builder.Property(i => i.TIN)
            .HasMaxLength(20);

        builder.Property(i => i.FatcaCrsStatus)
            .IsRequired()
            .HasConversion<int>();

        builder.Property(i => i.GIIN)
            .HasMaxLength(20);

        // AML
        builder.Property(i => i.AmlStatus)
            .IsRequired()
            .HasConversion<int>();

        builder.Property(i => i.AmlGatewayReference)
            .HasMaxLength(100);

        builder.Property(i => i.AmlCheckedAt);

        builder.Property(i => i.IsPEP);

        builder.Property(i => i.PepDetails)
            .HasMaxLength(500);

        builder.Property(i => i.SourceOfWealth)
            .HasMaxLength(200);

        builder.Property(i => i.UnresolvedPepCount).IsRequired();
        builder.Property(i => i.UnresolvedSanctionCount).IsRequired();
        builder.Property(i => i.UnresolvedAdverseMediaCount).IsRequired();

        builder.Property(i => i.Status)
            .IsRequired()
            .HasConversion<int>();

        builder.Property(i => i.CreatedBy);
        builder.Property(i => i.UpdatedBy);
        builder.Property(i => i.CreatedAt).IsRequired();
        builder.Property(i => i.UpdatedAt).IsRequired();

        builder.HasIndex(i => new { i.TenantId, i.InvestorCode })
            .HasDatabaseName("IX_Investors_TenantId_InvestorCode")
            .IsUnique();

        // Filtered unique index: one Investor per Party per Tenant (only when PartyId is set)
        builder.HasIndex(i => new { i.TenantId, i.PartyId })
            .HasDatabaseName("IX_Investors_TenantId_PartyId")
            .IsUnique()
            .HasFilter("[PartyId] IS NOT NULL");

        // Extension profiles — 1:0..1 relationships
        builder.HasOne(i => i.IndividualProfile)
            .WithOne(p => p.Investor)
            .HasForeignKey<IndividualInvestorProfile>(p => p.InvestorId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(i => i.CorporateProfile)
            .WithOne(p => p.Investor)
            .HasForeignKey<CorporateInvestorProfile>(p => p.InvestorId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(i => i.TrustProfile)
            .WithOne(p => p.Investor)
            .HasForeignKey<TrustInvestorProfile>(p => p.InvestorId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
