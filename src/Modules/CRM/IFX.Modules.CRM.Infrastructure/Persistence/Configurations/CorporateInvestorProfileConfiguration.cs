using IFX.Modules.CRM.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace IFX.Modules.CRM.Infrastructure.Persistence.Configurations;

public class CorporateInvestorProfileConfiguration : IEntityTypeConfiguration<CorporateInvestorProfile>
{
    public void Configure(EntityTypeBuilder<CorporateInvestorProfile> builder)
    {
        builder.ToTable("CorporateInvestorProfiles", ModuleDatabase.Schema);

        builder.HasKey(p => p.Id);

        builder.Property(p => p.InvestorId).IsRequired();

        builder.Property(p => p.Acn).HasMaxLength(9);
        builder.Property(p => p.Abn).HasMaxLength(11);
        builder.Property(p => p.RegistrationNumber).HasMaxLength(50);
        builder.Property(p => p.CountryOfIncorporation).HasMaxLength(2);

        builder.Property(p => p.IncorporationDate);
        builder.Property(p => p.IsPubliclyListed);
        builder.Property(p => p.Regulator).HasMaxLength(100);
        builder.Property(p => p.LicenceNumber).HasMaxLength(50);

        builder.Property(p => p.FrankieOneEntityId).HasMaxLength(100);

        builder.HasIndex(p => p.InvestorId)
            .HasDatabaseName("IX_CorporateInvestorProfiles_InvestorId")
            .IsUnique();
    }
}
