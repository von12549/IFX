using IFX.Modules.Registry.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace IFX.Modules.Registry.Infrastructure.Persistence.Configurations;

public class FundConfiguration : IEntityTypeConfiguration<Fund>
{
    public void Configure(EntityTypeBuilder<Fund> builder)
    {
        builder.ToTable("Funds", "registry");

        builder.HasKey(f => f.Id);

        builder.Property(f => f.TenantId).IsRequired();

        builder.Property(f => f.FundCode)
            .IsRequired()
            .HasMaxLength(20);

        builder.Property(f => f.FundName)
            .IsRequired()
            .HasMaxLength(200);

        builder.Property(f => f.FundType).IsRequired();

        builder.Property(f => f.BaseCurrency)
            .IsRequired()
            .HasMaxLength(3);

        builder.Property(f => f.InceptionDate).IsRequired();

        builder.Property(f => f.Status).IsRequired();

        builder.Property(f => f.CreatedBy);
        builder.Property(f => f.CreatedAt).IsRequired();
        builder.Property(f => f.UpdatedAt).IsRequired().IsConcurrencyToken();

        builder.HasIndex(f => new { f.TenantId, f.FundCode })
            .HasDatabaseName("IX_Funds_TenantId_FundCode")
            .IsUnique();
    }
}
