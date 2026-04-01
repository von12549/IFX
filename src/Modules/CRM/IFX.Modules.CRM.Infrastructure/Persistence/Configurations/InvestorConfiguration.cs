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

        builder.Property(i => i.InvestorCode)
            .IsRequired()
            .HasMaxLength(20);

        builder.Property(i => i.Name)
            .IsRequired()
            .HasMaxLength(200);

        builder.Property(i => i.Type)
            .IsRequired()
            .HasConversion<int>();

        builder.Property(i => i.KycStatus)
            .IsRequired()
            .HasConversion<int>();

        builder.Property(i => i.KycReviewedAt);

        builder.Property(i => i.ResidencyCountry)
            .IsRequired()
            .HasMaxLength(2);

        builder.Property(i => i.TaxResidency)
            .IsRequired()
            .HasMaxLength(2);

        builder.Property(i => i.Status)
            .IsRequired()
            .HasConversion<int>();

        builder.Property(i => i.CreatedBy);
        builder.Property(i => i.CreatedAt).IsRequired();
        builder.Property(i => i.UpdatedAt).IsRequired();

        builder.HasIndex(i => new { i.TenantId, i.InvestorCode })
            .HasDatabaseName("IX_Investors_TenantId_InvestorCode")
            .IsUnique();
    }
}
