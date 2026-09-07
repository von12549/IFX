using IFX.Modules.CRM.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace IFX.Modules.CRM.Infrastructure.Persistence.Configurations;

public class TrustInvestorProfileConfiguration : IEntityTypeConfiguration<TrustInvestorProfile>
{
    public void Configure(EntityTypeBuilder<TrustInvestorProfile> builder)
    {
        builder.ToTable("TrustInvestorProfiles", ModuleDatabase.Schema);

        builder.HasKey(p => p.Id);

        builder.Property(p => p.InvestorId).IsRequired();

        builder.Property(p => p.TrustType).HasMaxLength(50);
        builder.Property(p => p.TrustDeedReference).HasMaxLength(100);
        builder.Property(p => p.TrustEstablishedDate);
        builder.Property(p => p.TrusteePartyId);

        builder.Property(p => p.FrankieOneEntityId).HasMaxLength(100);

        builder.HasIndex(p => p.InvestorId)
            .HasDatabaseName("IX_TrustInvestorProfiles_InvestorId")
            .IsUnique();
    }
}
