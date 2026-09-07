using IFX.Modules.Registry.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace IFX.Modules.Registry.Infrastructure.Persistence.Configurations;

public class FundClassConfiguration : IEntityTypeConfiguration<FundClass>
{
    public void Configure(EntityTypeBuilder<FundClass> builder)
    {
        builder.ToTable("FundClasses", "registry");

        builder.HasKey(fc => fc.Id);

        builder.Property(fc => fc.FundId).IsRequired();

        builder.Property(fc => fc.TenantId).IsRequired();

        builder.Property(fc => fc.ClassCode)
            .IsRequired()
            .HasMaxLength(20);

        builder.Property(fc => fc.ClassName)
            .IsRequired()
            .HasMaxLength(200);

        builder.Property(fc => fc.Currency)
            .IsRequired()
            .HasMaxLength(3);

        builder.Property(fc => fc.MinInitialInvestment)
            .HasColumnType("decimal(18,4)");

        builder.Property(fc => fc.ManagementFeeRate)
            .HasColumnType("decimal(8,6)");

        builder.Property(fc => fc.PerformanceFeeRate)
            .HasColumnType("decimal(8,6)");

        builder.Property(fc => fc.NavFrequency).IsRequired();

        builder.Property(fc => fc.Status).IsRequired();

        builder.Property(fc => fc.CreatedBy);
        builder.Property(fc => fc.CreatedAt).IsRequired();
        builder.Property(fc => fc.UpdatedAt).IsRequired().IsConcurrencyToken();

        builder.HasIndex(fc => new { fc.FundId, fc.ClassCode })
            .HasDatabaseName("IX_FundClasses_FundId_ClassCode")
            .IsUnique();

        builder.HasIndex(fc => fc.TenantId)
            .HasDatabaseName("IX_FundClasses_TenantId");
    }
}
