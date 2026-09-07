using IFX.Modules.CRM.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace IFX.Modules.CRM.Infrastructure.Persistence.Configurations;

public class IndividualInvestorProfileConfiguration : IEntityTypeConfiguration<IndividualInvestorProfile>
{
    public void Configure(EntityTypeBuilder<IndividualInvestorProfile> builder)
    {
        builder.ToTable("IndividualInvestorProfiles", ModuleDatabase.Schema);

        builder.HasKey(p => p.Id);

        builder.Property(p => p.InvestorId).IsRequired();

        builder.Property(p => p.DateOfBirth);
        builder.Property(p => p.DateOfDeath);

        builder.Property(p => p.Gender)
            .HasConversion<int>();

        builder.Property(p => p.PlaceOfBirth).HasMaxLength(100);
        builder.Property(p => p.Nationality).HasMaxLength(2);

        builder.Property(p => p.IdDocumentType)
            .HasConversion<int>();

        builder.Property(p => p.IdDocumentNumber).HasMaxLength(50);
        builder.Property(p => p.IdDocumentCountry).HasMaxLength(2);
        builder.Property(p => p.IdDocumentExpiry);

        builder.Property(p => p.FrankieOneEntityId).HasMaxLength(100);

        builder.HasIndex(p => p.InvestorId)
            .HasDatabaseName("IX_IndividualInvestorProfiles_InvestorId")
            .IsUnique();
    }
}
